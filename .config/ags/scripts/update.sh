#!/bin/bashopaci

# Check if both action and target are provided
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 < --get|--update> <system|repo>"
    exit 1
fi

# Function to check for system updates
check_system_updates() {
    echo "Checking system updates..."
    
    # Get the list of available updates
    updates=$(checkupdates 2>/dev/null)
    
    # Count the number of lines (each line corresponds to a package)
    num_updates=$(echo "$updates" | wc -l)
    
    if [ "$num_updates" -eq 0 ]; then
        echo "Your system is up to date!"
    else
        echo "$num_updates package(s) need updating."
    fi
}

# Function to update the system
update_system() {
    hyprctl dispatch exec "[float] foot bash -c 'sudo pacman -Syu --noconfirm'"
    # echo "Updating system..."
    
    # # Start pkexec with pacman in the background
    # pkexec pacman -Syu &
    
    # # Get the PID of the pkexec process
    # PKEXEC_PID=$!
    
    # # Function to clean up when the script is terminated
    # cleanup() {
    #     echo "Terminating pkexec and pacman..."
    #     kill $PKEXEC_PID
    #     wait $PKEXEC_PID 2>/dev/null
    #     exit
    # }
    
    # # Trap signals (SIGINT and SIGTERM) to call cleanup
    # trap cleanup SIGINT SIGTERM
    
    # # Wait for the pkexec process to exit
    # wait $PKEXEC_PID
}

# Function to check if a Git repo is behind (compared to the remote)
check_repo_status() {
    echo "Checking repository status..."
    
    # Ensure we are inside a Git repository
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Not a git repository!"
        exit 1
    fi
    
    # Fetch the latest changes from the remote
    git fetch >/dev/null 2>&1
    
    # Compare local and remote branches
    local_commit=$(git rev-parse @)
    remote_commit=$(git rev-parse @{u})
    
    if [ "$local_commit" = "$remote_commit" ]; then
        echo "Your repository is up to date!"
    else
        echo "Your repository is behind or ahead of the remote. Sync it!"
    fi
}

# Function to update the Git repository
update_repo() {
    echo "Updating repository..."
    
    # Ensure we are inside a Git repository
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Not a git repository!"
        exit 1
    fi
    
    # Pull the latest changes
    git pull
}

# Main logic
case "$1" in
    --get)
        case "$2" in
            system)
                check_system_updates
            ;;
            repo)
                check_repo_status
            ;;
            *)
                echo "Invalid target. Usage: $0 < --get|--update> <system|repo>"
                exit 1
            ;;
        esac
    ;;
    --update)
        case "$2" in
            system)
                update_system $3
            ;;
            repo)
                update_repo
            ;;
            *)
                echo "Invalid target. Usage: $0 < --get|--update> <system|repo>"
                exit 1
            ;;
        esac
    ;;
    *)
        echo "Invalid action. Usage: $0 < --get|--update> <system|repo>"
        exit 1
    ;;
esac
