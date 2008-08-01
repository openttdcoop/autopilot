set f [open "autopilot/custom_say" r]
set content [read $f]
close $f
set lines [split $content "\n"]

foreach line $lines {
	if {[string length $line] > 0} {
		::ap::say::everywhere [::ap::func::map_strings $line]
	}
}

