#!/bin/sh
# Start Tcl \
exec tclsh $0 $@

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

package require Expect
log_user 0

set pidfile autopilot.pid
exec echo [ pid ] > $pidfile

# Decide which config file we're using; either set by environment, or default.
set inifilename openttd.cfg
if [info exists env(OTTD_CONFIG)] {
   set inifilename $env(OTTD_CONFIG)
}

# Our version - if you modify and redistribute, please change this
# string to reflect the fact that this autopilot isn't the original
# autopilot by Brian Ronald.
set version {autopilot ap+ 3.0 beta}

namespace eval mainloop {
   # Do nothing; just make the namespace
}

# Read in values from openttd.cfg
# namespace apconfig contains only configuration lists
namespace eval apconfig {
   variable inifile [open $inifilename r]
   while {-1 != [gets $inifile line]} {
      if {[string length $line] > 0 && [string first \# $line] != 0} {
         if [string match {\[*\]} $line] {
            variable section "[string map {{[} {} {]} {}} $line]"
            variable $section {}
         } {
            lappend $section [join [split $line =]]
         }
      }
   }
   close $inifile
}

if {![info exists ::apconfig::autopilot]} {
   error "autopilot configuration section not loaded from $inifilename"
   exit 1
}

# Fetch in our library of functions
source autopilot/libs/main.tcl

# Check the config, and include support for extra features
if {[setting_enabled [get_setting autopilot use_irc]]} {
	source autopilot/libs/irc.tcl
}

if {[setting_enabled [get_setting autopilot use_mysql]]} {
	source autopilot/libs/mysql.tcl
}

if {[setting_enabled [get_setting autopilot use_signals]]} {
	source autopilot/libs/signals.tcl
}

if {[setting_enabled [get_setting autopilot use_gui]]} {
	source autopilot/libs/gui.tcl
	# Wait for the GUI to actually become visible
	tkwait vis .
}

# Three ways to start the game - new, load default, load specified
# Construct the command we plan to spawn.

if {[set openttd [get_setting autopilot command]] == {} } {
   set openttd {./openttd}
}

ds_output $::lang::engaged
set arg1 [ lindex $argv 0 ]
set arg2 [ lindex $argv 1 ]
if { [ string equal "$arg1" "load" ] } {
   if { [ string length $arg2 ] > 0 } {
      set commandline "$openttd -c $inifilename -D -g $arg2"
      ds_output [format $::lang::loadspec [get_setting network server_name]]
   } else {
      set commandline "$openttd -c $inifilename -D -g save/game.sav"
      ds_output [format $::lang::loaddef [get_setting network server_name]]
   }
} else {
   set commandline "$openttd -c $inifilename -D"
   ds_output [format $::lang::startnew [get_setting network server_name]]
   ds_output [format $::lang::landscape_is [get_setting gameopt landscape]]
   if {[get_setting game_creation map_y] != {}} {
      ds_output [format $::lang::map_dimensions [expr (pow(2,[get_setting game_creation map_y]))] [expr (pow(2,[get_setting game_creation map_x]))]]
   } {
      ds_output [format $::lang::map_dimensions [expr (pow(2,[get_setting patches map_y]))] [expr (pow(2,[get_setting patches map_x]))]]
   }
   if {[get_setting game_creation starting_year] != {}} {
      ds_output [format $::lang::start_year [get_setting game_creation starting_year]]
   } {
      if {[get_setting patches starting_year] != {}} {
         ds_output [format $::lang::start_year [get_setting patches starting_year]]
      } {
         ds_output [format $::lang::start_year [get_setting patches starting_date]]
      }
   }
   
   if {[namespace exists ::mod_db]} {
		::mod_db::newgame [get_setting network server_name]
   }
}

# Get the version
set ottd_version [ottd_version $openttd]

# Start openttd in dedicated mode
set ds [start_server $commandline]

# Create a list of passwords if that feature is enabled, and trigger
# the recurring password randomizer
if {[setting_enabled [get_setting autopilot randomize_password]]} {
   set wordfile [open [get_setting autopilot password_list] "r"]
   set worddata [read -nonewline $wordfile]
   close $wordfile
   set passwords [split $worddata "\n"]
   set numpasswords [llength $passwords]
   every [get_setting autopilot password_frequency] {
      set ::password [lrandom $::passwords]
      exp_send -i $::ds "server_pw $::password\r"
   }
} {
   set password [get_setting network server_password]
}

if {[namespace exists ::mod_db]} {
   ::mod_db::set_password $::password
}

# Set some expect variables
set spawn_id $ds

# Set the status bar
set ap_status $::lang::initializing

# Send some one-off commands to the server
if {[get_setting network net_frame_freq] != {}} {
   exp_send "net_frame_freq [get_setting network net_frame_freq]\r"
} {
   exp_send "net_frame_freq 2\r"
}
exp_send "debug_level net=0\r"

# Some versions of openttd don't read these settings, so autopilot will
if {[get_setting network max_companies] != {}} {
#   exp_send "max_companies [get_setting network max_companies]\r"
}

if {[get_setting network max_clients] != {}} {
#   exp_send "max_clients [get_setting network max_clients]\r"
}

if {[get_setting network max_spectators] != {}} {
#   exp_send "max_spectators [get_setting network max_spectators]\r"
}

# Pause the game, regardless; no point playing with no players.
exp_send "pause\r"

# Initialize other variables
set name [get_setting network player_name]
if {[setting_enabled [get_setting autopilot use_console]]} {
   set standard_delay [expr ([get_setting autopilot responsiveness] * 1000 + 500)]
} {
   set standard_delay 1000
}

# Getting started by sending a couple of commands and reading the output.
# We want to know the maximum number of companies, players and spectators,
# and details of which companies already exist, if any.

exp_send "server_info\r"

# I *really* want these variables setting.
set timeout 3600

expect {
   -re "Current/maximum clients: *\[ 0-9\]*/\[ 0-9\]{2}" {
      scan $expect_out(0,string) "Current/maximum clients:    %2d/%2d" players max_clients
      exp_continue
   }
   -re "Current/maximum companies: *\[ 0-9\]*/\[ 0-9\]{2}" {
      scan $expect_out(0,string) "Current/maximum companies:  %2d/%2d" companies max_companies
      exp_continue
   }
   -re "Current/maximum spectators: *\[ 0-9\]*/\[ 0-9\]{2}" {
      scan $expect_out(0,string) "Current/maximum spectators: %2d/%2d" - max_spectators
   }
}

# Populate the gui's company list with blanks
for {set c 1} {$c <= $max_companies} {incr c} {
   $::gui::companylist insert $c {}
}
$::gui::companylist configure -height $max_companies

# Populate the gui's player list with blanks
for {set p 1} {$p <= $max_clients} {incr p} {
   $::gui::playerlist insert $p {}
}
$::gui::playerlist configure -height $max_clients

# Now set the timeout for the main loop's expect
set timeout [get_setting autopilot responsiveness]

# This is it - the main Expect loop.  Wrapped in a namespace
# to avoid accidental pollution.  It's monolithic, and
# unashamedly so.

namespace eval mainloop {

