# #!/bin/bash

HYPR_DIR="$HOME/.config/hypr"
GENERAL_CONF_FILE="$HYPR_DIR/configs/general.conf"
KEYBOARD_CONF="$HYPR_DIR/configs/custom/keyboard.conf"

FZF_HEIGHT="40%"

configure_keybord() {
    figlet "KEYBOARD" -f slant | lolcat
    
    # List of keyboard layouts
    kb_layouts=$(localectl list-x11-keymap-layouts)
    kb_variants=$(localectl list-x11-keymap-variants)
    
    selected_layouts=""
    selected_variants=""
    
    while true; do
        # Layout selection
        echo "Configuring keyboard layout for Hyprland... (eg: us, es, fr, de, etc)"
        new_layout=$(echo "$kb_layouts" | fzf --height $FZF_HEIGHT)
        
        # Ensure layout is selected
        if [ -z "$new_layout" ]; then
            echo "No layout selected. Please select a layout."
            continue
        else
            echo "Selected layout: $new_layout"
        fi
        selected_layouts="$selected_layouts$new_layout,"
        # Variant selection
        echo "OPTIONAL (tip: leave empty for qwerty): Configuring Custom keyboard variant for Hyprland... (eg: intl, dvorak, etc) or leave it empty (.) "
        new_variant=$(echo "$kb_variants" | fzf --height $FZF_HEIGHT)
        
        # Ensure variant is selected
        if [ -z "$new_variant" ]; then
            echo "No variant selected. Leaving it empty."
        else
            echo "Selected variant: $new_variant"
        fi
        selected_variants="$selected_variants$new_variant,"
        # Use continue_prompt function to check if the user wants to add more
        continue_prompt "Would you like to add another layout and variant pair?" "true"
        if [ "$?" -ne 0 ]; then
            break
        fi
    done
    
    # Remove trailing commas
    selected_layouts=$(echo "$selected_layouts" | sed 's/,$//')
    selected_variants=$(echo "$selected_variants" | sed 's/,$//')
    
    # Apply the changes to the config file
    echo -e "input { \n\tkb_layout=$selected_layouts \n\tkb_variant=$selected_variants \n}" >$KEYBOARD_CONF
    
    echo "Keyboard layouts have been configured to: $selected_layouts"
    echo "Keyboard variants have been configured to: $selected_variants"
    
    # reload the configuration
    hyprctl reload
}

continue_prompt() {
    # Color variables
    GREEN="\e[32m"
    RED="\e[31m"
    CYAN="\e[36m"
    BOLD="\e[1m"
    RESET="\e[0m"
    
    while true; do
        echo -e "${CYAN}${BOLD}$1${RESET} ${GREEN}[Y]${RESET}/${RED}[N]${RESET}: "
        read -p "" choice
        case "$choice" in
            [Yy]* ) echo -e "${GREEN}Great! Continuing...${RESET}";
                return 0;  # Indicate continue
            ;;
            [Nn]* ) echo -e "${RED}Okay, exiting...${RESET}";
                return 1;  # Indicate exit
            ;;
            * ) echo -e "${RED}Please answer with Y or N.${RESET}";;
        esac
    done
}

configure_keybord




