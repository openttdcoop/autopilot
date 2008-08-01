set datetime [clock format [clock seconds] -format %Y%m%d-%H%M%s]
::ap::game::save [::ap::func::map_strings {save autosave/OTTD_$datetime}]
