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

puts [::msgcat::mc module_load_irc [package require irc]]

namespace eval ::mod_irc {

	# connection
	variable irc [::irc::connection]
	
	variable ops {}
	variable nicklist {}

	# config
	namespace eval config {
		variable bind_ip [::ap::config::get autopilot irc_bind_ip]
		variable bind_port [::ap::config::get autopilot irc_bind_port]
		variable server [::ap::config::get autopilot irc_server]
		variable port [::ap::config::get autopilot irc_port]
		variable user [::ap::config::get autopilot irc_user]
		variable nick [::ap::config::get network client_name]
		variable channel [::ap::config::get autopilot irc_channel]
		variable channelkey [::ap::config::get autopilot irc_channel_key]
		variable commandchar [::ap::config::get autopilot irc_commandchar]
		variable bridge [::ap::config::isEnabled autopilot irc_bridge]
		variable explicit_say [::ap::config::isEnabled autopilot irc_explicit_say]
		variable eol_style [::ap::config::get autopilot irc_eol_style crlf]
		::irc::config debug [::ap::config::get autopilot irc_debug 0]
		::irc::config verbose [::ap::config::get autopilot irc_verbose 0]
	}

	# means of communicating with people on irc
	namespace eval say {

		# Procedure to send IRC notices
		proc notice {nick message} {
			if {[string length $message] == 0} {
				return
			}
			
			::mod_irc::network::send "NOTICE $nick :$message"
		}

		# public chat
		proc public {nick {message {}}} {
			set message [::ap::func::getChatMessage $nick $message]
			
			if {[string length $message] == 0} {
				return
			}
			
			::mod_irc::network::send "PRIVMSG $::mod_irc::config::channel :$message"
		}
		
		# private chat
		proc private {nick message} {
			if {[string length $message] == 0} {
				return
			}
			
			::mod_irc::network::send "PRIVMSG $nick :$message"
		}
		
		# reply as has been addressed
		proc reply {private nick message} {
			# do not send empty messages
			if {$message == {}} {
				return
			}
			
			if {$private} {
				::mod_irc::say::private $nick $message
			} else {
				::mod_irc::say::public $nick $message
			}
		}
		
		namespace eval more {
			array set ::mod_irc::say::more::buffer {}
			
			proc add {nick message} {
				lappend ::mod_irc::say::more::buffer($nick) $message
			}
			
			proc clear {nick} {
				set ::mod_irc::say::more::buffer($nick) {}
			}
			
			proc size {nick} {
				if {[array names ::mod_irc::say::more::buffer -exact $nick] == {}} {
					return 0
				}
				
				return [llength $::mod_irc::say::more::buffer($nick)]
			}
			
			proc get {nick} {
				variable message {}
				
				if {[array names ::mod_irc::say::more::buffer -exact $nick] != {}} {
					set message [lindex $::mod_irc::say::more::buffer($nick) 0]
					set ::mod_irc::say::more::buffer($nick) [lrange $::mod_irc::say::more::buffer($nick) 1 end]
				}
				
				return $message
			}
			
			proc sendNext {nick {num {}} {private false}} {
				if {$num > [::ap::config::get autopilot irc_more_flush_lines 5] || $num == {}} {
					set num [::ap::config::get autopilot irc_more_flush_lines 5]
				}
				
				if {$num > [size $nick]} {
					set num [size $nick]
				}
				
				after cancel ::mod_irc::say::more::clear $nick
				
				for {variable i 0} {$i < $num} {incr i} {
					::mod_irc::say::reply $private $nick [get $nick]
				}
				
				after [expr [::ap::config::get autopilot irc_more_timeout 120] * 1000] ::mod_irc::say::more::clear $nick
				
				if {[size $nick] > 0} {
					sendStatus $nick $private
				}
			}
			
			proc sendStatus {nick {private false}} {
				variable num [size $nick]
				variable msg [::msgcat::mc irc_more_none]
				
				if {$num == 1} {
					set msg [::msgcat::mc irc_more_one]
				} elseif {$num > 1} {
					set msg [::msgcat::mc irc_more_many $num]
				}
				
				::mod_irc::say::reply $private $nick $msg
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
				::mod_irc::say::public $message
			}
		}

