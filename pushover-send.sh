#!/bin/bash

set -euo pipefail

# URL encoding function that properly handles Unicode and special characters
# Based on RFC 3986 standards and current best practices
urlencode() {
    # Handle empty input by returning empty string (no error)
    if [[ -z "$1" ]]; then
        printf '%s' ""
        return 0
    fi
    
    # Save current locale settings and set to C for byte-level processing
    local old_lc_all="${LC_ALL:-}"
    LC_ALL=C
    
    local input="$1"
    local length="${#input}"
    local encoded=""
    
    # Process each character in the input string
    for (( i = 0; i < length; i++ )); do
        local char="${input:$i:1}"
        
        # Characters that don't need encoding (RFC 3986 unreserved characters)
        case "$char" in
            [a-zA-Z0-9.~_-]) 
                encoded+="$char" 
                ;;
            *)
                # Encode all other characters as %XX
                printf -v hex_char '%%%02X' "'$char"
                encoded+="$hex_char"
                ;;
        esac
    done
    
    # Restore original locale
    if [[ -n "$old_lc_all" ]]; then
        LC_ALL="$old_lc_all"
    else
        unset LC_ALL
    fi
    
    # Output the encoded string
    printf '%s' "$encoded"
}

# Source user credentials
CONFIG_FILE="$HOME/.config/pushwrap/pushover.conf"
# Check if config file exists before sourcing
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Config file not found: $CONFIG_FILE"
    exit 1
fi
source "$CONFIG_FILE"
#source "$HOME/.config/pushwrap/pushover.conf"

# Check for credentials
errors=0
if [[ -z "$PUSHOVER_API_KEY" ]]; then
  echo "ERROR: Pushover API Key not provided. Please set it in $CONFIG_FILE."
  ((errors++))
fi
if [[ -z "$PUSHOVER_USER_KEY" ]]; then
  echo "ERROR: Pushover User Key not provided. Please set it in $CONFIG_FILE."
  ((errors++))
fi
if ((errors > 0)); then
  echo "Terminating program..."
  exit 1
fi

# Check for default title
title="${PUSHOVER_TITLE:-Pushover}"


# Test cases for Pushover API
test_cases=(
    "test@example.com"
    ""
)

for test_string in "${test_cases[@]}"; do
    # URL encode the message
    encoded=$(urlencode "$test_string")
    echo "Original message: '$test_string'"
    echo "Encoded message: '$encoded'"
    # Check if encoded message is empty and skip API call
    if [[ -z "$encoded" ]]; then
      echo "Skipping empty message (API will reject)"
      echo "---"
      continue
    fi
    
    # URL encode the title as well (in case it has special characters)
    encoded_title=$(urlencode "$title")
    
    # Construct the curl command - using double quotes to allow variable expansion
    command="curl -X POST -d 'token=$PUSHOVER_API_KEY' -d 'user=$PUSHOVER_USER_KEY' -d 'message=$encoded' -d 'title=$encoded_title' -i https://api.pushover.net/1/messages.json"
    
    echo "Command: $command"
    echo "---"
    
    # Execute the command
    eval "$command"
    echo
    echo "---"
    
    sleep 10
done