   # Array for players
   array set player {}

   # Whether to enable the console for commands
   set use_console [get_setting autopilot use_console]
   set ::pause_level [get_setting autopilot pause_level]
   if $use_console {log_user 1}

   # Start a background periodic task to recount players and
   # companies - just in case the game "forgets" to inform us
   # and we lose count
   every [get_setting autopilot recount_frequency] player_count
   
   # Set the status bar
   set ::ap_status [format $::lang::players 0]

   while true {
      expect {
         -re ".*\n" {
            # This is a greedy regex, so it might *contain* more \n
            set out_buffer $expect_out(0,string)
            # The regex matches one or more lines.  Separate them.
            foreach linestr [split [string map {"\r" {} } $out_buffer] "\n"] {
               # You'll get at least one empty from the split
               if {$linestr != {} } {
                  set line [split $linestr]
                  # Get this far, and we have exactly one line of output from the server.
                  # Now we have fun with ifs and cases!
   
                  if {[string first {[All] } $linestr] == 0} {
                     # This is public chat
                     # Snap off the name of the sender, look at content
                     set lineafternick [lrange [split [join [lrange [split $linestr :] 1 end] :]] 1 end]
                     # Check for some commands
                     if {![string match [lindex $line 1] $name:]} {
                        say_from_game [join [lrange $line 1 end]]
                     }
                     if {[string equal [lrange $lineafternick 0 end] {show autopilot version}]} {
                        say_game $::version
                     }
                     if {[string equal [lrange $lineafternick 0 end] {!version}]} {
                        say_game $::version
                     }
                     if {[string equal [lrange $lineafternick 0 end] {!page admin}]} {
                        page_admin [string map {: {}} [lindex $line 1]]
                     }
                  } elseif {[string first "Company Name" $linestr] > 1} {
                     # Output from players command, populate companies
                     # First pull out the name, which can contain quotes
                     set c_name [join [lrange [split $linestr '] 1 end-1] ']
                     set ncline [string map "{'$c_name'} discarded" $linestr]
                     # then scan everything else, which is far more predictable
                     scan $ncline "#:%d(%\[^)\]) Company Name: discarded  Year Founded: %d  Money: %d  Loan: %d  Value: %d  (T:%\[^,\], R:%\[^,\], P:%\[^,\], S:%\[^,)])" c_number c_color c_founded c_money c_loan c_value c_trains c_roadvehicles c_planes c_ships
                     set company($c_number) "{$c_color} {$c_name} $c_founded $c_money $c_loan $c_value $c_trains $c_roadvehicles $c_planes $c_ships"
                     # Put what we find into the gui list
                     set cl_number $c_number; incr cl_number -1
                     if {[setting_enabled [get_setting autopilot use_gui]]} {
                        catch {$::gui::companylist delete $cl_number}
                        $::gui::companylist insert $cl_number $c_name
                        $::gui::companylist itemconfigure $cl_number -foreground $::gui::colors($c_color)
                     }
                  }
                  if {[string first "*** " $linestr] == 0} {
                     # Somebody joined, left or was renamed
                     if {[string first "has joined the game" $linestr] > 0} {
                        # Joined the game.  Greet, announce and increment count.
                        say_game [string map "NAME {[lrange $line 1 end-4]}" [map_strings [get_setting autopilot motd1]]]
                        say_game [string map "NAME {[lrange $line 1 end-4]}" [map_strings [get_setting autopilot motd2]]]
                        say_game [string map "NAME {[lrange $line 1 end-4]}" [map_strings [get_setting autopilot motd3]]]
                        say_from_game [join [lrange $line 1 end]]
                        # We used to increment and decrement, but this also
                        # populates the player array.
                        player_count
                        # Unpause if there are enough players.
                        if {[setting_enabled [get_setting autopilot save_on_join]]} {
                           exp_send -i $::ds "save join_[format %x [clock seconds]]\r"
                        }
                        if {$::players > $::pause_level && $::pause_level >= 0} {
                           exp_send -i $::ds "unpause\r"
                        }
                        # Randomize map location
                        if {[setting_enabled [get_setting autopilot randomize_location]]} {
                           if {[get_setting game_creation map_y] != {}} {
                              set tile [format %x [expr {int(rand()*(pow(2,[get_setting game_creation map_x] + [get_setting game_creation map_y])))}]]
                           } {
                              set tile [format %x [expr {int(rand()*(pow(2,[get_setting patches map_x] + [get_setting patches map_y])))}]]
                           }
                           exp_send -i $::ds "scrollto 0x$tile\n"
                        }
                     }
                     if {[string first "has left the game" $linestr] > 0} {
                        # Left the game.  Announce and decrement count.
                        say_from_game [join [lrange $line 1 end]]
                        # We used to increment and decrement, but this also
                        # populates the player array.
                        player_count
                        # Pause if there are too few players.
                        if {$::players <= $::pause_level && $::pause_level >= 0} {
                           exp_send -i $::ds "pause\r"
                           exp_send -i $::ds "save game\r"
                        }
                     }
                     if {[string first "has changed his/her name to" $linestr] >0} {
                        # Player changed name.  Announce the fact.
                        say_from_game [lrange $line 1 end]
                        # Now refresh the gui
                        player_count
                     }
                  }
                  if {[string first "Current/maximum companies: " $linestr] == 0} {
                     scan $linestr "Current/maximum companies:  %2d/%2d" ::companies ::max_companies
                  }
                  if {[string first "'rcon_pw' changed to:  " $linestr] == 0} {
                     set newentry "rcon_password [lindex $line 4]"
                     set location [lsearch [set ::apconfig::network] rcon_password*]
                     set ::apconfig::network "[lreplace [set ::apconfig::network] $location $location $newentry]"
                  }
                  if {[string first "'server_pw' changed to:  " $linestr] == 0} {
                     set ::password [lindex $line 4]
                     if {[namespace exists ::mod_db]} {
                        ::mod_db::set_password $::password
                     }
                  }
                  if {[regexp "^Client.*unique-id: '\[0-9,a-f\]*'\$" $linestr]} {
                     # We're discarding output from status
                  } elseif {[string first "Client" $linestr] == 0} {
                     # Output from clients command, populate players
                     # First pull out the name, which can contain quotes
                     set p_name [join [lrange [split $linestr '] 1 end-1] ']
                     set npline [string map "{'$p_name'} discarded" $linestr]
                     # then scan everything else, which is far more predictable
                     scan $npline "Client #%d  name: discarded  company: %d  IP: %s" p_number p_company p_IP
                     # Ignore client #1 (the server)
                     if {$p_number > 1} {
                        set pl_number [array size player]
                        if {$p_company > $::max_companies} {
                           set player([expr $pl_number + 1]) "{$p_name} $p_company $p_IP {[lindex $company(255) 0]} $p_number"
                        } {
                           set player([expr $pl_number + 1]) "{$p_name} $p_company $p_IP {[lindex $company($p_company) 0]} $p_number"
                        }
                        # Update the gui player list
                        if {[setting_enabled [get_setting autopilot use_gui]]} {
                           $::gui::playerlist insert $pl_number $p_name
                           $::gui::playerlist itemconfigure $pl_number -foreground $::gui::colors([lindex $company($p_company) 0])
                        }
                     }
                  }   
                  if {[string match doneclientcount $linestr]} {
                     set ::players [array size player]
                     # Set the status bar
                     set ::ap_status [format $::lang::players $::players]
                  }
                  if {[string first {Map sucessfully saved to} $linestr] == 0} {
                     say_everywhere $::lang::map_saved
                  }
               }
            }
         }
         eof {
            ds_output $::lang::server_exited
            break;
         }
      }
      # Respond to player commands from console, if enabled
      if $use_console {
         expect_user {
            "quit\n" {
               say_everywhere $::lang::admin_quit
               exp_send -i $::ds "quit\r"
               break
            }
            "exit\n" {
               say_everywhere $::lang::admin_quit
               say_everywhere $::lang::saving_game
               exp_send -i $::ds "save game\r"
               exp_send -i $::ds "quit\r"
            }
            "save\n" {
               say_everywhere $::lang::saving_game
               exp_send -i $::ds "save game\r"
            }
            "version\n" {
               puts $version
            }
            "license\n" {
               puts $::lang::license
            }
            -re "(.*)\n" {
               exp_send -i $::ds "$expect_out(1,string)\r"
            }
         }
      }
   }

   # End of ::mainloop namespace
}

$gui_close
if {[namespace exists ::mod_db]} {
   ::mod_db::disconnect
}
exec echo {} > $pidfile
