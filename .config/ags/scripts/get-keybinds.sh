#!/usr/bin/env bash

file="$HOME/.config/hypr/configs/bind.conf"

json_escape() {
  sed 's/\\/\\\\/g; s/"/\\"/g'
}

extract_keys() {
  # example input:
  # bind = SUPER CTRL, 1, movetoworkspace, 1
  local line="$1"

  # strip everything before =
  line="${line#*=}"

  # take first two comma-separated fields
  local mods key
  mods="$(echo "$line" | cut -d',' -f1 | xargs)"
  key="$(echo "$line" | cut -d',' -f2 | xargs)"

  # split modifiers into array + append key
  read -ra mod_arr <<< "$mods"

  printf '['
  first=true
  for m in "${mod_arr[@]}" "$key"; do
    [[ "$first" = false ]] && printf ', '
    printf '"%s"' "$m"
    first=false
  done
  printf ']'
}

pending_category=""
category_open=false
current_comment=""
first_item=true

echo "{"

while IFS= read -r line; do
  # Category
  if [[ "$line" =~ ^##[[:space:]]*(.+)$ ]]; then
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

  # Ignore commented out binds and reset the description
  if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*bind ]]; then
    current_comment=""
    continue
  fi

  # Description
  if [[ "$line" =~ ^#[^#][[:space:]]*(.+)$ ]]; then
    current_comment="$(printf '%s' "${BASH_REMATCH[1]}" | json_escape)"
    continue
  fi

  # Capturing a string with a bind
  if [[ "$line" =~ ^[[:space:]]*bind && -n "$current_comment" ]]; then

    # If this is the first bind for a pending category, we display its title!
    if [[ -n "$pending_category" ]]; then
      echo "  \"$pending_category\": ["
      pending_category="" # Reset the wait
      category_open=true  # Note that the category array is open
      first_item=true
    fi

    # We write the bind itself only if the category was successfully opened.
    if [[ "$category_open" == true ]]; then
      keys="$(extract_keys "$line")"

      [[ "$first_item" = false ]] && echo "    ,"

      echo "    {"
      echo "      \"description\": \"$current_comment\","
      echo "      \"keys\": $keys"
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
