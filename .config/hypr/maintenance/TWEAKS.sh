figlet "TWEAKS" -f slant | lolcat

# Boosting boot time
echo -e "\tBoosting boot time..."

## Disable NetworkManager-wait-online.service
echo -e "\t\tMasking NetworkManager-wait-online.service..."
sudo systemctl mask NetworkManager-wait-online.service
