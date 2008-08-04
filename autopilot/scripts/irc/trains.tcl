if {![::mod_irc::nickIsOp [who]]} {
	say::public "you must be channel op to use [command]"
} elseif {[numArgs] != 2 || ![string is integer [getArg 1]]} {
	say::reply "[command] <integer>: set value of max_trains"
} else {
	# we are ops and have one argument that is an integer
	::ap::game::console "patch max_trains $numtrains\r"
	::ap::say::everywhere "*** [who] has set max_trains to $numtrains"
}
