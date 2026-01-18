#!/usr/bin/env bash

file="$HOME/.config/hypr/configs/keybinds.conf"

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

current_category=""
current_comment=""
first_item=true

echo "{"

while IFS= read -r line; do
  # Category
  if [[ "$line" =~ ^##[[:space:]]*(.+)$ ]]; then
    if [[ -n "$current_category" ]]; then
      echo
      echo "  ],"
    fi

    current_category="$(printf '%s' "${BASH_REMATCH[1]}" | json_escape)"
    echo "  \"$current_category\": ["
    first_item=true
    continue
  fi

  # Description
  if [[ "$line" =~ ^#[^#][[:space:]]*(.+)$ ]]; then
    current_comment="$(printf '%s' "${BASH_REMATCH[1]}" | json_escape)"
    continue
  fi

  # Capture next line
  if [[ -n "$current_comment" && -n "$current_category" ]]; then
    keys="$(extract_keys "$line")"

    [[ "$first_item" = false ]] && echo "    ,"

    echo "    {"
    echo "      \"description\": \"$current_comment\","
    echo "      \"keys\": $keys"
    echo "    }"

    first_item=false
    current_comment=""
  fi
done < "$file"

# close last category
if [[ -n "$current_category" ]]; then
  echo
  echo "  ]"
fi

echo "}"
