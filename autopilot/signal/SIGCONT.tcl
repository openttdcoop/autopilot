if {[::ap::config::isEnabled autopilot use_irc]} {
	::mod_irc::network::connect
}
