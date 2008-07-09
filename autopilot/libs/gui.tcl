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

puts $::lang::load_tk_module
package require Tk

# Set our widgets
frame .output
set ::gui::main .output.main
set ::gui::mainscroll .output.mainscroll
frame .control
set ::gui::companylist .control.companylist
set ::gui::companyscroll .control.companyscroll
set ::gui::playerlist .control.playerlist
set ::gui::playerscroll .control.playerscroll
set ::gui::input .input
frame .control.buttons
set ::gui::stop .control.buttons.stop
set ::gui::quit .control.buttons.quit
set ::gui::add .add
set ::gui::status .control.status

# Define our widgets
text $::gui::main -foreground lightgrey -background black -font {Courier 11} -wrap word -yscrollcommand "$::gui::mainscroll set"
scrollbar $::gui::mainscroll -orient vertical -command "$::gui::main yview"
listbox $::gui::companylist -foreground lightgrey -background black
listbox $::gui::playerlist -foreground lightgrey -background black
entry $::gui::input
button $::gui::stop -text $::lang::gui_refresh -command player_count
button $::gui::quit -text $::lang::gui_quit -command {
   say_everywhere $::lang::admin_quit
   exp_send -i $::ds "quit\r"
}
label $::gui::status -textvariable ::ap_status
button $::gui::add -text $::lang::gui_enter -command gui_send_chat

# Define our layout
grid .output .control -sticky news
grid rowconfigure .output 0 -weight 1
grid columnconfigure .output 0 -weight 1
grid rowconfigure .control 2 -weight 1
grid $::gui::main $::gui::mainscroll
grid configure $::gui::main -sticky news
grid configure $::gui::mainscroll -sticky news
grid $::gui::companylist
grid configure $::gui::companylist -sticky news
grid $::gui::playerlist
grid configure $::gui::playerlist -sticky news
grid $::gui::status
grid .control.buttons -sticky news -columnspan 2
grid columnconfigure .control.buttons "0 1" -uniform buttoncols -weight 1
grid $::gui::input $::gui::add -sticky news
grid $::gui::stop $::gui::quit -sticky news
grid rowconfigure . 0 -weight 1
grid columnconfigure . 0 -weight 1

# Key bindings
bind $::gui::input <Return> gui_send_chat

# Colours, as seen in the game
array set ::gui::colors {
   {Dark Blue} {#1C448C}
   {Pale Green} {#4C7458}
   Pink {#BC546C}
   Yellow {#D49C20}
   Red {#C40000}
   {Light Blue} {#347084}
   Green {#548414}
   {Dark Green} {#50683C}
   Blue {#1878DC}
   Cream {#B87050}
   Mauve {#505074}
   Purple {#684CC4}
   Orange {#FC9C00}
   Brown {#7C6848}
   Grey {#747474}
   White {#B8B8B8}
   system {#FFFF80}
   none {}
}

# Create correct color tags for the main chat log
foreach colorpair [array names ::gui::colors] {
   $::gui::main tag config $colorpair -foreground $::gui::colors($colorpair)
}

puts [$::gui::main tag names]

proc gui_say_internal message {
   set y [lindex [$::gui::main yview] 1]
   set tag {}
   set premessage {}
   if {[string range $message 0 2] == "***"} {
      set tag system
      set premessage {***}
      set message [string range $message 3 end]
   }
   if {[array size ::mainloop::player] >= 1} {
      for {set p 1} {$p <= [array size ::mainloop::player]} {incr p} {
         if {[lindex $::mainloop::player($p) 0] eq [lindex [split $message :] 0]} {
            set tag [lindex $::mainloop::player($p) 3]
            set premessage "[lindex [split $message :] 0]:"
            set message [join [lrange [split $message :] 1 end] :]
         }
      }
   }
   $::gui::main insert end "$premessage" $tag
   $::gui::main insert end "$message\n" {}
   if {$y == 1} {
      $::gui::main yview end
   }
}

proc gui_send_chat {} {
   set message [$::gui::input get]
   if {$message != {}} {
      if {[string index $message 0] == {/}} {
         exp_send -i $::ds "[string range $message 1 end]\n"
         $::gui_say "*** [string range $message 1 end]"
      } {
         say_everywhere "$::lang::admin_name $message"
      }
   }
   $::gui::input delete 0 end
}

proc gui_close_internal {} {
   destroy .
}

set ::gui_say gui_say_internal
set ::gui_close gui_close_internal
