package require http
variable url "http://binaries.openttd.org/nightlies/trunk/$::ottd_version/changelog.txt"
variable data [::http::data [::http::geturl $url]]
variable num 0

if {[getArg 1] == "url"} {
	say::reply $url
	return
}

::mod_irc::say::more::clear [who]
foreach line [split $data "\n"] {
	if {[string trim $line] != {} && [string first {-} $line] == 0 && [string first {--} $line] == -1} {
		::mod_irc::say::more::add [who] $line
	}
}

::mod_irc::say::more::sendNext [who] 5 [private]
