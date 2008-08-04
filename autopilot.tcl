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

# Fetch in our library of functions
source autopilot/libs/main.tcl

# Read in values from openttd.cfg
# namespace apconfig contains only configuration lists
::ap::config::load $inifilename

# Load the language file
source autopilot/lang/[::ap::config::get autopilot language].tcl

if {![info exists ::ap::config::autopilot]} {
	error "autopilot configuration section not loaded from $inifilename"
	exit 1
}

# Check the config, and include support for extra features
if {[::ap::config::isEnabled autopilot use_irc]} {
	source autopilot/libs/irc.tcl
}

if {[::ap::config::isEnabled autopilot use_mysql]} {
	source autopilot/libs/mysql.tcl
}

if {[::ap::config::isEnabled autopilot use_signals]} {
	source autopilot/libs/signals.tcl
}

# Three ways to start the game - new, load default, load specified
# Construct the command we plan to spawn.

if {[set openttd [::ap::config::get autopilot command]] == {} } {
	set openttd {./openttd}
}

::ap::game::output $::lang::engaged
set arg1 [ lindex $argv 0 ]
set arg2 [ lindex $argv 1 ]
if { [ string equal "$arg1" "load" ] } {
	if { [ string length $arg2 ] > 0 } {
		set commandline "$openttd -c $inifilename -D -g $arg2"
		::ap::game::output [format $::lang::loadspec [::ap::config::get network server_name]]
	} else {
		set commandline "$openttd -c $inifilename -D -g save/game.sav"
		::ap::game::output [format $::lang::loaddef [::ap::config::get network server_name]]
	}
} else {
	set commandline "$openttd -c $inifilename -D"
	::ap::game::output [format $::lang::startnew [::ap::config::get network server_name]]
	::ap::game::output [format $::lang::landscape_is [::ap::config::get game_creation landscape]]
	if {[::ap::config::get game_creation map_y] != {}} {
		::ap::game::output [format $::lang::map_dimensions [expr (pow(2,[::ap::config::get game_creation map_y]))] [expr (pow(2,[::ap::config::get game_creation map_x]))]]
	} else {
		::ap::game::output [format $::lang::map_dimensions [expr (pow(2,[::ap::config::get patches map_y]))] [expr (pow(2,[::ap::config::get patches map_x]))]]
	}
	if {[::ap::config::get game_creation starting_year] != {}} {
		::ap::game::output [format $::lang::start_year [::ap::config::get game_creation starting_year]]
	} else {
		if {[::ap::config::get patches starting_year] != {}} {
			::ap::game::output [format $::lang::start_year [::ap::config::get patches starting_year]]
		} else {
			::ap::game::output [format $::lang::start_year [::ap::config::get patches starting_date]]
		}
	}

	if {[namespace exists ::mod_db]} {
		::mod_db::newgame [::ap::config::get network server_name]
	}
}

# Get the version
set ottd_version [::ap::game::version $openttd]

# Start openttd in dedicated mode
set ds [::ap::game::start $commandline]

# Create a list of passwords if that feature is enabled, and trigger
# the recurring password randomizer
if {[::ap::config::isEnabled autopilot randomize_password]} {
	set wordfile [open [::ap::config::get autopilot password_list] "r"]
	set worddata [read -nonewline $wordfile]
	close $wordfile
	set passwords [split $worddata "\n"]
	set numpasswords [llength $passwords]
	::ap::func::every [::ap::config::get autopilot password_frequency] {
		set ::password [::ap::func::lrandom $::passwords]
		::ap::game::console "server_pw $::password\r"
	}
} else {
	set ::password [::ap::config::get network server_password]
}

if {[namespace exists ::mod_db]} {
   ::mod_db::set_password $::password
}

# Set some expect variables
set spawn_id $ds

# Set the status bar
set ap_status $::lang::initializing

# Send some one-off commands to the server
if {[::ap::config::get network net_frame_freq] != {}} {
	::ap::game::console "net_frame_freq [::ap::config::get network net_frame_freq]\r"
} {
	::ap::game::console "net_frame_freq 2\r"
}

# ap does not want any debug levels - run openttd without autopilot for debuging, preferably in gdb
::ap::game::console "debug_level net=0\r"

