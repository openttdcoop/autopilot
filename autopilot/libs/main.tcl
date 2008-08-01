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

namespace eval ap {
	
	namespace eval config {
		
		proc load {filename} {
			variable inifile [open $filename r]
			while {-1 != [gets $inifile line]} {
				if {[string length $line] > 0 && [string first \# $line] != 0} {
					if [string match {\[*\]} $line] {
						variable section "[string map {{[} {} {]} {}} $line]"
						set ::ap::config::$section {}
					} else {
						lappend ::ap::config::$section [join [split $line =]]
					}
				}
			}
			close $inifile
		}
		
		proc get {section var} {
			if {[info exists ::ap::config::$section]} {
				return [string trim [lrange [lsearch -inline [set ::ap::config::$section] $var*] 1 end]]
			} else {
				return {}
			}
		}
		
		# Returns true if a setting is one of true, yes or on
		proc isEnabled {section var} {
			variable value [::ap::config::get $section $var]
			if { $value == yes || $value == true || $value == on } {
				return 1
			} else {
				return 0
			}
		}
	}

	proc debug {prefix message} {
		puts "\[$prefix\] $message"
	}

	namespace eval game {
		
		variable version {}
		
		proc version {command} {
			variable retval {}
			if {[catch {variable retval [lindex [lindex [split [eval "exec $command -d -h"] \n] 0] 1]} $retval]} {
				variable retval [lindex [lindex [split $::errorInfo \n] 0] 1]
			}
			return $retval
		}
		
		proc start {command} {
			eval "spawn $command"
			set ::ds $spawn_id
		}
		
		proc quit {} {
			::ap::game::console "quit\r"
			set ::ds {}
		}
		
		proc save {{savname game}} {
			::ap::game::console "save $savname\r"
		}
		
		proc pause {} {
			::ap::game::console "pause\r"
		}
		
		proc unpause {} {
			::ap::game::console "unpause\r"
		}
		
		proc console {command} {
			exp_send -i $::ds $command
		}
		
		proc output {message} {
			puts $message
			if {[namespace exists ::mod_irc]} {
				::mod_irc::say::channel $message
			}
		}
	}

	namespace eval count {
		
		# Cause companies to be recounted by wiping them all, issuing
		# a players command, then letting the Expect loop pick up the
		# result
		proc companies {} {
			for {set i 1} {$i <= $::max_companies} {incr i} {
				set ::mainloop::company($i) {none {} 0 0 0 0 0 0 0 0}
			}
			set ::mainloop::company(255) {none {Spectator} 0 0 0 0 0 0 0 0}
			::ap::game::console "players\r"
			::ap::game::console "server_info\r"
		}
		
		# Cause players to be recounted by wiping them all, issuing
		# a clients command, then echoing a string that expect will
		# treat as a delimiter
		proc players {} {
			# Update the status bar
			set ::ap_status $::lang::recounting
			array unset ::mainloop::player
			array set ::mainloop::player {}
			::ap::count::companies
			::ap::game::console "clients\recho doneclientcount\r"
			after $::standard_delay {
				if {$::pause_level >= 0} {
					if {$::players > $::pause_level} {
						::ap::game::unpause
					} {
						::ap::game::pause
					}
				}
			}
		}
	}

	namespace eval say {
		
		proc everywhere {message} {
			::ap::say::toGame $message
			
			if {[namespace exists ::mod_irc]} {
				::mod_irc::say::channel $message
			}
			
			if {[namespace exists ::mod_db]} {
				::mod_db::log $message
			}
		}
		
		proc toGame {message} {
			::ap::game::console "say \"$message\"\r"
		}
		
		proc toClient {client message} {
			if {![string is integer $message]} {
				variable client [::ap::getClientId $client]
			}
			
			::ap::game::console "say_client $client \"$message\"\r"
		}
		
		proc fromGame {message} {
			if {[namespace exists ::mod_irc]} {
				::mod_irc::say::channel $message
			}
			
			if {[namespace exists ::mod_db]} {
				::mod_db::log $message
			}
		}
	}

	namespace eval func {
		
		# remove irc codes from string
		proc strip_color {str} {
			return [regsub -all {\002|\003[0-9]{1,2},[0-9]{1,2}|\003[0-9]{1,2}|\003|\026|\037|\033\133.*\;} $str {}]
		}
		
		# Sanitize messages to the game server
		proc ds_sanitize message {
			return [string map {\" '} [::ap::func::strip_color $message]]
		}
		
		proc map_strings {str} {
			return [string map "
				COMPANIES {$::companies}
				EMAIL [::ap::config::get autopilot email]
				LICENSE {$::lang::license}
				OTTD {$::ottd_version}
				PASSWORD {$::password}
				PLAYERS {$::players}
				URL [::ap::config::get autopilot url]
				VERSION {$::version}
			" $str]
		}
		
		# Proc to run periodic tasks in the event loop
		proc every {ms body} {
			eval $body
			after $ms [info level 0]
		}
		
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
	}
}
