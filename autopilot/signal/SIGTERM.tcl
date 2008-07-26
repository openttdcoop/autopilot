exp_send -i $::ds "pause\n"

say_everywhere [map_strings "Server is going down for..."]
say_everywhere [map_strings "Thank you for playing OTTD."]

exp_send -i $::ds [map_strings "save autosave/OTTD_exit\n"]
exp_send -i $::ds "quit\n"