# Some versions of openttd don't read these settings, so autopilot will
if {[::ap::config::get network max_companies] != {}} {
#	::ap::game::console "max_companies [::ap::config::get network max_companies]\r"
}

if {[::ap::config::get network max_clients] != {}} {
#	::ap::game::console "max_clients [::ap::config::get network max_clients]\r"
}

if {[::ap::config::get network max_spectators] != {}} {
#	::ap::game::console "max_spectators [::ap::config::get network max_spectators]\r"
}

# only pause a new game if 'pause_on_newgame' is enabled
if {[::ap::config::isEnabled gui pause_on_newgame] || [::ap::config::isEnabled patches pause_on_newgame]} {
	::ap::game::pause
}

# Initialize other variables
set name [::ap::config::get network player_name]
if {[::ap::config::isEnabled autopilot use_console]} {
	set standard_delay [expr ([::ap::config::get autopilot responsiveness] * 1000 + 500)]
} else {
	set standard_delay 1000
}

# Getting started by sending a couple of commands and reading the output.
# We want to know the maximum number of companies, players and spectators,
# and details of which companies already exist, if any.

::ap::game::console "server_info\r"

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

# Now set the timeout for the main loop's expect
set timeout [::ap::config::get autopilot responsiveness]

# This is it - the main Expect loop.  Wrapped in a namespace
# to avoid accidental pollution.  It's monolithic, and
# unashamedly so.

namespace eval mainloop {

	# Array for players
	array set ::player {}
	
	# map player names to id's
	array set ::nick2id {}
	
	# Whether to enable the console for commands
	set use_console [::ap::config::get autopilot use_console]
	set ::pause_level [::ap::config::get autopilot pause_level]
	if $use_console {log_user 1}
	
