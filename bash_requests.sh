#!/bin/bash


DEFAULT_USER_AGENT="bash_requests/0.1"    # User agent to use if none is provided
LOG_FILE="./bash_requests_error.log"      # Log is stored here

# Basic function to make a request
request() {
  flatten_variables
  REQUEST="$1"
  REQUEST=$(prepare_request "$REQUEST")

  shift # Remove the first argument (URL) from the list of arguments
  local header
  local custom_user_agent_found=false
  
  # Initialize HEADERS as an empty string
  HEADERS=""
  
  # Loop through all remaining arguments to pack headers and check for custom User-Agent
  for header in "$@"; do
    # If header starts with User-Agent (case insensitive check using tr)
    if [[ "$(echo "$header" | tr '[:upper:]' '[:lower:]')" == user-agent:* ]]; then
      custom_user_agent_found=true
    fi
    # Append packed header to the HEADERS
    HEADERS="$(pack_headers "$header")"
  done

  # If no custom User-Agent found, prepend the default one using pack_headers
  if [ "$custom_user_agent_found" = false ]; then
    HEADERS="$(pack_headers "User-Agent: $DEFAULT_USER_AGENT")"
  fi

  # Call 'get_request' with the URL and packed headers
  get_request "$REQUEST" "$HEADERS"
  echo "$RESPONSE_BODY"
}

flatten_variables() {
  RESPONSE_CODE=""
  RESPONSE_BODY=""
  RESPONSE_HEADERS=""
}

# Function to automatically detect the available tool for sending the heartbeat, or use user input
select_tool() {
  debug "-----BEGIN select_tool ()-----"
  # Extract the protocol from REQUEST using get_url_component
  local protocol=$(get_url_component "$REQUEST" "protocol")
  debug "protocol" "$protocol"
  # If the user has provided a tool via command-line argument, use that
  if [ -n "$TOOL" ]; then
    debug "Returning tool from command line args"
    echo $TOOL
    return
  fi

  debug "Selecting tool..."

  # Otherwise, automatically detect the available tool
  if command -v curl &> /dev/null; then
    TOOL="curl"
  elif command -v wget &> /dev/null; then
    TOOL="wget"
  elif command -v openssl &> /dev/null && openssl s_client -help &> /dev/null; then
    TOOL="s_client"
  elif [ "$protocol" != "https" ] && command -v nc &> /dev/null; then
    # Only select nc if the protocol is not https
    TOOL="nc"
  else
    echo "Neither curl, wget, s_client, nor nc is installed. Please install one of them."
    exit 1
  fi
  debug "TOOL" "$TOOL"
  echo "$TOOL"
  debug "Returning tool..."
  debug "-----END select_tool ()-----"
}

# Function to log errors and non-200/203 responses
log_error() {
  debug "Executing log_error()..."
  local tool="$1"
  local code="$2"
  local body="$3"
  # Escape LF and CRLF in the response_code and response_body
  
  code=$(echo "$code" | awk 'BEGIN {ORS="\\n";} {print}' | tr -d '\r')
  body=$(echo "$body" | awk 'BEGIN {ORS="\\n";} {print}' | tr -d '\r')
  
  local timestamp=$(date +%Y-%m-%dT%H:%M:%S%z)
  echo "$timestamp [Tool: $tool] [Response Code: $code] [Response Body: $body]" >> $LOG_FILE
  debug "ERROR LOGGED" "$timestamp [Tool: $tool] [Response Code: $code] [Response Body: $body]"
}

