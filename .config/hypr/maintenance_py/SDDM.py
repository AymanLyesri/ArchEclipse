#!/usr/bin/env python3
"""
SDDM.py - Configure SDDM login manager theme
"""

import subprocess
import os
from components.figlet import print_figlet_lolcat


def main():
    """Main function"""
    print_figlet_lolcat("SDDM")

    # Disable lightdm and GDM
    print("Disabling lightdm and GDM... (don't worry about the error messages)")
    subprocess.run(
        ["sudo", "systemctl", "disable", "lightdm.service"], capture_output=True
    )
    subprocess.run(["sudo", "systemctl", "disable", "gdm.service"], capture_output=True)
    print(" Done.")

    # Enable sddm
    print("Enabling sddm...")
    subprocess.run(["sudo", "systemctl", "enable", "sddm"], capture_output=True)
    print(" Done.")

    # Set up theme configuration
    print("Setting up where is my sddm theme...")

    sddm_conf_content = """[General]
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
"""

    sddm_theme_dir = "/usr/share/sddm/themes/where_is_my_sddm_theme"
    sddm_conf_file = os.path.join(sddm_theme_dir, "theme.conf")

    # Create directory if it doesn't exist
    subprocess.run(["sudo", "mkdir", "-p", sddm_theme_dir], capture_output=True)

    # Write the configuration file
    with open("/tmp/sddm_theme.conf", "w") as f:
        f.write(sddm_conf_content)

    subprocess.run(
        ["sudo", "cp", "/tmp/sddm_theme.conf", sddm_conf_file], capture_output=True
    )
    subprocess.run(["rm", "/tmp/sddm_theme.conf"], capture_output=True)

    print(" Done.")

    # SDDM theme setup
    print("Setting up sddm theme...")
    subprocess.run(["sudo", "mkdir", "-p", "/etc/sddm.conf.d"], capture_output=True)

    theme_conf_content = "[Theme]\nCurrent=where_is_my_sddm_theme\n"
    with open("/tmp/sddm_theme_conf.conf", "w") as f:
        f.write(theme_conf_content)

    subprocess.run(
        ["sudo", "cp", "/tmp/sddm_theme_conf.conf", "/etc/sddm.conf.d/theme.conf"],
        capture_output=True,
    )
    subprocess.run(["rm", "/tmp/sddm_theme_conf.conf"], capture_output=True)

    print(" Done.")

    print("Sddm Configuration complete.")


if __name__ == "__main__":
    main()