	# Start a background periodic task to recount players and
	# companies - just in case the game "forgets" to inform us
	# and we lose count
	::ap::func::every [::ap::config::get autopilot recount_frequency] ::ap::count::players
	
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
						if {[string first {[All] } $linestr] == 0 || [string first {[Private] } $linestr] == 0} {
							set chat [regexp -inline -- {\[(All|Private)\] (.+?): (.*)} $linestr]
							
							set nick [lindex $chat 2]
							set lineafternick [lindex $chat 3]
							
							set private 0
							
							if {[lindex $chat 1] == "Private"} {
								set private 1
							}
							
							if {$nick == $::name} {
								# dont handle what we ourselves say!
							} elseif {$private && [::ap::func::getClientId $nick] == 0} {
								# if we say in private To somebody, the cought nick is prefixed with "To " and we get a 0 back as Id
								# ignore commands the server might say in private
							} elseif {[string first {!} $lineafternick] == 0} {
								# this is a bang_command...
								set bang_command [string range $lineafternick 1 end]
								switch $bang_command {
									{version} {
										ap::game::say::reply $private $nick $::version
									}
									{admin} {
										::ap::func::page_admin [string map {: {}} [lindex $line 1]]
									}
									{default} {
										variable filename "[lindex $bang_command 0].tcl"
						
										if {![::ap::callback::execute $nick ::ap::game::say $private [lrange $bang_command 0 end] "autopilot/scripts/game/$filename"]} {
											::ap::callback::execute $nick ::ap::game::say $private [lrange $bang_command 0 end] "autopilot/scripts/global/$filename"
										}
									}
								}
							} elseif {!$private} {
								if {[string first {/me } $lineafternick] == 0} {
									::ap::say::fromGame "* $nick [lrange $lineafternick 1 end]"
								} else {
									::ap::say::fromGame [join [lrange $line 1 end]]
								}
							}
						} elseif {[string first "Company Name" $linestr] > 1} {
							# Output from players command, populate companies
							# First pull out the name, which can contain quotes
							set c_name [join [lrange [split $linestr '] 1 end-1] ']
							set ncline [string map "{'$c_name'} discarded" $linestr]
							# then scan everything else, which is far more predictable
							scan $ncline "#:%d(%\[^)\]) Company Name: discarded  Year Founded: %d  Money: %d  Loan: %d  Value: %d  (T:%\[^,\], R:%\[^,\], P:%\[^,\], S:%\[^,)])" c_number c_color c_founded c_money c_loan c_value c_trains c_roadvehicles c_planes c_ships
							set company($c_number) "{$c_color} {$c_name} $c_founded $c_money $c_loan $c_value $c_trains $c_roadvehicles $c_planes $c_ships"
						}
						if {[string first "*** " $linestr] == 0} {
							# Somebody joined, left or was renamed
							if {[string first "has joined the game" $linestr] > 0} {
								# Joined the game.  Greet, announce and increment count.
								set nick [lrange [split $linestr] 1 end-4]
								
								# We used to increment and decrement, but this also
								# populates the player array.
								::ap::count::players
								
								after $::standard_delay [string map "NICK {$nick}" {::ap::callback::execute {NICK} ::ap::game::say 1 [list {[callback] on_game_join}] {autopilot/scripts/callback/on_game_join.tcl}}]
								
								# Unpause if there are enough players.
								if {[::ap::config::isEnabled autopilot save_on_join]} {
									::ap::game::save "join_[format %x [clock seconds]]"
								}
								if {$::players > $::pause_level && $::pause_level >= 0} {
									::ap::game::unpause
								}
							}
							if {[string first "has left the game" $linestr] > 0} {
								# Left the game.  Announce and decrement count.
								::ap::say::fromGame [join [lrange $line 1 end]]
								# We used to increment and decrement, but this also
								# populates the player array.
								::ap::count::players
								# Pause if there are too few players.
								if {$::players <= $::pause_level && $::pause_level >= 0} {
									::ap::game::pause
									::ap::game::save
								}
							}
							if {[string first "has changed his/her name to" $linestr] >0} {
								# Player changed name.  Announce the fact.
								::ap::say::fromGame "*** [lrange $line 1 end]"
								::ap::count::players
							}
						}
						if {[string first "Current/maximum companies: " $linestr] == 0} {
							scan $linestr "Current/maximum companies:  %2d/%2d" ::companies ::max_companies
						}
						if {[string first "'rcon_pw' changed to:  " $linestr] == 0} {
							set newentry "rcon_password [lindex $line 4]"
							set location [lsearch [set ::ap::config::network] rcon_password*]
							set ::ap::config::network "[lreplace [set ::ap::config::network] $location $location $newentry]"
						}
						if {[string first "'server_pw' changed to:  " $linestr] == 0} {
							set ::password [lindex $line 4]
							if {[namespace exists ::mod_db]} {
							   ::mod_db::set_password $::password
							}
							
							::ap::callback::execute {} ::ap::game::say 0 [list {[callback] on_game_serverwp} $::password] {autopilot/scripts/callback/on_game_serverpw.tcl}
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
								set pl_number [array size ::player]
								set ::nick2id($p_name) $p_number
								if {$p_company > $::max_companies} {
									set ::player([expr $pl_number + 1]) "{$p_name} $p_company $p_IP {[lindex $company(255) 0]} $p_number"
								} else {
									set ::player([expr $pl_number + 1]) "{$p_name} $p_company $p_IP {[lindex $company($p_company) 0]} $p_number"
								}
							}
						}   
						if {[string match doneclientcount $linestr]} {
							set ::players [array size ::player]
							# Set the status bar
							set ::ap_status [format $::lang::players $::players]
						}
						if {[string first {Map sucessfully saved to} $linestr] == 0} {
							::ap::say::everywhere $::lang::map_saved
						}
					}
				}
			}
			eof {
				::ap::game::output $::lang::server_exited
				break;
			}
		}
		# Respond to player commands from console, if enabled
		if $use_console {
			expect_user {
				"quit\n" {
					::ap::say::everywhere $::lang::admin_quit
					::ap::game::quit
					break
				}
				"exit\n" {
					::ap::say::everywhere $::lang::admin_quit
					::ap::say::everywhere $::lang::saving_game
					::ap::game::save
					::ap::game::quit
				}
				"save\n" {
					say_everywhere $::lang::saving_game
					::ap::game::save
				}
				"version\n" {
					puts $::version
				}
				"license\n" {
					puts $::lang::license
				}
				-re "(.*)\n" {
					::ap::game::console "$expect_out(1,string)\r"
				}
			}
		}
	}

	# End of ::mainloop namespace
}

if {[namespace exists ::mod_db]} {
	::mod_db::disconnect
}
exec echo {} > $pidfile
