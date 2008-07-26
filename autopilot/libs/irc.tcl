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

puts $::lang::load_irc_module
package require irc

# Make our global communication handle
set irc [::irc::connection]

# Speed things up by grabbing settings in advance - saves
# repeatedly executing a list search with get_setting
namespace eval apirc {
   set server [get_setting autopilot irc_server]
   set port [get_setting autopilot irc_port]
   set user [get_setting autopilot irc_user]
   set nick [get_setting network player_name]
   set channel [get_setting autopilot irc_channel]
   if [setting_enabled [get_setting autopilot irc_bridge]] { set bridge 1 } {set bridge 0}
   if [setting_enabled [get_setting autopilot irc_explicit_say]] { set explicit_say 1 } {set explicit_say 0 }
}

proc irc_tell_newgrfs nick {
   irc_tell {[newgrf]} $nick
   if {[info exists ::apconfig::newgrf]} {
      foreach newgrf $::apconfig::newgrf {irc_tell [lindex $newgrf 0] $nick}
   }
   irc_tell "# $::lang::newgrf_end" $nick
}

proc irc_tell_company_list nick {
   company_count
   after $::standard_delay [string map "NICK $nick" {
      # Wait a second to allow the Expect to pick up the result from players
      for {set i 1} {$i <= $::max_companies} {incr i} {
         if {[lindex $::mainloop::company($i) 3] > 1} {
            # The company's founding date is > 1, so it exists
            irc_tell [format {Company %d (%s): %s} $i [lindex $::mainloop::company($i) 0] [lindex $::mainloop::company($i) 1]] NICK
         }
      }
   }]
}

proc irc_tell_player_list nick {
   player_count
   after $::standard_delay [string map "NICK $nick" {
      # Wait a second to allow the Expect to pick up the result from clients
      foreach {number} [array names ::mainloop::player] {
         if {[lindex $::mainloop::player($number) 1] > $max_companies} {
            irc_tell [format {Player %d is %s, a spectator} [lindex $::mainloop::player($number) 4] [lindex $::mainloop::player($number) 0]] NICK
         } else {
            irc_tell [format {Player %d (%s) is %s, in company %d (%s)} [lindex $::mainloop::player($number) 4] [lindex $::mainloop::company([lindex $::mainloop::player($number) 1]) 0] [lindex $::mainloop::player($number) 0] [lindex $::mainloop::player($number) 1] [lindex $::mainloop::company([lindex $::mainloop::player($number) 1]) 1]] NICK
         }
      }
   }]
}

proc irc_say_newgrfs {} {
   $::irc_say {[newgrf]}
   if {[info exists ::apconfig::newgrf]} {
      foreach newgrf $::apconfig::newgrf {$::irc_say [lindex $newgrf 0]}
   }
   $::irc_say "# $::lang::newgrf_end"
}

proc irc_show_company_list {} {
   company_count
   after $::standard_delay {
      # Wait a second to allow the Expect to pick up the result from players
      for {set i 1} {$i <= $::max_companies} {incr i} {
         if {[lindex $::mainloop::company($i) 3] > 1} {
            # The company's founding date is > 1, so it exists
            $::irc_say [format {Company %d (%s): %s} $i [lindex $::mainloop::company($i) 0] [lindex $::mainloop::company($i) 1]]
         }
      }
   }
}

proc irc_show_player_list {} {
   player_count
   after $::standard_delay {
      # Wait a second to allow the Expect to pick up the result from clients
      foreach {number} [array names ::mainloop::player] {
         if {[lindex $::mainloop::player($number) 1] > $max_companies} {
            $::irc_say [format {Player %d is %s, a spectator} [lindex $::mainloop::player($number) 4] [lindex $::mainloop::player($number) 0]]
         } else {
            $::irc_say [format {Player %d (%s) is %s, in company %d (%s)} [lindex $::mainloop::player($number) 4] [lindex $::mainloop::company([lindex $::mainloop::player($number) 1]) 0] [lindex $::mainloop::player($number) 0] [lindex $::mainloop::player($number) 1] [lindex $::mainloop::company([lindex $::mainloop::player($number) 1]) 1]]
         }
      }
   }
}

