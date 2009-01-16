# Copyright 2008 Georg Lorenz, Nathanael Rebsch. All rights reserved.
# Autopilot (ap+) for use on OpenTTD dedicated server console.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

::msgcat::mcmset en {
	module_load_irc          {Loading module: IRC (version %s)}
	module_load_mysql        {Loading module: MySQL (version %s)}

	autopilot_license        {GNU General Public License v2 or later}
	autopilot_engaged        {Autopilot engaged}

	dbg_autopilot_no_config  {config file %s has no autopilot section}

	game_start_save          {Loading savegame: '%s'}
	game_start_default       {Loading default savegame}
	game_start_new           {Starting new game: '%s'}

	game_spec_start_year     {Starting year: %s}
	game_spec_landscape      {Landscape: %s}
	game_spec_dimensions     {Dimensions: %0.0fx%0.0f}

	game_saving              {Saving game...}
	game_saved               {Game saved}

	game_client_list_spec    {Client %d is %s, a spectator}
	game_client_list_comp    {Client %d (%s) is %s, in company %d (%s)}
	game_client_list_none    {There are currently no clients connected to the server}
	game_clients             {%s clients online}

	game_company_list_item   {Company %d (%s): %s}
	game_company_list_none   {No companies exist in the current game}
	game_companies           {%s companies}
	
	game_grflist_none        {No NewGRF's Loaded}
	game_grflist_end         {End of newgrf list}
	game_grflist_private     {%s: this command can only be used in a private message}
	
	game_quit_message        {Server has exited}
	game_quit_by_admin       {Server closed down by admin}

	irc_network_connected     {IRC connection established}
	irc_channel_joined        {IRC channel joined}
	irc_rcon_denied           {%s: you are not allowed to use !rcon}

	dbg_callback_not_found   {no callback file found: %s}
	dbg_callback_failed      {%s failed with %s}

	dbg_irc_rcon_request      {[AP] rcon via irc from %s}
	dbg_irc_rcon_denied       {[AP] rcon via irc from %s not accepted!}

	dbg_signal_ignoring       {WARNING: ignoring signals: %s}
	dbg_signal_failed         {%s failed with %s}
	dbg_signal_file_not_found {signalfile %s does not exist}
}
