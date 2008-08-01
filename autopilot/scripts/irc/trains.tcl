if {[::mod_irc::nickIsOp [who]]} {
	variable numtrains [lindex $bang_command 1]
	::ap::game::console "patch max_trains $numtrains\r"
	# publicly announce the config changes
	::ap::say::everywhere "[who] set max_trains to $numtrains"
} else {
	$replyto "[who]: you must be operator for this command"
}
