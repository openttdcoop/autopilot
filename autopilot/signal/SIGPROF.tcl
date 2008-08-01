set f [open "autopilot/custom_cmd" r]
set content [read $f]
close $f
set lines [split $content "\n"]

foreach line $lines {
	if {[string length $line] > 0} {
		::ap::game::console [::ap::func::map_strings "$line\r"]
	}
}

