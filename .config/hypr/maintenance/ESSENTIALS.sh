export FZF_HEIGHT="40%"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

install_fzf() {
    if command_exists fzf; then
        echo "fzf is already installed."
    else
        echo "fzf is not installed. Installing fzf..."
        
        # Clone fzf repository from GitHub
        sudo pacman -S fzf
    fi
}

install_figlet() {
    if command_exists figlet; then
        echo "figlet is already installed."
    else
        echo "figlet is not installed. Installing figlet..."
        # Install figlet
        sudo pacman -S figlet
    fi
}

install_git() {
    if command_exists git; then
        echo "git is already installed."
    else
        echo "git is not installed. Installing git..."
        # Install git
        sudo pacman -S git
    fi
}

# Function to install yay
install_yay() {
    if command_exists yay; then
        echo "yay is already installed."
    else
        echo "yay is not installed. Installing yay..."
        
        # Update system packages
        sudo pacman -Syu --noconfirm
        
        # Install base-devel and git if not already installed
        sudo pacman -S --needed --noconfirm base-devel git
        
        # Clone yay repository from the AUR
        git clone https://aur.archlinux.org/yay.git
        
        # Change directory to yay folder
        cd yay
        
        # Build and install yay
        makepkg -si --noconfirm
        
        # Go back to the original directory
        cd ..
        
        # Clean up by removing the yay directory
        rm -rf yay
        
        echo "yay has been successfully installed."
    fi
}

install_browser() {
    title=''
    package=''
    app=''
    
    echo "Choose a browser to install (recommended: zen-browser)"
    # List of browsers to install (space-separated)
    browsers=("zen-browser" "firefox" "chromium" "google-chrome") # Replace with actual browser names
    browser=$(echo "${browsers[@]}" | tr ' ' '\n' | fzf --height $FZF_HEIGHT)
    echo "Browser selected: $browser"
    case $browser in
        zen-browser)
            title="Zen Browser"
            package="zen-browser-bin"
            app="zen-browser"
        ;;
        firefox)
            title="Firefox"
            package="firefox"
            app="firefox"
        ;;
        chromium)
            title="Chromium"
            package="chromium"
            app="chromium"
        ;;
        google-chrome)
            title="Google Chrome"
            package="google-chrome"
            app="google-chrome"
        ;;
    esac
    
    yay -S --noconfirm $package
    
    # echo config into browser.conf
    echo -e "exec-once = $app \n windowrule = workspace 2 silent, match:title ^($title)$" >$HOME/.config/hypr/configs/defaults/browser.conf
    
}

install_discord_client() {
    class=''
    package=''
    app=''
    
    echo "Choose a Discord client to install (recommended: legcord)"
    cords=("legcord" "discord" "betterdiscord")
    cord=$(echo "${cords[@]}" | tr ' ' '\n' | fzf --height $FZF_HEIGHT)
    echo "Discord client selected: $cord"
    case $cord in
        legcord)
            class="legcord"
            package="legcord"
            app="legcord"
        ;;
        discord)
            class="discord"
            package="discord"
            app="discord"
        ;;
        betterdiscord)
            class="BetterDiscord"
            package="betterdiscord"
            app="betterdiscord"
        ;;
    esac
    
    yay -S --noconfirm $package
    
    echo -e "workspace = 6, gapsout:69, on-created-empty:$class \n windowrule = workspace 6 silent, match:class ^($class)$" >$HOME/.config/hypr/configs/defaults/discord_client.conf
}

# Function to install paru
install_paru() {
    if command_exists paru; then
        echo "paru is already installed."
    else
        echo "paru is not installed. Installing paru..."
        
        # Update system packages
        sudo pacman -Syu --noconfirm
        
        # Install base-devel and git if not already installed
        sudo pacman -S --needed --noconfirm base-devel git
        
        # Clone paru repository from the AUR
        git clone https://aur.archlinux.org/paru.git
        
        # Change directory to paru folder
        cd paru
        
        # Build and install paru
        makepkg -si --noconfirm
        
        # Go back to the original directory
        cd ..
        
        # Clean up by removing the paru directory
        rm -rf paru
        
        echo "paru has been successfully installed."
    fi
}

remove_packages() {
    packages_to_remove=("dunst" "swaync") # Replace with actual package names
    
    installed_packages=()
    
    for pkg in "${packages_to_remove[@]}"; do
        if pacman -Q "$pkg" &>/dev/null; then
            installed_packages+=("$pkg")
            pkill -x "$pkg" 2>/dev/null # More precise than killall
        fi
    done
    
    if [[ ${#installed_packages[@]} -gt 0 ]]; then
        echo "Removing packages: ${installed_packages[*]}"
        sudo pacman -Rns --noconfirm "${installed_packages[@]}"
    else
        echo "No specified packages are installed."
    fi
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
            [Yy]*)
                echo -e "${GREEN}Great! Continuing...${RESET}"
                $2
                break
            ;;
            [Nn]*)
                echo -e "${RED}Okay, exiting...${RESET}"
                break
            ;;
            *) echo -e "${RED}Please answer with Y or N.${RESET}" ;;
        esac
    done
}
