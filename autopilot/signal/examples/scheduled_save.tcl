set datetime [clock format [clock seconds] -format %Y%m%d-%H%M%s]
::ap::game::save [::ap::func::map_strings "autosave/OTTD_$datetime\n"]
