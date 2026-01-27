#!/bin/bash

declare -A features=(
  [SDR]=7
  [LORA]=16
  ["Internal USB"]=23
  [GPS]=27
)

selected=0

readPinState() {
  local pin="$1"
  local out
  out=$(pinctrl "$pin")
  if [[ $out =~ \|\ (hi|lo)\ // ]]; then
    [[ "${BASH_REMATCH[1]}" == "hi" ]] && echo "on" || echo "off"
  else
    echo "unknown"
  fi
}

pullPin() {
  local pin="$1"
  local pullup="$2"
  local cmd
  [[ "$pullup" == "on" ]] && cmd="dh" || cmd="dl"
  pinctrl "$pin" op && pinctrl "$pin" "$cmd"
}

readStates() {
  feature_names=()
  feature_states=()
  for feature in "${!features[@]}"; do
    feature_names+=("$feature")
    feature_states+=("$(readPinState "${features[$feature]}")")
  done
  feature_names+=("Exit")
}

toggleFeature() {
  feature="$1"
  old_state="$2"
  [[ "$old_state" == "off" ]] && new_state="on" || new_state="off"
  pullPin "${features[$feature]}" "${new_state}"
}

draw_menu() {
  clear
  echo "Use [ ↑  ][ ↓  ] to navigate, [ ↵  ] to toggle"
  for ((i=0; i<${#feature_names[@]}; i++)); do
    if [ $i -eq $selected ]; then
      indicator=">"
      pre="\e[47;30m"
      post="\e[0m"
    else
      indicator=" "
      pre=""
      post=""
    fi
    [ ${#feature_names[@]} -eq $((i + 1)) ] && line="${feature_names[$i]}" || line="${feature_names[$i]}: ${feature_states[$i]}"
    echo -e "${pre} ${indicator} ${line} ${post}"
  done
}

run() {
  readStates
  # hiding cursor
  tput civis
  trap "tput cnorm; exit" INT TERM EXIT
  # --
  while true; do
    draw_menu
    read -rsn1 key
    if [[ $key == $'\e' ]]; then
      read -rsn2 key
    fi
    case $key in
      '[A') # Up arrow
        ((selected--))
        [ $selected -lt 0 ] && selected=$((${#feature_names[@]} - 1))
        ;;
      '[B') # Down arrow
        ((selected++))
        [ $selected == ${#feature_names[@]} ] && selected=0
        ;;
      '') # Enter key
        if [ $selected -eq $((${#feature_names[@]} - 1)) ]; then
          echo "Bye!"
          exit 0
        else
          toggleFeature "${feature_names[$selected]}" "${feature_states[$selected]}"
          readStates
        fi
        ;;
    esac
  done
  # showing cursor back
  tput cnorm
  # --
}

run
