#!/bin/bash

# Function to insert venue into XML
insert_venue() {
    local pn="$1"
    local ln="$2"
    
    # Insert the venue into the XML and sort it
    xmlstarlet ed -s "//venues" -t elem -n "venue" -v "$pn" ../../data/venues.xml | \
    xmlstarlet ed -u "//venue[last()]" -v "$ln" | \
    xmlstarlet fo > /usr/local/bin/venues.xml

    # Reassign IDs here after insertion, sorting alphabetically
    sort_venues_by_pn
}

# Function to sort venues alphabetically by prompt name (pn)
sort_venues_by_pn() {
    xmlstarlet fo /usr/local/bin/venues.xml | \
    xmlstarlet ed -d "//venue" | \
    xmlstarlet ed -s "//venues" -t elem -n "venue" -v "$(sort_venues_logic)" > ../../data/venues.xml
}
