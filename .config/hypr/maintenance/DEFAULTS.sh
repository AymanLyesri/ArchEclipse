customDir="$HOME/.config/hypr/configs/custom"
defaultsDir="$HOME/.config/hypr/configs/defaults"

figlet "DEFAULTS" -f slant | lolcat

# restore_defaults() {
#     if [ ! -f "$2" ]; then
#         cp "$1" "$2"
#     fi
# }

echo "Do you want to set up default custom files (not necessary after the first time)"

read -p "y/n: " response

if [ "$response" != "y" ]; then
    echo "Exiting..."
    exit 0
fi

echo "Setting up default configuration files..."

cp $defaultsDir/* $customDir

echo " Done."
