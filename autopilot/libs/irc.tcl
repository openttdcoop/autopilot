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

namespace eval ::mod_irc {

	# connection
	variable irc [::irc::connection]
	
	variable ops [list]

	# config
	namespace eval config {
		set server [::ap::config::get autopilot irc_server]
		set port [::ap::config::get autopilot irc_port]
		set user [::ap::config::get autopilot irc_user]
		set nick [::ap::config::get network player_name]
		set channel [::ap::config::get autopilot irc_channel]
		set commandchar [::ap::config::get autopilot irc_commandchar]
		if [::ap::config::isEnabled autopilot irc_bridge] { set bridge 1 } {set bridge 0}
		if [::ap::config::isEnabled autopilot irc_explicit_say] { set explicit_say 1 } {set explicit_say 0 }
	}

	# means of communicating with people on irc
	namespace eval say {

		# Procedure to send IRC notices
		proc notice {nick message} {
			$::mod_irc::irc send "NOTICE $nick :$message"
		}

		# (depricated) chat publicly to channel
		proc channel {nick {message {}}} {
			::ap::debug [namespace current]::channel depricated
			set message [::ap::func::getChatMessage $nick $message]
			::mod_irc::say::public $message
		}
		
		# public chat
		proc public {nick {message {}}} {
			set message [::ap::func::getChatMessage $nick $message]
			$::mod_irc::irc send "PRIVMSG $::mod_irc::config::channel :$message"
		}
		
		# private chat
		proc private {nick message} {
			$::mod_irc::irc send "PRIVMSG $nick :$message"
		}
		
		# reply as has been addressed
		proc reply {private nick message} {
			if {$private} {
				::mod_irc::say::private $nick $message
			} else {
				::mod_irc::say::public $nick $message
			}
		}
	}

	namespace eval do {

		# how to do an irc action (private or public)
		proc action {target message} {
			variable message "\001ACTION $message\001"
			if {[::mod_irc::chatIsPrivate $target]} {
				::mod_irc::say::private $target $message
			} else {
				::mod_irc::say::channel $message
			}
		}

		# how to do a ctcp reply
		proc ctcpReply {target type message} {
			::mod_irc::say::notice $target "\001[string toupper $type] $message\001"
		}
	}

	namespace eval network {

		# how to connect to a server
		proc connect {} {
			set code [catch {$::mod_irc::irc connect $::mod_irc::config::server $::mod_irc::config::port}]
			if {$code} {
				# connection failed
				::ap::debug [namespace current] "$code: $::lang::irc_connect_fail"
				after 5000 ::mod_irc::network::connect
			} else {
				::ap::debug [namespace current] $::lang::irc_connected
				$::mod_irc::irc user $::mod_irc::config::user localhost domain "$::version"
				$::mod_irc::irc nick $::mod_irc::config::nick
				
				# identify with nickserv if required
				set nickservtask [::ap::config::get autopilot irc_nickserv]
				if {$nickservtask != {}} {
					$::mod_irc::irc send $nickservtask
				}
				
				::mod_irc::network::join $::mod_irc::config::channel
			}
		}

		# how to disconnect (quit)
		proc quit {message} {
			if {[$::mod_irc::irc connected]} {
				$::mod_irc::irc quit $message
			}
		}

		# how to join a channel
		proc join {channel} {
			$::mod_irc::irc join $channel
			::mod_irc::network::names $channel
		}

		# how to leave a channel
		proc part {channel} {
			$::mod_irc::irc part $channel
		}

		# send a request for all names in the channel (lists op status)
		proc names {channel} {
			$::mod_irc::irc send "NAMES $channel"
		}
	}

	namespace eval tell {

