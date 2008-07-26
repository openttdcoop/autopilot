say_everywhere {Scheduled quit for automated maintenance... will be back shortely}
say_everywhere [map_strings "Thank you for playing OTTD."]

exp_send -i $::ds [map_strings "save autosave/OTTD_exit\n"]
exp_send -i $::ds "quit\n"