# Function to extract a component of an URL and return the requested part
# Usage "get_url_component "url" "part to return"
# Part to return options: protocol, port, host, domain, subdomain, path, query, pathquery (path + query)
get_url_component() {
  debug "-----BEGIN get_url_component()-----"

  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error: Missing or null arguments. Both URL and component part are required."
    exit 1
  fi

  local full_url="$1"
  local part_to_return="$2"

  # Pre-compute all the components using pipes for multiple string manipulations
  local protocol="${full_url%%://*}"
  local port=$( [ "$protocol" = "http" ] && echo "80" || echo "443" )
  local host_port_path=$(echo "${full_url#*://}")       # Remove the protocol
  local host_port="${host_port_path%%/*}"               # Extract host:port before first slash
  local host="${host_port%:*}"                          # Remove the port
  local domain=$(echo "$host" | awk -F. '{if(NF>1) print $(NF-1)"."$NF; else print $NF}')
  local subdomain="${host%.$domain}"
  local path=$(echo $full_url | cut -d '?' -f 1 | awk -F/ '{for(i=4; i<=NF; i++) printf "/"$i}')
  local query_string=$(echo $full_url | awk -F"?" '{print $2}')
  if [ -z "$query_string" ]; then
    local query=""
  else
    local query=$(echo "?"$query_string)
  fi
  local pathquery="$path$query"

  debug "protocol" "$protocol"
  debug "port" "$port"
  debug "host" "$host"
  debug "domain" "$domain"
  debug "subdomain" "$subdomain"
  debug "path" "$path"
  debug "query" "$query"
  debug "pathquery" "$pathquery"

  case "$part_to_return" in
    "protocol"|"scheme")
      echo "$protocol"
      ;;
    "host")
      echo "$host"
      ;;
    "domain")
      echo "$domain"
      ;;
    "subdomain")
      echo "$subdomain"
      ;;
    "path")
      echo "$path"
      ;;
    "query")
      echo "$query"
      ;;
    "pathquery")
      echo "$pathquery"
      ;;
    "port")
      echo "$port"
      ;;
    *)
      echo "Unknown part requested: $part_to_return"
      exit 1
      ;;
  esac
  debug "-----END get_url_component()-----"
}

# Function to make a GET request using curl
# Example usage: request_curl "$url" "$headers"
request_curl () {
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error: Missing or null arguments. Both URL and headers are required."
    exit 1
  fi

  debug "Executing request_curl()..."
  local url="$1"
  local curl_headers=$(unpack_headers "$2" "curl")

  local response=$(eval curl -i -s $curl_headers '"$url"') # Fetch both headers and body  
  RESPONSE_HEADERS="${response%%$'\r\n\r\n'*}"
  RESPONSE_BODY="${response#*$'\r\n\r\n'}"
  RESPONSE_CODE=$(echo "$response" | awk 'NR==1{print $2}')

  debug "-----request_curl ()-----"
  debug "RESPONSE_CODE" "$RESPONSE_CODE"
  debug "RESPONSE_HEADERS" "$RESPONSE_HEADERS"
  debug "RESPONSE_BODY" "$RESPONSE_BODY"
  debug "-----request_curl ()-----"
}

# Function to make a GET request using wget
# Example usage: request_wget "$url" "$headers"
request_wget () {
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error: Missing or null arguments. Both URL and headers are required."
    exit 1
  fi

  debug "Executing request_wget()..."
  local url="$1"
  local wget_headers=$(unpack_headers "$2" "wget")

  local response=$(eval wget --server-response "$wget_headers" -O - '"$url"' 2>&1)
  RESPONSE_BODY=$(echo "$response" | awk '/Saving to: .STDOUT./, /0K.*100%/' | sed '1d;$d')
  RESPONSE_HEADERS=$(echo "$response" | awk '/HTTP\/[12](\.[01])?/,/Saving to: ‘STDOUT’/' | sed '1d;$d' | sed '$d' | sed 's/^[ \t]*//')
  RESPONSE_CODE=$(echo "$response" | sed -n 's/.*HTTP\/1\.[01] \([1-5][0-9][0-9]\).*/\1/p')
  debug "-----WGET-----"
  debug "RESPONSE_CODE" "$RESPONSE_CODE"
  debug "RESPONSE_HEADERS" "$RESPONSE_HEADERS"
  debug "RESPONSE_BODY" "$RESPONSE_BODY"
  debug "-----WGET-----"
}

