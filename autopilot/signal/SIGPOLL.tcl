set datetime [clock format [clock seconds] -format %Y%m%d-%H%M%s]
exp_send -i $::ds [map_strings {save autosave/OTTD_$datetime\n}]