$irc registerevent PRIVMSG {
   set commandchar [get_setting autopilot irc_commandchar]
   if {[target] == $::apirc::nick} {
      # Message sent to autopilot
      if { [string match "\001VERSION\001" [msg]] } {
         $::irc send "NOTICE [who] :\001VERSION autopilot:$::version:$::tcl_platform(machine)/$::tcl_platform(platform)\001"
         puts [format $::lang::version_requested [who]]
      } {puts [string map {\001 *} "IRC PM from [who]: [msg]"]}
      set bang_command [split [msg]]
      case [lindex $bang_command 0] {
         {version} {irc_tell [map_strings "autopilot VERSION"] [who]}
         {newgrf} {irc_tell_newgrfs [who]}
         {companies} {irc_tell_company_list [who]}
         {players} {irc_tell_player_list [who]}
         {save} {
            say_everywhere $::lang::saving_game
            exp_send -i $::ds "save game\r"
         }

         {rcon} {
            if {[setting_enabled [get_setting autopilot irc_rcon]] && [lindex $bang_command 1] == [get_setting network rcon_password]} {
               exp_send -i $::ds "[join [lrange $bang_command 2 end]]\r"
            }
         }
           
      }
      foreach response $::apconfig::responses {
         if {[lindex $bang_command 0] == "[lindex $response 0]"} {
            irc_tell [map_strings [lrange $response 1 end]] [who]
         }
      }
   } elseif {[string first "\001VERSION\001" [msg]] == 0} {
      $::irc send "NOTICE [who] :\001VERSION autopilot:$::version:$::tcl_platform(machine)/$::tcl_platform(platform)\001"
      puts [format $::lang::version_requested [who]]
   } elseif {[string first [get_setting autopilot irc_commandchar] [msg]] == 0} {
      # Message is a !bang-command
      # User-defined !bang commands take precedence
      set bang_command [split [msg]]
      set bang_command_incomplete true
      foreach response $::apconfig::responses {
         if {[string range [lindex $bang_command 0] 1 end] == "[lindex $response 0]"} {
            $::irc_say [map_strings [lrange $response 1 end]]
            set bang_command_incomplete false
         }
      }
      if $bang_command_incomplete {
         # Built-in !bang-commands which can be overriden
         case [string range [lindex $bang_command 0] 1 end] {
            {version} {$::irc_say [map_strings "autopilot VERSION"]}
            {say} {
               say_game "<[who]> [join [lrange $bang_command 1 end]]"
               $::db_log "$apirc::channel/[who]: [join [lrange $bang_command 1 end]]"
            }
            {save} {
               say_everywhere $::lang::saving_game
               exp_send -i $::ds "save game\r"
            }
            {newgrf} irc_say_newgrfs
            {companies} irc_show_company_list
            {players} irc_show_player_list
         }
      }
   } elseif {$::apirc::bridge && !$::apirc::explicit_say} {
      # Just a general chat
      if { [string match "\001*\001" [msg]] } {
         if { [regexp {^\001ACTION (.+)\001$} [msg] -> msg] } {
            say_game "* [who] $msg"
            $::gui_say "* [who] $msg"
         }
      } else {
         say_game "<[who]> [msg]"
         $::gui_say "<[who]> [msg]"
      }
   }
}

# Procedure to send IRC notices
proc irc_tell {message nick} {
   $::irc send "NOTICE $nick :$message"
}

# Define a way to talk to IRC
proc irc_say_internal message {
   $::irc send "PRIVMSG $::apirc::channel :$message"
}

# What to do to get onto IRC
proc join_irc {} {
   set ::nickserv_reg false
   set code [catch {$::irc connect $::apirc::server $::apirc::port}]
   if {$code} {
      puts "$code: $::lang::irc_connect_fail"
      after 5000 join_irc
   } {
      puts $::lang::irc_connected
      $::irc user $::apirc::user localhost domain "autopilot $::version"
      $::irc nick $::apirc::nick
      set nickservtask [get_setting autopilot irc_nickserv]
      puts $nickservtask
      if {$nickservtask != {}} {
         $::irc send $nickservtask
      }
      $::irc join $::apirc::channel
      set ::irc_say irc_say_internal
   }
}

proc quit_irc {} {
   if {[$::irc connected]} {
      $::irc quit
   }
}

# Join our channel if we see any invite

$irc registerevent INVITE {
   $::irc join $::apirc::channel
}

join_irc
