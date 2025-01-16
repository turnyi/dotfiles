ALERT_IF_IN_NEXT_MINUTES=300
ALERT_POPUP_BEFORE_SECONDS=10000
CATPUCCIN_BG=#1e1e2e
CATPUCCIN_RED=#f38ba8
NERD_FONT_FREE="󱁕"
NERD_FONT_MEETING="󰤙"
NERD_FONT_SEPARATOR=""


get_next_meeting() {
	next_meeting=$(icalBuddy \
		--includeEventProps "datetime,title,attendees,notes" \
		--propertyOrder "datetime,title,attendees,notes" \
		--includeOnlyEventsFromNowOn \
		--noCalendarNames \
		--dateFormat "%A" \
		--timeFormat "%H:%M:%S" \
		--limitItems 1 \
		--excludeAllDayEvents \
		--separateByDate \
		--bullet "" \
		eventsToday)

title=$(echo "$next_meeting" | sed -n '4p' | sed 's/^ *//;s/ *$//')
date_time=$(echo "$next_meeting" | sed -n '3p')
start_time=$(echo "$date_time" | awk -F " - " '{print $1}')  # Extracts start time
# end_time=$(echo "$date_time" | awk -F " - " '{print $2}')
attendees=$(echo "$next_meeting"| sed -n '5p' | sed 's/^ *//;s/ *$//' | sed "s/attendees: //")
notes=$(echo "$next_meeting" | sed -n '6,$p' | sed 's/^ *//;s/ *$//' | sed "s/notes: //")
meet_url=$(echo "$notes" | grep -Eo '(https?://(us02web\.zoom\.us|meet\.google\.com|teams\.microsoft\.com)/[^\ ]+)' | sed 's/<\/a>//g')
}

calculate_times() {
  epoc_meeting=$(date -j -f "%H:%M:%S" "$start_time" +%s)
	epoc_now=$(date +%s)
	epoc_diff=$((epoc_meeting - epoc_now))
	minutes_till_meeting=$((epoc_diff / 60))
}

print_tmux_status() {
  if [[ $minutes_till_meeting -ge $ALERT_IF_IN_NEXT_MINUTES || $minutes_till_meeting -le -60 ]]; then
      echo "#[bold,bg=$CATPUCCIN_BG] $NERD_FONT_SEPARATOR $NERD_FONT_FREE"
      exit 0
  fi

  echo "#[fg=$CATPUCCIN_RED,bold,bg=$CATPUCCIN_BG] $NERD_FONT_SEPARATOR $NERD_FONT_MEETING $title ($minutes_till_meeting minutes)"
	if [[ $epoc_diff -lt $ALERT_POPUP_BEFORE_SECONDS && epoc_diff -lt $ALERT_POPUP_BEFORE_SECONDS+10 ]]; then
	 	display_popup
	fi
}

open_chrome_profile() {
	local attendees="$1"
	local selected_url="$2"
	declare -A email_to_profile=(
		["martin.radovitzky@gmail.com"]="Profile 1"
		["402martin@gmail.com"]="Profile 1"
		["martin.radovitzky@stridefunding.com"]="Profile 2"
		["martin.radovitzky@qubika.com"]="Profile 4"
	)
	local matched=false

	for email in "${!email_to_profile[@]}"; do
		if echo "$attendees" | grep -q "$email"; then
			local profile="${email_to_profile[$email]}"
			echo "Matching email found: $email"
			echo "Opening Chrome with profile: $profile"

     bash "$HOME/scripts/launch_chrome.sh" "$profile" "$selected_url"
			matched=true
			break
		fi
	done
	if [ "$matched" = false ]; then
		echo "No matching email found. Opening Chrome with the default profile."
    tmux new-window "/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --args --profile-directory='Default' '$selected_url'"
	fi
}

display_popup() {
	header="$title - $date_time \n\n"

	formatted_attendees=$(echo "$attendees" | sed -e 's/: /:\n/' -e 's/, /\n  • /g' | sed 's/\(.*:\)/\1\n  • /')
	selected_url=$(printf "%s\n" "${meet_url[@]}" | fzf-tmux --header="Select Meet URL" --preview="echo \"$header$formatted_attendees\"" --preview-window=right:50% --border --height=40% -p)
	if [ -n "$selected_url" ]; then
		open_chrome_profile "$attendees" "$selected_url"
	else
		echo "No URL selected. Exiting..."
	fi

}

main() {
  get_next_meeting
  calculate_times
	print_tmux_status
}

main