# Function to make a GET request using openssl
# Example usage: request_openssl "$url" "$headers"
request_openssl() {
  debug "-----BEGIN request_openssl()-----"
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error: Missing or null arguments. Both URL and headers are required."
    exit 1
  fi
  local host=$(get_url_component "$1" "host")
  local port=$(get_url_component "$1" "port")
  local pathquery=$(get_url_component "$1" "pathquery")
  local s_client_headers=$(unpack_headers "$2" "s_client")

  # Generate the OPENSSL s_client request paramters
  local s_client_request="GET $pathquery HTTP/1.1\r\nHost:$host\r\n$s_client_headers"
  # Use a subshell to bundle the GET request and a delay, then pipe this into openssl s_client
  local raw_response=$((echo -e "$s_client_request"; sleep 5) | openssl s_client -connect $host:$port 2>/dev/null)
  raw_response=$(echo "$raw_response" | LC_ALL=C sed 's/[^[:print:][:space:]]//g')

  RESPONSE_BODY=$(echo "$raw_response" | LC_ALL=C sed 's/\r//g' | awk 'BEGIN {p=0} /^$/ {if (p == 0) p=1; next} p {print}' | sed '/---/q' | sed 's/---//' | sed '1d')
  RESPONSE_BODY=$(echo "$RESPONSE_BODY" | sed '$d')

  RESPONSE_HEADERS=$(echo -e "$raw_response" | tr -d '\r' | awk '/HTTP\/1.1/,/^$/ {print}')
  RESPONSE_CODE=$(echo "$RESPONSE_HEADERS" | awk '/HTTP\/1.1 [1-5][0-9]{2}/ {print $2}')
  debug "-----OPENSSL S_CLIENT-----"
  debug "RESPONSE_CODE" "$RESPONSE_CODE"
  debug "RESPONSE_HEADERS" "$RESPONSE_HEADERS"
  debug "RESPONSE_BODY" "$RESPONSE_BODY"
  debug "-----OPENSSL S_CLIENT-----"
  debug "-----END request_openssl()-----"

}

# Function to make a GET request using nc
# Example usage: request_nc "$url" "$headers"
request_nc() {
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error: Missing or null arguments. Both URL and headers are required."
    exit 1
  fi

  debug "Executing request_nc()..."
  # Modify URL to use http if https was used.
  local url=$(echo "$1" | sed 's/https:/http:/')
  local nc_headers=$(unpack_headers "$2" "nc")
  local host=$(get_url_component "$url" "host")
  ## Make the request and capture the entire response
  nc_response_raw=$((echo -e "GET $url HTTP/1.1\r\nHost: $host\r\n$nc_headers \r\nConnection: close\\r\\n\\r\\n"; sleep 5) | nc $host 80)
  RESPONSE_CODE=$(echo "$nc_response_raw" | LC_ALL=C awk '/HTTP\/1\.[01]/ {print $2}')
  RESPONSE_BODY=$(echo "$nc_response_raw" | LC_ALL=C sed 's/\r//g' | LC_ALL=C sed -n '/^$/,$p' | LC_ALL=C sed '1,2d;N;$!P;$!D;$d')
  RESPONSE_HEADERS=$(echo -e "$nc_response_raw" | tr -d '\r' | awk '/HTTP\/1.1/,/^$/ {print}')
  debug "-----NC-----"
  debug "RESPONSE_CODE" "$RESPONSE_CODE"
  debug "RESPONSE_HEADERS" "$RESPONSE_HEADERS"
  debug "RESPONSE_BODY" "$RESPONSE_BODY"
  debug "-----NC-----"
}

# Function to make a GET request using the appropriate tool
get_request() {
  debug "-----BEGIN get_request ()-----"
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error: Missing or null arguments. Both URL and headers are required."
    exit 1
  fi

  local get_request_tool=$(select_tool)
  local get_request_url="$1"
  local get_request_headers="$2"

  debug "get_request_tool" "$get_request_tool"
  debug "get_request_url" "$get_request_url"
  debug "get_request_headers" "$get_request_headers"

  if [ "$get_request_tool" = "curl" ]; then
    debug "Calling request_curl"
    request_curl "$get_request_url" "$get_request_headers"
   elif [ "$get_request_tool" = "s_client" ] || [ "$get_request_tool" = "openssl" ]; then
    debug "Calling request_openssl"
    request_openssl "$get_request_url" "$get_request_headers"
  elif [ "$get_request_tool" = "wget" ]; then
    debug "Calling request_wget"
    request_wget "$get_request_url" "$get_request_headers"
  elif [ "$get_request_tool" = "nc" ]; then
    debug "Calling request_nc"
    request_nc "$get_request_url" "$get_request_headers"
  else
    echo "Invalid tool specified. Please install either curl, wget, openssl or nc."
    exit 1
  fi

  if [ "$RESPONSE_CODE" != "200" ] && [ "$RESPONSE_CODE" != "203" ]; then
    log_error "$tool" "$RESPONSE_CODE" "$RESPONSE_BODY"
  fi
  debug "-----END get_request ()-----"
}

