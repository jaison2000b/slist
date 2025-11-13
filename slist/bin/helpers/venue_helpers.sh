#!/bin/bash

# Function to display the available venues from venues.xml
display_venues() {
    # Use xmlstarlet to extract and display the venues in the list from venues.xml
    xmlstarlet sel -t -m "//venue" -v "concat(@id, ': ', ln)" -n ../../data/venues.xml
}

# Function to format and return a venue name based on the input ID or manual entry
prompt_venue() {
    echo "Select a venue from the list below by entering the corresponding number:"
    # Display venues here
    display_venues
    read -p "Enter the number of the venue (or 0 for a custom venue): " venue_id

    if [[ "$venue_id" == "0" ]]; then
        # If 0 is selected, prompt for manual venue input
        read -p "Enter the name of the venue manually: " custom_venue
        selected_venue="$custom_venue"
    else
        # Retrieve the selected venue name from the venues.xml file
        selected_venue=$(xmlstarlet sel -t -v "//venue[@id='$venue_id']/ln" ../../data/venues.xml)
    fi

    echo "Selected venue: $selected_venue"
}

# Function to update the venues.xml file by adding a new venue
add_venue() {
    read -p "Enter the name of the new venue: " new_venue
    # Ensure the venue list is ordered alphabetically
    venue_id=$(xmlstarlet sel -t -m "//venue" -v "count(//venue)")  # Get the next available ID (based on the count of current venues)
    venue_id=$((venue_id + 1))  # Increment to avoid overwriting existing entries

    # Add the new venue to venues.xml
    xmlstarlet ed -s "/venues" -t elem -n "venue" -v "" \
        -i "/venues/venue[last()]" -t attr -n "id" -v "$venue_id" \
        -i "/venues/venue[last()]" -t elem -n "ln" -v "$new_venue" \
        ../../data/venues.xml > ../../data/venues.xml.tmp && mv ../../data/venues.xml.tmp ../../data/venues.xml

    echo "New venue '$new_venue' added with ID $venue_id."
}
