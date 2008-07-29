if {[::mod_irc::nickIsOp [who]]} {
	variable numtrains [lindex $bang_command 1]
	exp_send -i $::ds "patch max_trains $numtrains\r"
	# publicly announce the config changes
	say_everywhere "[who] set max_trains to $numtrains"
} else {
	$replyto "[who]: you must be operator for this command"
}
