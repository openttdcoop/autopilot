# English language internationalization file for autopilot 2.0
# Copyright © Brian Ronald, 2006 - licensed under GPL 2 or higher
# See main files for license details

# Default English strings (as defined by the author) are in the
# comments.  Translations go in the curly braces.  This file is
# a Tcl program.

namespace eval lang {

# Loading IRC module
set load_irc_module {Loading IRC module}

# Loading MySQL module
set load_mysql_module {Loading MySQL module}

# Loading Tk GUI module
set load_tk_module {Loading Tk GUI module}

# Autopilot engaged
set engaged {Autopilot engaged}

# Loading specified saved game as %s
set loadspec {Loading specified saved game as '%s'} 

# Loading default saved game as %s
set loaddef {Loading default saved game as '%s'}

# Starting new game named %s
set startnew {Starting new game named '%s'}

# Landscape is %s
set landscape_is {Landscape is %s}

# Map is %0.0f tiles north to south by %0.0f tiles east to west
set map_dimensions {Map is %0.0f tiles north to south by %0.0f tiles east to west}

# Starting year is %s
set start_year {Starting year is %s}

# Server has exited
set server_exited {Server has exited}

# Server closed down by admin
set admin_quit {Server closed down by admin}

# End of newgrf list
set newgrf_end {End of newgrf list}

# Connected to IRC server
set irc_connected {Connected to IRC server}

# Failed to connect to IRC server
set irc_connect_fail {Failed to connect to IRC server (retrying)}

# Saving game...
set saving_game {Saving game...}

# Saved game.
set map_saved {Saved game.}

# Released under the GNU General Public License version 2 or later
set license {Released under the GNU General Public License version 2 or later}

# Admin page from %s on %s
set admin_page {Admin page from %s on %s}

# Body of admin page email
set admin_page_body {This is a page from the autopilot controlling your OpenTTD server.
The client named in the subject has used the page command to attract
your attention as the game's administrator.}

# An admin has been paged
set admin_paged {An admin has been paged by email - please wait}

# Version request from %s acknowledged.
set version_requested {Version request from %s acknowledged}

# Tk GUI widgets
################

# Quit
set gui_quit {Quit}

# Enter
set gui_enter {Enter}

# Refresh
set gui_refresh {Refresh}

# Players: %s
set players {Players: %s}

# Initializing...
set initializing {Initializing...}

# Recounting...
set recounting {Recounting...}

# (admin)
set admin_name {(admin)}

}
