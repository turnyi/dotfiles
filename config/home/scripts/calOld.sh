#!/bin/bash

ALERT_IF_IN_NEXT_MINUTES=30
ALERT_POPUP_BEFORE_SECONDS=10
CATPUCCIN_BG=#1e1e2e
CATPUCCIN_RED=#f38ba8
NERD_FONT_FREE="󱁕"
NERD_FONT_MEETING="󰤙"
NERD_FONT_SEPARATOR=""

get_attendees() {
	attendees=$(
		icalBuddy \
			--includeEventProps "attendees" \
			--propertyOrder "datetime,title" \
			--noCalendarNames \
			--dateFormat "%A" \
			--includeOnlyEventsFromNowOn \
			--limitItems 1 \
			--excludeAllDayEvents \
			--separateByDate \
			--excludeEndDates \
			--bullet "" \
			--excludeCals "training,omerxx@gmail.com" \
			eventsToday
	)
}

parse_attendees() {
	attendees_array=()
	for line in $attendees; do
		attendees_array+=("$line")
	done
	number_of_attendees=$((${#attendees_array[@]} - 3))
}

get_next_meeting() {
	next_meeting=$(icalBuddy \
		--includeEventProps "title,datetime" \
		--propertyOrder "datetime,title" \
		--noCalendarNames \
		--dateFormat "%A" \
		--timeFormat "%H:%M" \
		--includeOnlyEventsFromNowOn \
		--limitItems 1 \
		--excludeAllDayEvents \
		--separateByDate \
		--bullet "" \
		--excludeCals "training,omerxx@gmail.com" \
		eventsToday)
}

get_next_next_meeting() {
	end_timestamp=$(date +"%Y-%m-%d ${end_time}:01 %z")
	tonight=$(date +"%Y-%m-%d 23:59:00 %z")
	next_next_meeting=$(
		icalBuddy \
			--includeEventProps "title,datetime" \
			--propertyOrder "datetime,title" \
			--noCalendarNames \
			--dateFormat "%A" \
			--limitItems 1 \
			--excludeAllDayEvents \
			--separateByDate \
			--bullet "" \
			--excludeCals "training,omerxx@gmail.com" \
			eventsFrom:"${end_timestamp}" to:"${tonight}"
	)
}

parse_result() {
	array=()
	for line in $1; do
		array+=("$line")
	done
	time="${array[2]}"
	end_time="${array[4]}"
	title="${array[*]:5:30}"
}

calculate_times() {
	epoc_meeting=$(date -j -f "%T" "$time:00" +%s)
	epoc_now=$(date +%s)
	epoc_diff=$((epoc_meeting - epoc_now))
	minutes_till_meeting=$((epoc_diff / 60))
}

display_popup() {
	# Get event details from iCalBuddy
	event_details=$(icalBuddy \
		--propertyOrder "datetime,title" \
		--noCalendarNames \
		--formatOutput \
		--includeOnlyEventsFromNowOn \
		--limitItems 1 \
		--excludeAllDayEvents \
		--excludeCals "training" \
		eventsToday)

	event_title=$(icalBuddy \
		--propertyOrder "title" \
		--noCalendarNames \
		--formatOutput \
		--includeEventProps "title" \
		--includeOnlyEventsFromNowOn \
		--limitItems 1 \
		--excludeAllDayEvents \
		eventsToday)

	event_time=$(icalBuddy \
		--propertyOrder "datetime" \
		--noCalendarNames \
		--formatOutput \
		--includeEventProps "datetime" \
		--includeOnlyEventsFromNowOn \
		--limitItems 1 \
		--excludeAllDayEvents \
		eventsToday)

	attendees=$(icalBuddy \
		--noCalendarNames \
		--formatOutput \
		--includeEventProps "attendees" \
		--includeOnlyEventsFromNowOn \
		--limitItems 1 \
		--excludeAllDayEvents \
		eventsToday)

	urls=($(echo "$event_details" | grep -Eo 'https://[a-zA-Z0-9./?=_-]+' | uniq | grep -E '(meet|zoom)'))

	header="$event_title - $event_time \n\n"

	formatted_attendees=$(echo "$attendees" | sed -e 's/: /:\n/' -e 's/, /\n  • /g' | sed 's/\(.*:\)/\1\n  • /')
	echo "$formatted_attendees"
	selected_url=$(printf "%s\n" "${urls[@]}" | fzf-tmux --header="Select Meet URL" --preview="echo \"$header$formatted_attendees\"" --preview-window=right:50% --border --height=40% -p)
	if [ -n "$selected_url" ]; then
		open_chrome_profile "$attendees" "$selected_url"
	else
		echo "No URL selected. Exiting..."
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

			/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --args --profile-directory="$profile" "$selected_url"
			matched=true
			break
		fi
	done
	if [ "$matched" = false ]; then
		echo "No matching email found. Opening Chrome with the default profile."
		/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --args --profile-directory="Default" "$selected_url"
	fi
}
print_tmux_status() {
	# && $number_of_attendees -gt 1  \
	if [[ $minutes_till_meeting -lt $ALERT_IF_IN_NEXT_MINUTES &&
		$minutes_till_meeting -gt -60 ]]; then
		echo "#[fg=$CATPUCCIN_RED,bold,bg=$CATPUCCIN_BG] \
			$NERD_FONT_SEPARATOR \
			$NERD_FONT_MEETING \
			$time $title ($minutes_till_meeting minutes)"
	else
		echo "#[bold,bg=$CATPUCCIN_BG] $NERD_FONT_SEPARATOR $NERD_FONT_FREE"
	fi

	if [[ $epoc_diff -gt $ALERT_POPUP_BEFORE_SECONDS && epoc_diff -lt $ALERT_POPUP_BEFORE_SECONDS+10 ]]; then
		display_popup
	fi
}

main() {
	get_attendees
	parse_attendees
	get_next_meeting
	parse_result "$next_meeting"
	calculate_times
	# always show the next calendar event
	# if [[ "$next_meeting" != "" && $number_of_attendees -lt 2 ]]; then
	# 	get_next_next_meeting
	# 	parse_result "$next_next_meeting"
	# 	calculate_times
	# fi
	print_tmux_status
	# echo "$minutes_till_meeting | $number_of_attendees"
}

main
