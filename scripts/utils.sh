#!/bin/bash

# Utility function to show a spinner while a background process runs
spinner() {
    local pid=$1
    local text="$2"
    local delay=0.1
    local spinstr='|/-\'
    local temp
    
    tput civis
    
    while kill -0 $pid 2>/dev/null; do
        temp=${spinstr#?}
        printf "\r%c %s" "$spinstr" "$text"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    
    printf "\r✅ %s\n" "$text"
    tput cnorm
}