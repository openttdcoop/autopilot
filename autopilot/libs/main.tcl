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

namespace eval ::ap {
	
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
			exp_send -i $::ds -- $command
		}
		
		proc output {message} {
			puts $message
			if {[namespace exists ::mod_irc]} {
				::mod_irc::say::public $message
			}
		}
		
		namespace eval say {
			
			proc public {nick {message {}}} {
				set message [::ap::func::getChatMessage $nick $message]
				::ap::game::console "say \"[::ap::func::sanitizeChat $message]\"\r"
			}
			
			proc private {nick message} {
				variable client_id [::ap::func::getClientId $nick]
				::ap::game::console "say_client $client_id \"[::ap::func::sanitizeChat $message]\"\r"
			}
			
			proc reply {private nick message} {
				if {$private} {
					::ap::game::say::private $nick $message
				} else {
					::ap::game::say::public $nick $message
				}
			}
		}
	}

	namespace eval count {
		
		# Cause companies to be recounted by wiping them all, issuing
		# a players command, then letting the Expect loop pick up the
		# result
		proc companies {} {
			for {set i 1} {$i < [array size ::mainloop::company]} {incr i} {
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
			::ap::game::say::public $message
			
			if {[namespace exists ::mod_irc]} {
				::mod_irc::say::public $message
			}
			
			if {[namespace exists ::mod_db]} {
				::mod_db::log $message
			}
		}
		
		# depricated
		proc toGame {message} {
			::ap::debug [namespace current]::toGame depricated
			::ap::game::say::public "$message"
		}
		
		proc toClient {client message} {
			::ap::debug [namespace current]::toClient depricated
			::ap::game::say::private $client $message
		}
		
		proc fromGame {message} {
			if {[namespace exists ::mod_irc]} {
				::mod_irc::say::public $message
			}
			
			if {[namespace exists ::mod_db]} {
				::mod_db::log $message
			}
		}
	}

	namespace eval func {
		
		proc getChatMessage {nick message} {
			if {$message == {}} {
				return $nick
			} elseif {$nick == {}} {
				return $message
			} else {
				if {[::ap::config::isEnabled autopilot respond_with_nick]} {
					return "$nick: $message"
				} else {
					return $message
				}
			}
		}
		
		proc getClientId {nick} {
			if {[array names ::mainloop::nick2id -exact $nick] != {}} {
				return $::mainloop::nick2id($nick)
			} else {
				return 0
			}
		}
		
		# grab a random list element
		proc lrandom L {
			lindex $L [expr {int(rand()*[llength $L])}]
		}
		
		# remove irc codes from string
		proc stripIrcColor {message} {
			return [regsub -all {\002|\003[0-9]{1,2},[0-9]{1,2}|\003[0-9]{1,2}|\003|\026|\037|\033\133.*\;} $message {}]
		}
		
		# Sanitize messages to the game server
		proc escape {message} {
			return [string map [list \" {\"}] $message]
		}
		
		proc sanitizeChat {message} {
			return [::ap::func::escape [::ap::func::stripIrcColor $message]]
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
		}
	}
	
	namespace eval callback {
		variable who {}
		variable target {}
		variable private false
		variable args {}
		
		proc execute {cbWho cbTarget cbPrivate cbArgs cbFile} {
			set ::ap::callback::who $cbWho
			set ::ap::callback::target $cbTarget
			set ::ap::callback::private $cbPrivate
			set ::ap::callback::args $cbArgs
			
			if {[file exists $cbFile]} {
				# if we catch something other than 0, we have a faild callback!
				if {[catch {source $cbFile} error_msg]} {
					::ap::debug [namespace current] "$cbFile failed with $error_msg"
				}
				return 1
			} else {
				::ap::debug [namespace current] "file $cbFile does not exist"
				return 0
			}
		}
		
		proc getArgs {} {
			return [lrange $::ap::callback::args 1 end]
		}
		
		proc getArg index {
			if {[numArgs] > $index} {
				return [lindex $::ap::callback::args $index]
			} else {
				return {}
			}
		}
		
		proc numArgs {} {
			return [llength $::ap::callback::args]
		}
		
		proc command {} {
			return [getArg 0]
		}
		
		proc who {} {
			return $::ap::callback::who
		}
		
		proc private {} {
			return $::ap::callback::private
		}
		
		proc target {{append {}}} {
			if {$append == {}} {
				return $::ap::callback::target
			} else {
				return [join [list $::ap::callback::target $append] {::}]
			}
		}
		
		namespace eval say {
			proc public {message} {
				[::ap::callback::target public] [::ap::callback::who] $message
			}
			
			proc private {message} {
				[::ap::callback::target private] [::ap::callback::who] $message
			}
			
			proc reply {message} {
				[::ap::callback::target reply] [::ap::callback::private] [::ap::callback::who] $message
			}
		}
	}
}
