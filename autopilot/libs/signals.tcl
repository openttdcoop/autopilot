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

puts "Loading Signal Handling\n"

# a list of signals we will handle
set signals [list SIGALRM SIGHUP SIGPOLL SIGPROF SIGTERM SIGUSR1 SIGUSR2 SIGCONT SIGABRT SIGILL SIGQUIT]

proc getsignals {} {
	variable sigs {}
	variable blocked {}
	
	foreach sig [signal get *] {
		lappend sigs [lindex $sig 0]
	}
	
	foreach sig $::signals {
		
		if {[lsearch -exact $sigs $sig] == -1} {
			variable index [lsearch $::signals $sig]
			lappend blocked $sig
			set ::signals [lreplace $::signals $index $index]
		}
	}
	
	::ap::debug WARNING "unsupported signals: $blocked"
	return $::signals
}

proc sigsource {filename} {
	set signalfile "autopilot/signal/$filename"
	if {[file exists $signalfile]} {
		source $signalfile
	} else {
		puts "file does not exist $signalfile\n"
	}
}

proc sig_SIGALRM {} {
	sigsource SIGALRM.tcl
}

proc sig_SIGHUP {} {
	sigsource SIGHUP.tcl
}

proc sig_SIGPOLL {} {
	sigsource SIGPOLL.tcl
}

proc sig_SIGPROF {} {
	sigsource SIGPROF.tcl
}

proc sig_SIGTERM {} {
	sigsource SIGTERM.tcl
}

proc sig_SIGUSR1 {} {
	sigsource SIGUSR1.tcl
}

proc sig_SIGUSR2 {} {
	sigsource SIGUSR2.tcl
}

proc sig_SIGCONT {} {
	sigsource SIGCONT.tcl
}

proc sig_SIGABRT {} {
	sigsource SIGABRT.tcl
}

proc sig_SIGILL {} {
	sigsource SIGILL.tcl
}

proc sig_SIGQUIT {} {
	sigsource SIGQUIT.tcl
}

signal trap [getsignals] sig_%S
