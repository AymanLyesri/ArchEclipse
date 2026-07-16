#!/bin/bash
#
# Lists audio OUTPUT devices for the reactive-wallpaper selector, one per line as
#   <monitor source name><TAB><friendly description>
# (Wallpaper Engine reacts to a sink's ".monitor" source.)

pactl list sinks 2>/dev/null | awk -F': ' '
    /^[[:space:]]*Name:/        { name = $2 }
    /^[[:space:]]*Description:/ { if (name != "") { print name ".monitor" "\t" $2; name = "" } }
'
