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

# Set database table prefix
set db_prefix [get_setting autopilot mysql_prefix]
append tbl_chatlog $db_prefix {chatlog}
append tbl_game    $db_prefix {game}
append tbl_setup   $db_prefix {setup}
append tbl_server  $db_prefix {server}
append tbl_user    $db_prefix {user}

# Connect to database
set autopilot_db [::mysql::connect -host [get_setting autopilot mysql_server] -user [get_setting autopilot mysql_user] -password [get_setting autopilot mysql_pass] -db [get_setting autopilot mysql_database]]

set db_gameserver [get_setting autopilot mysql_gameserver]
set sql "SELECT value FROM $tbl_setup WHERE setting='current_game' AND server=$db_gameserver"
set db_gamenumber [::mysql::sel $autopilot_db $sql -flatlist]
set sql "REPLACE INTO `$tbl_server` SET `id`=$::db_gameserver, `name`=\'[::mysql::escape $::autopilot_db [get_setting network server_name]]\'"
::mysql::exec $autopilot_db $sql

set db_log db_log_internal
set db_set_password db_set_password_internal
set db_close db_close_internal
set db_new_game db_new_game_internal

every 1800000 {
   ::mysql::ping $::autopilot_db
}

proc db_log_internal message {
   set sql "INSERT INTO `$::tbl_chatlog` SET `game`=$::db_gamenumber, `log`='[::mysql::escape $::autopilot_db $message]'"
   mysqlexec $::autopilot_db $sql
}

proc db_set_password_internal {} {
   set sql "REPLACE INTO `$::tbl_setup` SET `value`=\'[::mysql::escape $::autopilot_db $::password]\', `server`=$::db_gameserver, `setting`='password'"
   mysqlexec $::autopilot_db $sql
}

proc db_close_internal {} {
   ::mysql::close $::autopilot_db
}

proc db_new_game_internal title {
   set name [::mysql::escape $::autopilot_db "[get_setting network server_name] [clock format [clock seconds] -format %D-%T]"]
   set sql "INSERT INTO `$::tbl_game` SET `name`=\'$name\', `server`=$::db_gameserver"
   mysqlexec $::autopilot_db $sql
   set ::db_gamenumber [::mysql::insertid $::autopilot_db]
   set sql "REPLACE INTO `$::tbl_setup` SET `value`=\'$::db_gamenumber\', `server`=$::db_gameserver, `setting`='current_game'"
   mysqlexec $::autopilot_db $sql
}
