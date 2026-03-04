#!/bin/bash

figlet "LOCALES" -f slant | lolcat

# Function to add locale on Arch Linux
add_arch_locale() {
    echo "Adding en_US.UTF-8 locale to Arch Linux system..."

    # Check if locale is already enabled
    if grep -q "^en_US.UTF-8 UTF-8" /etc/locale.gen; then
        if locale -a | grep -q "en_US.utf8"; then
            echo "Locale en_US.UTF-8 is already installed and enabled."
            return 0
        fi
    fi

    # Uncomment the locale in locale.gen
    echo "Enabling locale in /etc/locale.gen..."
    sudo sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen || {
        echo "en_US.UTF-8 UTF-8" | sudo tee -a /etc/locale.gen
    }

    # Generate the locale
    echo "Generating locale (this may take a moment)..."
    sudo locale-gen

    # Verify the locale was added
    if locale -a | grep -q "en_US.utf8"; then
        echo "Successfully added en_US.UTF-8 locale."
        return 0
    else
        echo "Failed to add en_US.UTF-8 locale."
        return 1
    fi
}

# Main execution
echo "Arch Linux Locale Configuration"
echo "This script will add the en_US.UTF-8 locale to your system."

# Prompt for sudo password upfront
sudo -v || {
    echo "Error: sudo access is required to modify system locales."
    exit 1
}

add_arch_locale

# Set exit code based on result
if [ $? -eq 0 ]; then
    exit 0
else
    exit 1
fi
