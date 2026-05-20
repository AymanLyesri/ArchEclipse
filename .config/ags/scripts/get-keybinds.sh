#!/usr/bin/env bash

file="$HOME/.config/hypr/config/bind.lua"

json_escape() {
  sed 's/\\/\\\\/g; s/"/\\"/g'
}

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

extract_bind_expr() {
  # Get the first argument of hl.bind(...) (non-greedy up to first comma)
  echo "$1" | sed -n 's/^[[:space:]]*hl\.bind(\([^,]*\),.*/\1/p'
}

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

echo "{"

while IFS= read -r line; do
  # Track main modifier
  if [[ "$line" =~ ^[[:space:]]*local[[:space:]]+mainMod[[:space:]]*=[[:space:]]*\"(.+)\" ]]; then
    main_mod="${BASH_REMATCH[1]}"
    continue
  fi

  # Category
  if [[ "$line" =~ ^[[:space:]]*--[[:space:]]*##[[:space:]]*(.+)$ ]]; then
    # If a previous category with binds was opened, close its array
    if [[ "$category_open" == true ]]; then
      echo
      echo "  ],"
      category_open=false
    fi

    # We remember the new category, but do NOT output it to JSON yet.
    pending_category="$(printf '%s' "${BASH_REMATCH[1]}" | json_escape)"
    first_item=true
    continue
  fi

  # Description
  if [[ "$line" =~ ^[[:space:]]*--[[:space:]]*#[[:space:]]*(.+)$ ]]; then
    current_comment="$(printf '%s' "${BASH_REMATCH[1]}" | json_escape)"
    continue
  fi

  # Capturing a string with a bind
  if [[ "$line" =~ ^[[:space:]]*hl\.bind && -n "$current_comment" ]]; then

    # If this is the first bind for a pending category, we display its title!
    if [[ -n "$pending_category" ]]; then
      echo "  \"$pending_category\": ["
      pending_category="" # Reset the wait
      category_open=true  # Note that the category array is open
      first_item=true
    fi

    # We write the bind itself only if the category was successfully opened.
    if [[ "$category_open" == true ]]; then
      bind_expr="$(extract_bind_expr "$line")"
      combo="$(normalize_combo "$bind_expr")"

      keys_json="$(extract_keys "$combo")"
      [[ "$first_item" = false ]] && echo "    ,"
      echo "    {"
      echo "      \"description\": \"$current_comment\","
      echo "      \"keys\": $keys_json"
      echo "    }"
      first_item=false

      current_comment=""
    fi
  fi
done < "$file"

# We close the array of the last category only if it contained binds
if [[ "$category_open" == true ]]; then
  echo
  echo "  ]"
fi

echo "}"
