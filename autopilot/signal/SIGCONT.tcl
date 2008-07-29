if {[setting_enabled [get_setting autopilot use_irc]]} {
	::mod_irc::network::connect
}
