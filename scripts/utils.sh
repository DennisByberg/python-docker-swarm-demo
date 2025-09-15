#!/bin/bash

# Utility function to show a spinner while a background process runs
spinner() {
    local pid=$1
    local text="$2"
    local delay=0.1
    local spinstr='|/-\'
    local temp
    local color_counter=0
    
    tput civis
    
    while kill -0 $pid 2>/dev/null; do
        temp=${spinstr#?}
        
        # Cycle between colors every ~1 second
        if [ $((color_counter % 10)) -lt 5 ]; then
            printf "\r\033[91m%c\033[0m %s" "$spinstr" "$text"
        else
            printf "\r\033[95m%c\033[0m %s" "$spinstr" "$text"
        fi
        
        spinstr=$temp${spinstr%"$temp"}
        color_counter=$((color_counter + 1))
        sleep $delay
    done
    
    printf "\r✅ %s\n" "$text"
    tput cnorm
}