		# how to do a ctcp reply
		proc ctcpReply {target type message} {
			::mod_irc::say::notice $target "\001[string toupper $type] $message\001"
		}
	}

	namespace eval buffer {
		
		variable buf {}
		
		proc add {line} {
			lappend ::mod_irc::buffer::buf $line
		}
		
		proc flush {} {
			for {variable index 0} {$index < [llength $::mod_irc::buffer::buf]} {incr index} {
				::mod_irc::network::send [lindex $::mod_irc::buffer::buf $index]
				lreplace $::mod_irc::buffer::buf $index $index
			}
		}
	}

	namespace eval network {

		# what status do we currently have for the connection
		# -1 none (do nothing)
		#  0 connecting (buffer)
		#  1 fully connected (send directly)
		variable status -1

		# how to connect to a server
		proc connect {} {
			if {$::mod_irc::irc == {}} {
				set ::mod_irc::irc [::irc::connection]
			}
			
			if {[catch {::mod_irc::network::cmd-connect $::mod_irc::config::server $::mod_irc::config::port $::mod_irc::config::bind_ip $::mod_irc::config::bind_port} error_msg]} {
				# connection failed
				set ::mod_irc::network::status -1
				::ap::debug [namespace current] "$error_msg"
				after 5000 ::mod_irc::network::connect
			} else {
				# should default to crlf - but some irc networks dont send that!
				fconfigure [::mod_irc::network::getSocket] -translation $::mod_irc::config::eol_style
				
				set ::mod_irc::network::status 0
				::ap::debug [namespace current] [::msgcat::mc irc_network_connected]
				$::mod_irc::irc user $::mod_irc::config::user localhost domain "$::version"
				$::mod_irc::irc nick $::mod_irc::config::nick
			}
		}

		proc getSocket {} {
			return [set [format "%s::sock" [string replace $::mod_irc::irc [string first {::network} $::mod_irc::irc] end {}]]]
		}
		
		proc setSocket {sock} {
			set [format "%s::sock" [string replace $::mod_irc::irc [string first {::network} $::mod_irc::irc] end {}]] $sock
		}
		
		proc cmd-connect {{host localhost} {port 6667} {bind_ip {}} {bind_port {}}} {
			variable sock [::mod_irc::network::getSocket]
			variable args {}
			
			if {$sock == ""} {
				
				if {$bind_ip != {}} {
					lappend args -myaddr $bind_ip
				}
				
				if {$bind_port != {}} {
					lappend args -myport $bind_port
				}
				
				set sock [eval [concat socket $args $host $port]]
				
				fconfigure $sock -translation crlf -buffering line
				fileevent $sock readable [format "%s::GetEvent" [string replace $::mod_irc::irc [string first {::network} $::mod_irc::irc] end {}]]
				
				::mod_irc::network::setSocket $sock
			}
			
			return 0
		}

		# how to disconnect (quit)
		proc quit {message} {
			if {[$::mod_irc::irc connected]} {
				$::mod_irc::irc quit $message
				$::mod_irc::irc destroy
			}
		}

		# how to join a channel
		proc join {channel {key {}}} {
			$::mod_irc::irc join $channel $key
		}

		# how to leave a channel
		proc part {channel {message {}}} {
			$::mod_irc::irc part $channel $message
		}

		proc send {line} {
			if {[$::mod_irc::irc connected]} {
				if {$::mod_irc::network::status == 1} {
					$::mod_irc::irc send $line
				} elseif {$::mod_irc::network::status == 0} {
					::mod_irc::buffer::add $line
				}
			} elseif {$::mod_irc::network::status > -1} {
				::mod_irc::network::connect
			}
		}

		# send a request for all names in the channel (lists op status)
		proc names {channel} {
			set ::mod_irc::nicklist {}
			
			#refuse to send a global NAMES
			if {$channel == {}} {
				set channel $::mod_irc::config::channel
			}
			
			::mod_irc::network::send "NAMES $channel"
		}
	}

	namespace eval tell {