prepare_request() {
  local input_url="$1"

  
  # Reject null variables
  if [ -z "$input_url" ]; then
    echo "Error: URL cannot be empty."
    exit 1
  fi
  
  # Validate URL to be http or https
  if [[ "$input_url" != http://* ]] && [[ "$input_url" != https://* ]]; then
    echo "Error: Invalid URL format. Must start with http:// or https://"
    exit 1
  fi
  
  # Perform URL encoding if NO_ENCODE is false
  if [ "$NO_ENCODE" = false ]; then
    local query=$(get_url_component "$input_url" "query")

    local encoded_query=$(encode_query_params "$query")

    input_url="${input_url%%\?*}$encoded_query"
  fi

  echo "$input_url"
  return 0
}




# Function to URL-encode strings
urlencode() {
  if [ -z "$1" ]; then
    echo "Error: Missing or null argument. A string is required for URL encoding."
    exit 1
  fi

  debug "Executing urlencode()..."
  local string="$1"
  local strlen=${#string}
  local encoded=""
  local pos c o

  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:$pos:1}
     case "$c" in
        [-_.~a-zA-Z0-9] ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
     esac
     encoded+="${o}"
  done
  echo "$encoded"
}

# Function to selectively encode query parameters
encode_query_params() {
  local query="$1"
  local encoded_query=""  # Initialize as empty string

  # Remove the leading '?'
  query="${query#?}"

  # Split the query string into variables
  IFS='&' read -ra variables <<< "$query"
    
  for variable in "${variables[@]}"; do
    # Split each variable into name and value
    IFS='=' read -r name value <<< "$variable"

    # Encode name and value if they are not empty
    [ -n "$name" ] && name="$(urlencode "$name")"
    [ -n "$value" ] && value="$(urlencode "$value")"

    # Reconstruct the variable and append it to encoded_query
    [ -n "$name" ] || [ -n "$value" ] && encoded_query+="&${name}=${value}"
  done

  # Add the leading '?' only if encoded_query is not empty
  [ -n "$encoded_query" ] && encoded_query="?"${encoded_query#&}

  echo "$encoded_query"
}


# Packs headers into the global $HEADERS variable
pack_headers() {
  if [ $# -eq 0 ]; then
    echo "Error: Missing arguments. At least one header is required for packing."
    exit 1
  fi

  debug "Executing pack_headers()..."
  for header in "$@"; do
    # Append the header to HEADERS
    if [ -z "$HEADERS" ]; then
      HEADERS="$header"
    else
      HEADERS="${HEADERS}$(printf '\037')${header}"
    fi
  done

  echo "$HEADERS"
}

# Unpacks the headers and prints each.
unpack_headers() {
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error: Missing or null arguments. Both headers and format are required for unpacking."
    exit 1
  fi

  local headers_to_unpack="$1"
  local format="$2"
  local formatted_headers=""

  # Split the headers
  IFS=$'\037' read -ra headerArray <<< "$headers_to_unpack"
  
  # Format each header according to the specified format
  for i in "${headerArray[@]}"; do
    case "$format" in
      "curl")
        formatted_headers+=" -H \"$i\""
        ;;
      "wget")
        formatted_headers+=" --header=\"$i\""
        ;;
      "openssl" | "s_client" | "nc")
        formatted_headers+="$i\r\n"
        ;;
      *)
        formatted_headers+="$i\n"
        ;;
    esac
  done
  
  # Add ending characters for 'openssl' and 's_client'
  if [ "$format" == "openssl" ] || [ "$format" == "s_client" ]; then
    formatted_headers+="\r\n"
  fi
  
  # Remove leading whitespace for 'curl'
  if [ "$format" == "curl" ] || [ "$format" == "wget" ]; then
    formatted_headers="${formatted_headers:1}"
  fi

  # Output the formatted headers
  echo "$formatted_headers"
}

