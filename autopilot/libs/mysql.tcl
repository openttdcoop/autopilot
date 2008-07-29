# Copyright 2006 Brian Ronald.  All rights reserved.
# Autopilot for use on OpenTTD dedicated server console.
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

puts $::lang::load_mysql_module
package require mysqltcl

namespace eval mod_db {
	
	variable db {}
	
	namespace eval config {
		variable host   [get_setting autopilot mysql_server]
		variable user   [get_setting autopilot mysql_user]
		variable pass   [get_setting autopilot mysql_pass]
		variable db     [get_setting autopilot mysql_database]
		variable prefix [get_setting autopilot mysql_prefix]
		
		variable server [get_setting autopilot mysql_gameserver]
		variable game   {}
	}
	
	namespace eval table {
		variable chatlog $::mod_db::config::prefix
		variable game    $::mod_db::config::prefix
		variable setup   $::mod_db::config::prefix
		variable server  $::mod_db::config::prefix
		variable user    $::mod_db::config::prefix
		
		append chatlog chatlog
		append game    game
		append setup   setup
		append server  server
		append user    user
	}
	
	proc connect {} {
		set ::mod_db::db [::mysql::connect -host $::mod_db::config::host -user $::mod_db::config::user -password $::mod_db::config::pass -db $::mod_db::config::db]
	}
	
	proc disconnect {} {
		::mysql::close $::mod_db::db
	}
	
	proc escape {message} {
		return [::mysql::escape $::mod_db::db $message]
	}
	
	proc execute {sql} {
		::mysql::exec $::mod_db::db $sql
	}
	
	proc select {sql} {
		return [::mysql::sel $::mod_db::db $sql -flatlist]
	}
	
	proc init {} {
		variable sql "SELECT value FROM $::mod_db::table::setup WHERE setting='current_game' AND server=$::mod_db::config::server"
		set ::mod_db::config::game [::mod_db::select $sql]
		
		variable sql "REPLACE INTO $::mod_db::table::server SET id=$::mod_db::config::server, name='[::mod_db::escape [get_setting network server_name]]'"
		::mod_db::execute $sql
	}
	
	proc log {message} {
		variable sql "INSERT INTO $::mod_db::table::chatlog SET game=$::mod_db::config::game, log='[::mod_db::escape $message]'"
		::mod_db::execute $sql
	}
	
	proc set_password {password} {
		variable sql "REPLACE INTO $::mod_db::table::setup SET value='[::mod_db::escape $password]', server=$::mod_db::config::server, setting='password'"
		::mod_db::execute $sql
	}

	proc newgame title {
		variable name [::mod_db::escape "[get_setting network server_name] [clock format [clock seconds] -format %D-%T]"]
		variable sql "INSERT INTO $::mod_db::table::game SET name='$name', server=$::mod_db::config::server"
		::mod_db::execute $sql
		
		set ::mod_db::config::game [::mysql::insertid $::mod_db::db]
		variable sql "REPLACE INTO $::mod_db::table::setup SET value='$::mod_db::config::game', server=$::mod_db::config::server, setting='current_game'"
		::mod_db::execute $sql
	}

	# connect before we start pining ;-)
	::mod_db::connect
	::mod_db::init
	
	# have a little keep-alive ;-)
	every 1800000 {
		::mysql::ping $::mod_db::db
	}
}