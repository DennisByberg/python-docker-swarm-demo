#!/bin/bash

spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    local temp
    
    tput civis
    
    while kill -0 $pid 2>/dev/null; do
        temp=${spinstr#?}
        printf " %c" "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b"
    done
    
    printf "   \b\b\b"  # Clear spinner
    tput cnorm
    echo  # Add newline here!
}