		# construct the company list and send according to command received
		proc company_list {target nick} {
			set private [::mod_irc::chatIsPrivate $target]
			company_count
			# Wait a second to allow the Expect to pick up the result from players
			after $::standard_delay [string map "NICK $nick
						PRIVATE $private" {
				for {set i 1} {$i <= $::max_companies} {incr i} {
					# we only want the company if founding date > 1
					if {[lindex $::mainloop::company($i) 3] > 1} {
						::mod_irc::say::reply PRIVATE NICK [format {Company %d (%s): %s} $i [lindex $::mainloop::company($i) 0] [lindex $::mainloop::company($i) 1]]
					}
				}
			}]
		}

		# construct the newgrf list and send according to command received
		proc newgrf_list {target nick} {
			if {![::mod_irc::chatIsPrivate $target]} {
				::mod_irc::say::channel "$nick: this command can only be used in a private message"
			} else {
				
				if {[info exists ::apconfig::newgrf]} {
					::mod_irc::say::private $nick {[newgrf]}
					foreach newgrf $::apconfig::newgrf {
						::mod_irc::say::private $nick [lindex $newgrf 0]
					}
					::mod_irc::say::private $nick "$::lang::newgrf_end"
				} else {
					::mod_irc::say::private $nick "No NewGRF's Loaded"
				}
			}
		}

