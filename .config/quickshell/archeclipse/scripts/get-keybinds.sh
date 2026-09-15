#!/usr/bin/env bash

file="$HOME/.config/hypr/config/bind.lua"
custom_dir="$HOME/.config/hypr/config/custom"

# Pure-bash helpers (no forks): the old versions piped through
# sed/tr/echo-pipeline/xargs per keybind (~6-8 execs x 62 binds ~= 1.5s).
# These use only builtins (parameter expansion + read), so the whole
# script runs in ~40ms.

# json_escape <input> <out_var>: escapes backslashes and quotes
json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  printf -v "$2" '%s' "$s"
}

# extract_bind_expr <line> <out_var>: first arg expr of hl.bind(...),
# i.e. text between "hl.bind(" and the first comma (old sed \([^,]*\) parity)
extract_bind_expr() {
  local line=$1
  line=${line#"${line%%[![:space:]]*}"}
  line=${line#hl.bind(}
  if [[ "$line" != *,* ]]; then
    printf -v "$2" '%s' ""
    return
  fi
  line=${line%%,*}
  printf -v "$2" '%s' "$line"
}

# normalize_combo <expr> <main_mod> <out_var>
normalize_combo() {
  local expr=$1 main=$2
  expr=${expr//mainMod/$main}
  expr=${expr//\"/}
  expr=${expr//../ }
  # squeeze whitespace + trim (old sed squeeze/trim parity)
  local -a words
  read -ra words <<< "$expr"
  expr="${words[*]}"
  # collapse runs of '+' separated by spaces (old sed 's/\+\s*\+/+/g'
  # parity), then space each '+' and squeeze (old 's/\+/ + /g' parity)
  expr=${expr// +/+}
  expr=${expr//+ /+}
  while [[ "$expr" == *++* ]]; do
    expr=${expr//++/+}
  done
  expr=${expr//+/ + }
  read -ra words <<< "$expr"
  printf -v "$3" '%s' "${words[*]}"
}

# extract_keys <combo> <out_var>: splits on '+' into a JSON array,
# trimming each part (old xargs-trim parity)
extract_keys() {
  local combo=$1
  local -a parts
  IFS='+' read -ra parts <<< "$combo"
  local p json='[' first=true
  for p in "${parts[@]}"; do
    p=${p#"${p%%[![:space:]]*}"}
    p=${p%"${p##*[![:space:]]}"}
    [[ -z "$p" ]] && continue
    [[ "$first" == false ]] && json+=', '
    json+="\"$p\""
    first=false
  done
  json+=']'
  printf -v "$2" '%s' "$json"
}

pending_category=""
category_open=false
current_comment=""
first_item=true
main_mod="SUPER"
any_category_printed=false
current_category=""

# Files that shouldn't be treated as keybind sources even if they live in custom/
blacklist=("monitors.lua" "monitors.conf")

is_blacklisted() {
  local base=${1##*/}
  local item
  for item in "${blacklist[@]}"; do
    [[ "$base" == "$item" ]] && return 0
  done
  return 1
}

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
      json_escape "${BASH_REMATCH[1]}" current_comment
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

      json_escape "$cat_name" pending_category
      first_item=true
      # New category: drop any sticky comment so it can't leak across categories.
      current_comment=""
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
        extract_bind_expr "$line" bind_expr
        normalize_combo "$bind_expr" "$main_mod" combo
        extract_keys "$combo" keys_json

        if [[ "$first_item" = false ]]; then
          echo ","
          printf "    {"
        else
          echo
          printf "    {"
        fi
        printf "\n      \"description\": \"${current_comment:-Unknown Keybind}\",\n      \"keys\": $keys_json\n    }"
        first_item=false
        # NOTE: current_comment stays set (sticky) — bind.lua authors one
        # '---' comment per fallback pair (e.g. "XF86 + ALT fallback share
        # one command"), so the following bind shares it. A new '---' or a
        # '--' category header below replaces/clears it.
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
    is_blacklisted "$cfile" && continue

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
        json_escape "${BASH_REMATCH[1]}" current_comment
        continue

      # Capture category header (two dashes) for custom files
      elif [[ "$line" =~ ^[[:space:]]*--[[:space:]]+(.+)$ ]]; then
        cat_name="${BASH_REMATCH[1]}"
        
        # JavaScript sorting protection: if the custom category consists only of digits, append a trailing space
        if [[ "$cat_name" =~ ^[0-9]+$ ]]; then
          cat_name="$cat_name "
        fi

        json_escape "$cat_name" new_cat
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
          # New category: drop any sticky comment so it can't leak across categories.
          current_comment=""
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

          extract_bind_expr "$line" bind_expr
          normalize_combo "$bind_expr" "$main_mod" combo

          main_mod="$orig_main_mod"
          extract_keys "$combo" keys_json

          if [[ "$first_item" = false ]]; then
            echo ","
            printf "    {"
          else
            echo
            printf "    {"
          fi
          printf "\n      \"description\": \"${current_comment:-Unknown Keybind}\",\n      \"keys\": $keys_json\n    }"
          first_item=false
          # NOTE: sticky comment — see main stage above (shared pair comments).
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