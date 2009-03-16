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

::msgcat::mcmset de {
	module_load_irc          {Lade Modul: IRC (version %s)}
	module_load_mysql        {Lade Modul: MySQL (version %s)}

	autopilot_license        {GNU General Public License v2 oder später}
	autopilot_engaged        {Autopilot gestartet}

	dbg_autopilot_no_config  {Die Konfigurationsdatei %s hat keine Sektion [autopilot]}

	game_start_save          {Lade Spielstand: '%s'}
	game_start_default       {Lade standard Spielstand}
	game_start_new           {Starte ein neues Spiel: '%s'}

	game_spec_start_year     {Startjahr: %s}
	game_spec_landscape      {Landschaft: %s}
	game_spec_dimensions     {Kartengröße: %0.0fx%0.0f}

	game_saving              {Speichere Spiel...}
	game_saved               {Spiel gespeichert}

	game_client_list_spec    {Client %d ist %s, ein Zuschauer}
	game_client_list_comp    {Client %d (%s) ist %s, in Unternehmen %d (%s)}
	game_client_list_none    {Derzeit sind keine Spieler auf dem Server.}
	game_clients             {%s Clients online}

	game_company_list_item   {Unternehmen %d (%s): %s}
	game_company_list_none   {Es existieren keine Unternehmen im aktuellen Spiel}
	game_companies           {%s Unternehmen}
	
	game_grflist_none        {Keine NewGRF's geladen}
	game_grflist_end         {Ende der NewGRF Liste}
	game_grflist_private     {%s: dieser Befehl kann nur in per privater Nachricht ausgeführt werden}
	
	game_password_none       {Es gibt kein Passwort!}
	
	game_quit_message        {Server beendet}
	game_quit_by_admin       {Server wurde von einem Administrator geschlossen}

	irc_network_connected     {IRC Verbindung hergestellt}
	irc_channel_joined        {IRC channel betreten}
	irc_rcon_denied           {%s: Du hast nicht genügend Rechte um !rcon zu verwenden}

	irc_more_none             {Du hast keine weiteren Nachrichten}
	irc_more_one              {Du hast eine weitere Nachricht}
	irc_more_many             {Du hast %d weitere Nachrichten}

	dbg_callback_not_found   {Keine callback file gefunden: %s}
	dbg_callback_failed      {%s gescheitert mit %s}

	dbg_irc_rcon_request      {[AP] rcon via irc von %s}
	dbg_irc_rcon_denied       {[AP] rcon via irc von %s nicht akzeptiert!}

	dbg_signal_ignoring       {ACHTUNG: Ignoriere Signale: %s}
	dbg_signal_failed         {%s gescheitert mit %s}
	dbg_signal_file_not_found {signalfile %s existiert nicht}
}