		# construct the client list and send according to command received
		proc player_list {target nick} {
			variable strmap "NICK     $nick
						PRIVATE  [::mod_irc::chatIsPrivate $target]"
			::ap::count::players
			after $::standard_delay [string map $strmap {
				# Wait a second to allow the Expect to pick up the result from clients
				foreach {number} [array names ::mainloop::player] {
					if {[lindex $::mainloop::player($number) 1] > $max_companies} {
						::mod_irc::say::reply PRIVATE NICK [format {Player %d is %s, a spectator} [lindex $::mainloop::player($number) 4] [lindex $::mainloop::player($number) 0]]
					} else {
						::mod_irc::say::reply PRIVATE NICK [format {Player %d (%s) is %s, in company %d (%s)} [lindex $::mainloop::player($number) 4] [lindex $::mainloop::company([lindex $::mainloop::player($number) 1]) 0] [lindex $::mainloop::player($number) 0] [lindex $::mainloop::player($number) 1] [lindex $::mainloop::company([lindex $::mainloop::player($number) 1]) 1]]
					}
				}
			}]
		}
	}

	proc nickIsOp {nick} {
		if {[lsearch -exact $::mod_irc::ops $nick] > -1} {
			return true
		} else {
			return false
		}
	}
	
	proc chatIsPrivate {target} {
		return [string equal $target $::mod_irc::config::nick]
	}
	
	proc isCTCP {message} {
		if {[string first "\001" $message] > -1 && [string last "\001" $message] > -1} {
			return true
		} else {
			return false
		}
	}
	
	# register some callback events
	
	# response from NAMES command
	$::mod_irc::irc registerevent 353 {
		set ::mod_irc::ops [list]
		foreach name [split [msg] { }] {
			#filter channel operators out of the list
			if {[string first {@} $name] == 0} {
				lappend ::mod_irc::ops [string range $name 1 end]
			}
		}
	}
	
	# catch mode changes
	$::mod_irc::irc registerevent MODE {
		::mod_irc::network::names [target]
	}
	
	# catch nickchanges and update the internal list of op's
	$::mod_irc::irc registerevent NICK {
		::mod_irc::network::names [target]
	}
	
	# catch kick
	$::mod_irc::irc registerevent KICK {
		after $::standard_delay [string map "CHANNEL [target]" "::mod_irc::network::join CHANNEL"]
	}
	
	# we join OUR channel on ANY invite!
	$irc registerevent INVITE {
		::mod_irc::network::join $::mod_irc::config::channel
	}
	
	# catch PRIVMSG (this can be private to ap or to the channel...)
	$irc registerevent PRIVMSG {
		variable isPrivate [::mod_irc::chatIsPrivate [target]]
		
		if {$isPrivate && [::mod_irc::isCTCP [msg]]} {
			if {[string match "\001VERSION\001" [msg]]} {
				::mod_irc::do::ctcpReply [who] {version} $::version
			}
			# no need to continue processing!
		} elseif {[string first $::mod_irc::config::commandchar [msg]] == 0 || $isPrivate} {
			
			# get the bang command
			set bang_command [split [msg]]
			if {[string first {!} $bang_command] == 0} {
				set bang_command [string range $bang_command 1 end]
			}
			
			if {$isPrivate} {
				# also use this moment to output to console about the event!
				::ap::debug [namespace parent] [string map {\001 *} "IRC PM from [who]: [msg]"]
			}
			
			# prioritise the responses from the config file
			set bang_command_incomplete true
			foreach response $::ap::config::responses {
				if {[lindex $bang_command 0] == "[lindex $response 0]"} {
					::mod_irc::say::reply $isPrivate [who] [::ap::func::map_strings [lrange $response 1 end]]
					set bang_command_incomplete false
				}
			}
			
			if $bang_command_incomplete {
				# Built-in !bang-commands which can be overriden
				case [lindex $bang_command 0] {
					{version} {
						::mod_irc::say::reply $isPrivate [who] $::version
					}
					{say} {
						::ap::say::toGame "<[who]> [join [lrange $bang_command 1 end]]"
						if {[namespace exists ::mod_db]} {
							::mod_db::log "$::mod_irc::config::channel/[who]: [join [lrange $bang_command 1 end]]"
						}
					}
					{save} {
						::ap::say::everywhere $::lang::saving_game
						::ap::game::save
					}
					{newgrf} {
						::mod_irc::tell::newgrf_list [target] [who]
					}
					{companies} {
						::mod_irc::tell::company_list [target] [who]
					}
					{players} {
						::mod_irc::tell::player_list [target] [who]
					}
					{leave} {
						if {[::mod_irc::nickIsOp [who]]} {
							if {[::mod_irc::chatIsPrivate [target]]} {
								::mod_irc::network::part [lrange $bang_command 1 end]
							} else {
								::mod_irc::network::part [target]
							}
						}
					}
					{rcon} {
						if {[::ap::config::isEnabled autopilot irc_rcon]} {
							puts "\[AP\] rcon via irc from [who]"
							if {[::mod_irc::nickIsOp [who]]} {
								::ap::game::console "[join [lrange $bang_command 1 end]]\r"
							} elseif {$isPrivate && [lindex $bang_command 1] == [::ap::config::get network rcon_password]} {
								::ap::game::console "[join [lrange $bang_command 1 end]]\r"
							} else {
								puts "\[AP\] rcon via irc from [who] not accepted!"
								::mod_irc::say::channel "[who]: you are not allowed to use !rcon"
							}
						}
					}
					{default} {
						variable filename "[lindex $bang_command 0].tcl"
						
						if {[file exists "autopilot/scripts/irc/$filename"]} {
							::ap::callback::execute [who] ::mod_irc::say $isPrivate [lrange $bang_command 0 end] "autopilot/scripts/irc/$filename"
						} elseif {[file exists "autpilot/scripts/global/$filename"]} {
							::ap::callback::execute [who] ::mod_irc::say $isPrivate [lrange $bang_command 0 end] "autopilot/scripts/global/$filename"
						}
					}
				}
			}
		}  elseif {$::mod_irc::config::bridge && !$::mod_irc::config::explicit_say} {
			# Just a general chat
			if { [string match "\001*\001" [msg]] } {
				if { [regexp {^\001ACTION (.+)\001$} [msg] -> msg] } {
					::ap::say::toGame "* [who] $msg"
					if {[namespace exists ::mod_db]} {
						::mod_db::log "$::mod_irc::config::channel:* [who] $msg"
					}
				}
			} else {
				::ap::game::say::public "<[who]> [msg]"
				if {[namespace exists ::mod_db]} {
					::mod_db::log "$::mod_irc::config::channel/[who]: [msg]"
				}
			}
		}
	}
	
	::mod_irc::network::connect	
}
