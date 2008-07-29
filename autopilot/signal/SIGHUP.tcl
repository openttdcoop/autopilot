if {[namespace exists mod_irc]} {
	::mod_irc::network::quit "reloading config"
}

# Fetch in our library of functions
source autopilot/libs/main.tcl

# Check the config, and include support for extra features
if {[setting_enabled [get_setting autopilot use_irc]]} {
        source autopilot/libs/irc.tcl
}

if {[setting_enabled [get_setting autopilot use_mysql]]} {
        source autopilot/libs/mysql.tcl
}

if {[setting_enabled [get_setting autopilot use_signals]]} {
        source autopilot/libs/signals.tcl
}

if {[setting_enabled [get_setting autopilot use_gui]]} {
        source autopilot/libs/gui.tcl
        # Wait for the GUI to actually become visible
        tkwait vis .
}
