# Fetch in our library of functions
source autopilot/libs/main.tcl

# Check the config, and include support for extra features
if {[setting_enabled [get_setting autopilot use_irc]]} {
        source autopilot/libs/irc.tcl
} else {
        # We use this variable in this file, so we explicitly set it
        # if there is no IRC code
        namespace eval apirc {set bridge 0}
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
