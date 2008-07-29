if {[namespace exists mod_irc]} {
	::mod_irc::network::quit "Quit triggered by signal"
}
