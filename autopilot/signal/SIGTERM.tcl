exp_send -i $::ds "pause"

say_everywhere [map_strings "Server is going down for maintenence..."]
say_everywhere [map_strings "Thank you for playing OTTD."]

exp_send -i $::ds [map_version "save autosave/OTTD_exit\r"]
exp_send -i $::ds "quit\n"
