#!/bin/bash

figlet "SDDM" -f slant | lolcat

# Disable lightdm and GDM
echo "Disabling lightdm and GDM... (dont worry about the error messages)"
sudo systemctl disable lightdm.service
sudo systemctl disable gdm.service
echo " Done."

# Enable sddm
echo "Enabling sddm..."
sudo systemctl enable sddm
echo " Done."

# Where is my sddm theme? echo whole config into the file
echo "Setting up where is my sddm theme..."
sudo tee /usr/share/sddm/themes/where_is_my_sddm_theme/theme.conf >/dev/null <<EOF
[General]
# Password mask character
passwordCharacter=*
# Mask password characters or not ("true" or "false")
passwordMask=true
# value "1" is all display width, "0.5" is a half of display width etc.
passwordInputWidth=0.5
# Background color of password input
passwordInputBackground=
# Radius of password input corners
passwordInputRadius=
# "true" for visible cursor, "false"
passwordInputCursorVisible=true
# Font size of password (in points)
passwordFontSize=69
passwordCursorColor=random
passwordTextColor=
# Allow blank password (e.g., if authentication is done by another PAM module)
passwordAllowEmpty=false

# Enable or disable cursor blink animation ("true" or "false")
cursorBlinkAnimation=true

# Show or not sessions choose label
showSessionsByDefault=true
# Font size of sessions choose label (in points).
sessionsFontSize=14

# Show or not users choose label
showUsersByDefault=true
# Font size of users choose label (in points)
usersFontSize=14
# Show user real name on label by default
showUserRealNameByDefault=true

# Path to background image
background=
# Or use just one color
backgroundFill=#000000
backgroundFillMode=aspect

# Default text color for all labels
basicTextColor=#808080

# Blur radius for background image
blurRadius=0

# Hide cursor
hideCursor=false
EOF
echo " Done."

# Sddm theme setup
echo "Setting up sddm theme..."
sudo mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=where_is_my_sddm_theme" | sudo tee /etc/sddm.conf.d/theme.conf >/dev/null
echo " Done."

echo "Sddm Configuration complete."
