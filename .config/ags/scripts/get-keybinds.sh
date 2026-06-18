#!/usr/bin/env bash

file="$HOME/.config/hypr/config/bind.lua"
custom_dir="$HOME/.config/hypr/config/custom"

# Escapes special characters for valid JSON output
json_escape() {
  sed 's/\\/\\\\/g; s/"/\\"/g'
}

# Splits a modifier/key combination string (separated by '+') into a JSON array of strings
extract_keys() {
  local combo="$1"
  local part
  local first

  combo=$(echo "$combo" | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')

  printf '['
  first=true
  while IFS= read -r part; do
    part=$(echo "$part" | xargs)
    [[ -z "$part" ]] && continue
    [[ "$first" = false ]] && printf ', '
    printf '"%s"' "$part"
    first=false
  done <<< "$(echo "$combo" | tr '+' '\n')"
  printf ']'
}

# Extracts the first argument (key combination expression) from hl.bind(...)
extract_bind_expr() {
  echo "$1" | sed -n 's/^[[:space:]]*hl\.bind(\([^,]*\),.*/\1/p'
}

# Normalizes key expressions by replacing variables and cleaning up whitespace/plus signs
normalize_combo() {
  local expr="$1"
  expr=${expr//mainMod/$main_mod}
  expr=${expr//\"/}
  expr=${expr//../ }
  expr=$(echo "$expr" | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//; s/\+\s*\+/+/g; s/\+\s*\+/+/g; s/\+/ + /g; s/[[:space:]]\+/ /g')
  echo "$expr"
}

pending_category=""
category_open=false
current_comment=""
first_item=true
main_mod="SUPER"
any_category_printed=false
current_category=""

echo "{"

# 1. First stage: Parse the main bind.lua file
if [[ -f "$file" ]]; then
  while IFS= read -r line; do
    # Track the mainMod variable definition
    if [[ "$line" =~ ^[[:space:]]*local[[:space:]]+mainMod[[:space:]]*=[[:space:]]*\"(.+)\" ]]; then
      main_mod="${BASH_REMATCH[1]}"
      continue
    fi

    # Capture keybind description (three dashes)
    if [[ "$line" =~ ^[[:space:]]*---[[:space:]]*(.+)$ ]]; then
      current_comment="$(printf '%s' "${BASH_REMATCH[1]}" | json_escape)"
      continue
    # Capture category header (two dashes)
    elif [[ "$line" =~ ^[[:space:]]*--[[:space:]]+(.+)$ ]]; then
      if [[ "$category_open" == true ]]; then
        echo
        echo "  ]"
        category_open=false
      fi

      cat_name="${BASH_REMATCH[1]}"
      # JavaScript sorting protection: if the category consists only of digits, append a trailing space
      if [[ "$cat_name" =~ ^[0-9]+$ ]]; then
        cat_name="$cat_name "
      fi

      pending_category="$(printf '%s' "$cat_name" | json_escape)"
      first_item=true
      continue
    fi

    # Process and build the keybind item
    if [[ "$line" =~ ^[[:space:]]*hl\.bind ]]; then
      if [[ -n "$pending_category" ]]; then
        [[ "$any_category_printed" == true ]] && echo ","
        printf "  \"$pending_category\": ["
        current_category="$pending_category"
        pending_category=""
        category_open=true
        any_category_printed=true
        first_item=true
      elif [[ "$category_open" == false ]]; then
        [[ "$any_category_printed" == true ]] && echo ","
        printf "  \"Default Keybinds\": ["
        current_category="Default Keybinds"
        category_open=true
        any_category_printed=true
        first_item=true
      fi

      if [[ "$category_open" == true ]]; then
        bind_expr="$(extract_bind_expr "$line")"
        combo="$(normalize_combo "$bind_expr")"
        keys_json="$(extract_keys "$combo")"

        if [[ "$first_item" = false ]]; then
          echo ","
          printf "    {"
        else
          echo
          printf "    {"
        fi
        printf "\n      \"description\": \"${current_comment:-Unknown Keybind}\",\n      \"keys\": $keys_json\n    }"
        first_item=false
        current_comment=""
      fi
    fi
  done < "$file"
fi

# Close the main file category array if it's still open
if [[ "$category_open" == true ]]; then
  echo
  echo "  ]"
  category_open=false
fi


# 2. Second stage: Append custom files from the custom/ directory to the end of the list
if [[ -d "$custom_dir" ]]; then
  last_category=""

  while IFS= read -r cfile; do
    [[ "$cfile" == *.lua ]] || continue
    [[ -f "$cfile" ]] || continue

    local_main_mod="$main_mod"
    current_comment=""
    file_has_explicit_category=false

    while IFS= read -r line; do
      # Track local file mainMod variable overrides
      if [[ "$line" =~ ^[[:space:]]*local[[:space:]]+mainMod[[:space:]]*=[[:space:]]*\"(.+)\" ]]; then
        local_main_mod="${BASH_REMATCH[1]}"
        continue
      fi

      # Capture keybind description (three dashes)
      if [[ "$line" =~ ^[[:space:]]*---[[:space:]]*(.+)$ ]]; then
        current_comment="$(printf '%s' "${BASH_REMATCH[1]}" | json_escape)"
        continue

      # Capture category header (two dashes) for custom files
      elif [[ "$line" =~ ^[[:space:]]*--[[:space:]]+(.+)$ ]]; then
        cat_name="${BASH_REMATCH[1]}"
        
        # JavaScript sorting protection: if the custom category consists only of digits, append a trailing space
        if [[ "$cat_name" =~ ^[0-9]+$ ]]; then
          cat_name="$cat_name "
        fi

        new_cat="$(printf '%s' "$cat_name" | json_escape)"
        file_has_explicit_category=true

        if [ "$new_cat" != "$last_category" ]; then
          if [[ "$category_open" == true ]]; then
            echo
            echo "  ]"
          fi
          [[ "$any_category_printed" == true ]] && echo ","
          printf "  \"$new_cat\": ["
          category_open=true
          any_category_printed=true
          first_item=true
          last_category="$new_cat"
        fi
        continue
      fi

      # Process and build the keybind item from the custom file
      if [[ "$line" =~ ^[[:space:]]*hl\.bind ]]; then
        # Fallback to "Custom Keybinds" if no explicit category is defined yet in the current file
        if [[ "$file_has_explicit_category" == false && "$last_category" != "Custom Keybinds" ]]; then
          if [[ "$category_open" == true ]]; then
            echo
            echo "  ]"
          fi
          [[ "$any_category_printed" == true ]] && echo ","
          printf "  \"Custom Keybinds\": ["
          category_open=true
          any_category_printed=true
          first_item=true
          last_category="Custom Keybinds"
        fi

        if [[ "$category_open" == true ]]; then
          orig_main_mod="$main_mod"
          main_mod="$local_main_mod"

          bind_expr="$(extract_bind_expr "$line")"
          combo="$(normalize_combo "$bind_expr")"

          main_mod="$orig_main_mod"
          keys_json="$(extract_keys "$combo")"

          if [[ "$first_item" = false ]]; then
            echo ","
            printf "    {"
          else
            echo
            printf "    {"
          fi
          printf "\n      \"description\": \"${current_comment:-Unknown Keybind}\",\n      \"keys\": $keys_json\n    }"
          first_item=false
          current_comment=""
        fi
      fi
    done < "$cfile"

  done < <(find "$custom_dir" -type f -name "*.lua" | sort)

  # Close the very last open category array from custom files before wrapping up the root object
  if [[ "$category_open" == true ]]; then
    echo
    echo "  ]"
  fi
fi

echo
echo "}"