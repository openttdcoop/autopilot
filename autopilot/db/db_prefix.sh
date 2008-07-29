#!/bin/sh
# OK, this is simple and dirty.  It'll add the prefix specifiedon the command
# line to the SQL CREATE statements in autopilot.sql, saving the result as
# a file of the same name but with the prefix prefixed.

# Free to use and distribute.  No warranty.
# If this breaks, you get to keep all the pieces.

sed "s/CREATE TABLE IF NOT EXISTS \`/CREATE TABLE IF NOT EXISTS \`$1/" < mysql.sql > $1mysql.sql
