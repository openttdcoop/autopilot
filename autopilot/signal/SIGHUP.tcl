if {[namespace exists ::mod_irc]} {
	::mod_irc::network::quit "reloading config"
}

# Fetch in our library of functions
source autopilot/libs/main.tcl

# Check the config, and include support for extra features
if {[::ap::config::isEnabled autopilot use_irc]} {
        source autopilot/libs/irc.tcl
}

if {[::ap::config::isEnabled autopilot use_mysql]} {
        source autopilot/libs/mysql.tcl
}

if {[::ap::config::isEnabled autopilot use_signals]} {
        source autopilot/libs/signals.tcl
}
