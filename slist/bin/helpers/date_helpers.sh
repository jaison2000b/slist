# Function to format the date (calculating next occurrence)
format_date() {
    local input_date=$1
    local current_year=$(date +"%Y")
    local input_month=${input_date%%/*}
    local input_day=${input_date#*/}

    # Ensure we are getting the correct year if the month and day are in the past
    if [ $input_month -lt $(date +"%m") ] || { [ $input_month -eq $(date +"%m") ] && [ $input_day -lt $(date +"%d") ]; }; then
        ((current_year++))  # Use next year if the date has already passed
    fi

    # Get the full date string: e.g., "Apr  3 Thr"
    full_date=$(date -d "$current_year-$input_month-$input_day" +"%b %d %a")

    # Convert the date string to lowercase (month, day, weekday)
    full_date=$(echo "$full_date" | tr '[:upper:]' '[:lower:]')

    # Split the date into components
    month=$(echo "$full_date" | cut -d' ' -f1)  # e.g., "apr"
    day=$(echo "$full_date" | cut -d' ' -f2)    # e.g., "3" or "12"
    weekday=$(echo "$full_date" | cut -d' ' -f3) # e.g., "thr"

    # Format the day correctly (no leading zero) and adjust space formatting
    if [ ${#day} -eq 1 ]; then
        # Single digit day: Add two spaces after the month
        formatted_date="$month  $day $weekday"
    else
        # Double digit day: Add one space after the month
        formatted_date="$month $day $weekday"
    fi

    echo "$formatted_date"
}
