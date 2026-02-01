RAM_DIR=/dev/shm                         # RAM directory
scriptsDirC=$HOME/.config/hypr/scripts-c # c scripts directory

gcc $scriptsDirC/battery-loop.c -o $RAM_DIR/battery-loop
gcc $scriptsDirC/updates-loop.c -o $RAM_DIR/updates-loop
gcc $scriptsDirC/posture-loop.c -o $RAM_DIR/posture-loop
gcc $scriptsDirC/hyprpaper-loop.c -o $RAM_DIR/hyprpaper-loop

$RAM_DIR/battery-loop &
$RAM_DIR/updates-loop &
$RAM_DIR/posture-loop &
$RAM_DIR/hyprpaper-loop &

rm $RAM_DIR/battery-loop
rm $RAM_DIR/updates-loop
rm $RAM_DIR/posture-loop
rm $RAM_DIR/hyprpaper-loop
