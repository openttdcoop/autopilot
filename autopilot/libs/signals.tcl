#!/usr/bin/tclsh

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

# to get hold of the signal function
package require Tclx

namespace eval ::ap::signals {
	
	# list of supported signals
	variable list [list SIGALRM SIGHUP SIGPOLL SIGPROF SIGTERM SIGUSR1 SIGUSR2 SIGCONT SIGABRT SIGILL SIGQUIT]
	
	proc getlist {} {
		variable supported {}
		variable ignored {}
		
		# get a list of supported signals
		foreach sig [signal get *] {
			lappend supported [lindex $sig 0]
		}
		
		# filter
		foreach sig $::ap::signals::list {
			
			if {[lsearch -exact $supported $sig] == -1} {
				variable index [lsearch $::ap::signals::list $sig]
				lappend ignored $sig
				set ::ap::signals::list [lreplace $::ap::signals::list $index $index]
			}
		}
		
		::ap::debug [namespace current] "WARNING: ignoring signals $ignored"
		return $::ap::signals::list
	}
	
	proc init {} {
		signal trap [::ap::signals::getlist] {::ap::signals::loadSignal %S}
	}
	
	proc loadSignal {signal} {
		::ap::signals::sourceSignal "$signal.tcl"
	}
	
	proc sourceSignal {signalfile} {
		set signalfile "autopilot/signal/$signalfile"
		if {[file exists $signalfile]} {
			if {[catch {source $signalfile} error_msg]} {
				::ap::debug [namespace current] "$signalfile failed with $error_msg"
			}
		} else {
			::ap::debug [namespace current] "signalfile $signalfile does not exist"
		}
	}
	
	::ap::signals::init
}
