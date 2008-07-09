# Copyright 2006 Brian Ronald.  All rights reserved.
# Autopilot for use on OpenTTD dedicated server console.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

# Handy command to strip IRC codes from a string
proc strip_color {intext} { return [regsub -all {\002|\003[0-9]{1,2},[0-9]{1,2}|\003[0-9]{1,2}|\003|\026|\037|\033\133.*\;} $intext {}]}

# Null handlers to replace disabled functions
proc nullmessage {args} {}
proc null {} {}
namespace eval ::gui {
   set companylist nullmessage
   set playerlist nullmessage
}

# Set default procedures for messages - these are overridden
# by setting the variables to other procedures, normally from
# within an include file.
set irc_say nullmessage
set db_log nullmessage
set db_set_password null
set db_close null
set db_new_game nullmessage
set ::gui_say nullmessage
set gui_close null

# Procedure for getting the version of the game.  Runs new, so only
# accurate if done at the time the game is spawned.
proc ottd_version command {
   set retval {}
   if { [catch { set retval [lindex [lindex [split [eval "exec $command -d -h"] \n] 0] 1] } $retval ] } {
      set retval [lindex [lindex [split $::errorInfo \n] 0] 1]
   }
   return $retval
}

# Procedure to fetch a setting from the apconfig namespace
proc get_setting {section var} {
   if {[info exists ::apconfig::$section]} {
      return [string trim [lrange [lsearch -inline [set ::apconfig::$section] $var*] 1 end]]
   } {
      return {}
   }
}

# Load the language file
source autopilot/lang/[get_setting autopilot language].tcl

# Page the admin by email
proc page_admin name {
   set smtp_server [get_setting autopilot smtp_server]
   if {$smtp_server != {} } {
      set mailserver [socket $smtp_server 25]
      puts $mailserver "HELO [info hostname]"
      flush $mailserver
      # Necessary to read the response on servers where
      # pipelining is forbidden as an anti-spam measure
      gets $mailserver response
      puts $mailserver "MAIL FROM: [get_setting autopilot email]"
      flush $mailserver
      gets $mailserver response
      puts $mailserver "RCPT TO: [get_setting autopilot email]"
      flush $mailserver
      gets $mailserver response
      puts $mailserver DATA
      flush $mailserver
      gets $mailserver response
      puts $mailserver "SUBJECT: [format $::lang::admin_page $name [get_setting network server_name]]"
      puts $mailserver $::lang::admin_page_body
      puts $mailserver .
      flush $mailserver
      gets $mailserver response
      puts $mailserver QUIT
      flush $mailserver
      close $mailserver
      say_game $::lang::admin_paged
   }
   say_from_game "Admin paged on this server by $name"
}

# Map strings
proc map_strings message {
   return [string map "
      COMPANIES {$::companies}
      EMAIL [get_setting autopilot email]
      LICENSE {$::lang::license}
      PASSWORD {$::password}
      PLAYERS {$::players}
      URL [get_setting autopilot url]
      VERSION {$::version}
      OTTD {$::ottd_version}
   " $message]
}

# Start the game, and return a spawn ID 
proc start_server commandline {
   eval "spawn $commandline"
   return $spawn_id
}

# Returns true if a setting is one of true, yes or on
proc setting_enabled setting {
   if { $setting == yes || $setting == true || $setting == on }\
   {return 1} {return 0}
}

# Sanitize messages to the game server
proc ds_sanitize message {
   return [string map {\" '} [strip_color $message]]
}

# Output a message to the console and IRC
proc ds_output message {
   puts $message
   $::gui_say $message
   $::irc_say $message
}

# Send a message to all channels but the game
proc say_from_game message {
   $::gui_say $message
   if $::apirc::bridge {
      $::irc_say $message
   }
   $::db_log $message
}

# Send a message to all available channels
proc say_everywhere message {
   say_game $message
   $::irc_say $message
   $::db_log $message
   $::gui_say $message
}

# Say something in the game
proc say_game message {
   exp_send -i $::ds "say \"[ds_sanitize $message]\"\r"
}

# Proc to run periodic tasks in the event loop
proc every {ms body} {eval $body ; after $ms [info level 0]}

# Cause companies to be recounted by wiping them all, issuing
# a players command, then letting the Expect loop pick up the
# result
proc company_count {} {
   for {set i 1} {$i <= $::max_companies} {incr i} {
      set ::mainloop::company($i) {none {} 0 0 0 0 0 0 0 0}
   }
   set ::mainloop::company(255) {none {Spectator} 0 0 0 0 0 0 0 0}
   exp_send -i $::ds "players\r"
   exp_send -i $::ds "server_info\r"
}

# Cause players to be recounted by wiping them all, issuing
# a clients command, then echoing a string that expect will
# treat as a delimiter
proc player_count {} {
   # Update the status bar
   set ::ap_status $::lang::recounting
   array unset ::mainloop::player
   array set ::mainloop::player {}
   catch {$::gui::playerlist delete 0 end}
   company_count
   exp_send -i $::ds "clients\recho doneclientcount\r"
   after $::standard_delay {
      if {$::pause_level >= 0} {
         if {$::players > $::pause_level} {
            exp_send -i $::ds "unpause\r"
         } {
            exp_send -i $::ds "pause\r"
         }
      }
   }
}

# grab a random list element
proc lrandom L {lindex $L [expr {int(rand()*[llength $L])}]}
