say::private "Welcome [who]"
say::private "You are playing on \"[::ap::config::get network server_name]\""
say::private [::ap::func::map_strings "House rules are at URL"]
say::private "say !help for more information"
say::private "---"
::ap::say::fromGame "*** [who] joined the game"