		# construct the company list and send according to command received
		proc company_list {target nick} {
			set private [::mod_irc::chatIsPrivate $target]
			::ap::count::companies
			# Wait a second to allow the Expect to pick up the result from players
			after $::standard_delay [string map "NICK $nick
						PRIVATE $private" {
				if {[array size ::mainloop::company] > 0} {
					for {variable number 1} {$number < [array size ::mainloop::company]} {incr number} {
						# we only want the company if founding date > 1
						if {[lindex $::mainloop::company($number) 3] > 1} {
							::mod_irc::say::reply PRIVATE NICK [::msgcat::mc game_company_list_item $number [lindex $::mainloop::company($number) 0] [lindex $::mainloop::company($number) 1]]
						}
					}
				} else {
					::mod_irc::say::reply PRIVATE NICK [::msgcat::mc game_company_list_empty]
				}
			}]
		}

		# construct the newgrf list and send according to command received
		proc newgrf_list {target nick} {
			if {![::mod_irc::chatIsPrivate $target]} {
				::mod_irc::say::public [::msgcat::mc game_grflist_private $nick]
			} else {
				
				if {[info exists ::ap::config::newgrf]} {
					::mod_irc::say::private $nick {[newgrf]}
					foreach newgrf $::ap::config::newgrf {
						::mod_irc::say::private $nick [lindex $newgrf 0]
					}
					::mod_irc::say::private $nick [::msgcat::mc game_grflist_end]
				} else {
					::mod_irc::say::private $nick [::msgcat::mc game_grflist_none]
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
				if { $::players > 0 } {
					foreach {number} [lsort [array names ::mainloop::player]] {
						if {[lindex $::mainloop::player($number) 1] > $max_companies} {
							::mod_irc::say::reply PRIVATE NICK [::msgcat::mc game_client_list_spec [lindex $::mainloop::player($number) 4] [lindex $::mainloop::player($number) 0]]
						} else {
							::mod_irc::say::reply PRIVATE NICK [::msgcat::mc game_client_list_comp [lindex $::mainloop::player($number) 4] [lindex $::mainloop::company([lindex $::mainloop::player($number) 1]) 0] [lindex $::mainloop::player($number) 0] [lindex $::mainloop::player($number) 1] [lindex $::mainloop::company([lindex $::mainloop::player($number) 1]) 1]]
						}
					}
				} else {
					::mod_irc::say::reply PRIVATE NICK [::msgcat::mc game_client_list_none]
				}
			}]
		}
	}

	proc nickIsOp {nick} {
		if {[lsearch -exact $::mod_irc::ops $nick] > -1} {
			return 1
		} else {
			return 0
		}
	}
	
	proc chatIsPrivate {target} {
		return [string equal -nocase $target $::mod_irc::config::nick]
	}
	
	proc isCTCP {message} {
		if {[string first "\001" $message] > -1 && [string last "\001" $message] > -1} {
			return true
		} else {
			return false
		}
	}
	
	# register some callback events
	
	# only join our channel once we have the motd ;-)
	$::mod_irc::irc registerevent 376 {
		# identify with nickserv if required
		set nickservtask [::ap::config::get autopilot irc_nickserv]
		if {$nickservtask != {}} {
			$::mod_irc::irc send $nickservtask
		}
		
		# join the channel
		::mod_irc::network::join $::mod_irc::config::channel $::mod_irc::config::channelkey
		
		# flush the buffer
		set ::mod_irc::network::status 1
		::mod_irc::buffer::flush
		
		# run the on_irc_connect callback
		::ap::callback::execute {} ::mod_irc::say 1 [list {[callback] on_irc_connect} [who] [target]] {autopilot/scripts/callback/on_irc_connect.tcl}
	}
	
	# send NAMES after joining a channel
	$::mod_irc::irc registerevent 332 {
		::mod_irc::network::names [target]
	}
	
	# response from NAMES command
	$::mod_irc::irc registerevent 353 {
		append ::mod_irc::nicklist [split [msg]]
	}
	
	# end of NAMES command, start processing the list
	$::mod_irc::irc registerevent 366 {
		if {[additional] != $::mod_irc::config::nick} {
			# clear the ops list
			set ::mod_irc::ops {}
			# find ops (prefixed with @)
			foreach {name} [lsort -unique [split $::mod_irc::nicklist]] {
				if {[string first {@} $name] == 0} {
					lappend ::mod_irc::ops [string range $name 1 end]
				}
			}
			
			# clear the nicklist again!
			set ::mod_irc::nicklist {}
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
	
	# catch users quitting
	$::mod_irc::irc registerevent QUIT {
		::mod_irc::network::names [target]
	}
	
	# catch people leaving the channel
	$::mod_irc::irc registerevent PART {
		::mod_irc::network::names [target]
	}
	
	# catch kick
	$::mod_irc::irc registerevent KICK {
		::ap::callback::execute [who] ::mod_irc::say 1 [list {[callback] on_irc_kick} [target] [additional] [msg]] {autopilot/scripts/callback/on_irc_kick.tcl}
	}
	
	# we join OUR channel on ANY invite!
	$irc registerevent INVITE {
		::mod_irc::network::join $::mod_irc::config::channel $::mod_irc::config::channelkey
	}
	
	# catch PRIVMSG (this can be private to ap or to the channel...)
	$irc registerevent PRIVMSG {
		variable isPrivate [::mod_irc::chatIsPrivate [target]]
		
		if {$isPrivate && [::mod_irc::isCTCP [msg]]} {
			if {[string match "\001VERSION\001" [msg]]} {
				::mod_irc::do::ctcpReply [who] {version} $::version
			}
			# no need to continue processing!
		} elseif {[string first $::mod_irc::config::commandchar [string trim [msg]]] == 0 || $isPrivate} {
			
			# get the bang command
			set bang_command [split [string trim [msg]]]
			if {[string first $::mod_irc::config::commandchar $bang_command] == 0} {
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
					{more} {
						variable arg [lindex $bang_command 1]
						
						if {$arg == {clear}} {
							::mod_irc::say::more::clear [who]
						} elseif {$arg == {status} || [::mod_irc::say::more::size [who]] == 0} {
							::mod_irc::say::more::sendStatus [who] $isPrivate
						} elseif {[string is integer $arg] && $arg > 0} {
							::mod_irc::say::more::sendNext [who] $arg $isPrivate
						} else {
							::mod_irc::say::more::sendNext [who] {1} $isPrivate
						}
					}
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
						::ap::say::everywhere [::msgcat::mc game_saving]
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
								::mod_irc::network::part [lindex $bang_command 1] [lrange $bang_command 2 end]
							} else {
								::mod_irc::network::part [target] [lrange $bang_command 1 end]
							}
						}
					}
					{rcon} {
						if {[::ap::config::isEnabled autopilot irc_rcon]} {
							variable allow_rcon false
							
							if {[::mod_irc::nickIsOp [who]]} {
								set allow_rcon true
							} elseif {$isPrivate && [string equal [lindex $bang_command 1] [::ap::config::get network rcon_password]] && [string length [::ap::config::get network rcon_password]] > 0} {
								set allow_rcon true
							}
							
							# clear the clients more buffer
							::mod_irc::say::more::clear [who]
							
							if {!$allow_rcon} {
								puts [::msgcat::mc dbg_irc_rcon_denied [who]]
								::mod_irc::say::public [::msgcat::mc irc_rcon_denied [who]]
								return
							}
							
							puts [::msgcat::mc dbg_irc_rcon_request [who]]
							
							variable buf [::ap::game::consoleCapture "[join [lrange $bang_command 1 end]]\r"]
							
							foreach line $buf {
								if {[string length [string trim $line]] > 0} {
									::mod_irc::say::more::add [who] $line
								}
							}
								
							::mod_irc::say::more::sendNext [who] {} $isPrivate
						}
					}
					{default} {
						variable filename "[lindex $bang_command 0].tcl"
						
						if {![::ap::callback::execute [who] ::mod_irc::say $isPrivate [lrange $bang_command 0 end] "autopilot/scripts/irc/$filename"]} {
							if {![::ap::callback::execute [who] ::mod_irc::say $isPrivate [lrange $bang_command 0 end] "autopilot/scripts/global/$filename"]} {
								::ap::debug [namespace current] [::msgcat::mc dbg_callback_not_found [lindex $bang_command 0]]
							}
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
