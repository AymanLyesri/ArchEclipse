file=$HOME/.config/hypr/configs/custom/keyboard.conf

# sed -i 's/kb_variant=dvorak/kb_variant=new_variant/g' $file
#create the file if it doesn't exist
touch "$file"
#!/bin/bash

# Function to check and replace 'kb_variant=dvorak,' with 'kb_variant=,'
function replace_dvorak_with_comma {
    sed -i 's/kb_variant=dvorak,/kb_variant=,dvorak/g' "$file"
}

# Function to check and replace 'kb_variant=,' with 'kb_variant=dvorak,'
function replace_comma_with_dvorak {
    sed -i 's/kb_variant=,dvorak/kb_variant=dvorak,/g' "$file"
}

# Check if 'kb_variant=dvorak,' exists, if yes, replace with 'kb_variant=,'
if grep -q 'kb_variant=dvorak,' "$file"; then
    replace_dvorak_with_comma "$file"
    notify-send "Keyboard Layout" "Qwerty"
    
    # Check if 'kb_variant=,' exists, if yes, replace with 'kb_variant=dvorak,'
    elif grep -q 'kb_variant=,dvorak' "$file"; then
    replace_comma_with_dvorak "$file"
    notify-send "Keyboard Layout" "Dvorak"
    
else
    echo "No 'kb_variant=dvorak,' or 'kb_variant=,' found in $file"
fi