debug() {
    # Check if the first argument starts with '!'
  if [[ "$1" == !* ]]; then
    echo "🪲 Debug: ${1:1}" >&2
    return
  fi

  if [ "$#" -eq 2 ]; then
    local var_name="$1"
    local var_value="$2"
    if [ "$DEBUG" = true ]; then
      echo "🪲 Debug: $var_name = $var_value" >&2
    fi
  else
    local message="$1"
    if [ "$DEBUG" = true ]; then
      echo "🪲 Debug: $message" >&2
    fi
  fi
}

# Check for command-line arguments
process_args() {
  debug "Executing process_args()..."
  local is_tool_specified=false
  local invalid_arg=""
  local custom_user_agent_found=false     
  DEBUG=false  # Initialize DEBUG to false
  NO_ENCODE=false # Initialize a new variable to store the no-encode flag
  TOOL="" #Initialize TOOL to null


  for arg in "$@"; do
    if [ "$is_tool_specified" = true ]; then
      TOOL="$arg"
      is_tool_specified=false
      shift
      continue
    elif [ "$arg" = "-h" ] || [ "$arg" = "--help" ]; then
      print_help
      exit 0
    elif [ "$arg" = "-d" ] || [ "$arg" = "--debug" ]; then
      DEBUG=true
    elif [ "$arg" = "-t" ] || [ "$arg" = "--tool" ]; then
      is_tool_specified=true
    elif [ "$arg" = "-n" ] || [ "$arg" = "--no-encode" ]; then
      NO_ENCODE=true
    # Capture URLs
    elif [[ "$arg" == http://* ]] || [[ "$arg" == https://* ]]; then
      arg=$(echo "$arg" | tr -d '"') # Remove quotes around the argument if present
      REQUEST="$arg"
      
    # Capture headers based on the presence of a colon
    elif [[ "$arg" == *:* ]]; then
      header_argument="$arg"
      # If header starts with User-Agent (case insensitive check using tr)
      if [[ "$(echo "$header_argument" | tr '[:upper:]' '[:lower:]')" == user-agent:* ]]; then
        custom_user_agent_found=true
      fi
      # Call the pack_headers function
      HEADERS=$(pack_headers "$header_argument")
    else
      # Store the unrecognized argument
      invalid_arg="$arg"
      break
    fi

    shift # Move to the next argument for the next iteration
  done
  # After processing all arguments, check for any unrecognized argument
  echo "$REQUEST"
  REQUEST=$(prepare_request "$REQUEST")
  echo "$REQUEST"

  if [ -n "$invalid_arg" ]; then
    echo "Error: Invalid argument '$invalid_arg'"
    print_help
    exit 1
  fi
  # Check for an empty URL
  if [ -z "$REQUEST" ]; then
    echo "Error: URL is required."
    print_help
    exit 1
  fi
  # If no custom user-agent is found, pack the default user-agent
  if [ "$custom_user_agent_found" = false ]; then
    defaultUserAgent="User-Agent: $DEFAULT_USER_AGENT"
    HEADERS=$(pack_headers "$defaultUserAgent")
  fi

}

print_help() {
    echo "Usage: $0 [OPTIONS] <URL>"
    echo
    echo " bash_requests 0.1"
    echo " A script for making simple HTTP/HTTPS requests."
    echo " Tool will be autodetected if not specified."
    echo
    echo " Options:"
    echo "  -h,--help               Display this help screen"
    echo "  -d,--debug              Enable debug output"
    echo "  -t,--tool <TOOL>        Specify the tool to be used (curl, wget, openssl, nc)"
    echo "  -n,--no-encode          Disable URL encoding for query parameters"
    echo "  \"<HEADER>\"              Specify headers (multiple headers can be used,"
    echo "                          enclose each in quotes)"
    echo "  <URL>                   Specify the URL (without quotes)"
    echo
    echo " Examples:"
    echo "  $0 -d https://api.twitter.com/2/tweets/123456789 \"Authorization: Bearer TOKEN\""
    echo "  $0 -t curl -d https://api.twitter.com/2/tweets/123456789 \"User-Agent: MyUserAgent\""
    echo
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  debug "bash_requests script is being run directly, process args and execute main logic."
  process_args "$@"
  debug "REQUEST URL" "$REQUEST"
  debug "REQUEST HEADERS" "$HEADERS"
  get_request "$REQUEST" "$HEADERS"
  echo "$RESPONSE_BODY"
else
  debug "bash_request script is being sourced, main logic won't execute."
fi