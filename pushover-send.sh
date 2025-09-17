#!/bin/bash

set +H
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

pushover_send() {
  # Validate input argument
  if [[ -z "${1:-}" ]]; then
    echo "ERROR: No message provided to pushover_send()" >&2
    return 1
  fi

  local message="$1"

  # Source user credentials
  local config_file="$HOME/.config/pushwrap/pushover.conf"
  if [[ ! -f "$config_file" ]]; then
    echo "ERROR: Config file not found: $config_file" >&2
    return 1
  fi

  # shellcheck source=/dev/null
  source "$config_file"

  # Check for credentials
  local errors=0
  if [[ -z "${PUSHOVER_API_KEY:-}" ]]; then
    echo "ERROR: Pushover API Key not provided. Please set it in $config_file." >&2
    ((errors++))
  fi
  if [[ -z "${PUSHOVER_USER_KEY:-}" ]]; then
    echo "ERROR: Pushover User Key not provided. Please set it in $config_file." >&2
    ((errors++))
  fi
  if ((errors > 0)); then
    echo "Terminating program..." >&2
    return 1
  fi

  # Check for default title
  local title="${PUSHOVER_TITLE:-Pushover}"

  # URL encode the message
  local encoded_message
  encoded_message=$(urlencode "$message")
  if [[ -z "$encoded_message" ]]; then
    echo "Notification message string empty. Skipping send..." >&2
    return 1
  fi

  # URL encode the title
  local encoded_title
  encoded_title=$(urlencode "$title")

  # Execute the API call
  local response
  response=$(curl -X POST \
    -d "token=$PUSHOVER_API_KEY" \
    -d "user=$PUSHOVER_USER_KEY" \
    -d "message=$encoded_message" \
    -d "title=$encoded_title" \
    -i "https://api.pushover.net/1/messages.json")
  
  # Check if the response contains success indicator
  if echo "$response" | grep -q '"status":1'; then
    echo "✓ Message sent successfully"
    return 0
  else
    echo "✗ Failed to send message" >&2
    echo "API Response: $response" >&2
    return 1
  fi
}

show_usage() {
  echo "Usage: $0 <message>"
  echo ""
  echo "Send a message via Pushover API"
  echo ""
  echo "Examples:"
  echo "  $0 'Hello World'"
  echo "  $0 'Server backup completed successfully'"
  echo ""
  echo "Configuration:"
  echo "  Create ~/.config/pushwrap/pushover.conf with your API credentials"
}

main() {
  # Check if any arguments were provided
  if [[ $# -eq 0 ]]; then
    echo "ERROR: No message provided" >&2
    show_usage
    exit 1
  fi

  # Join all arguments into a single message string
  # This allows for: ./script.sh "Hello World" or ./script.sh Hello World
  local message="$*"

  # Send the message
  if pushover_send "$message"; then
    exit 0
  else
    exit 1
  fi
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
