#!/bin/bash

TESTS_PASSED=0  # 0 means all tests passed, 1 means at least one test failed

# Source the original script to get the urlencode function
source bash_requests.sh

# Check for verbose flag
VERBOSE=0
if [ "$1" == "-v" ] || [ "$1" == "--verbose" ]; then
  VERBOSE=1
fi

print_test_result() {
  local input="$1"
  local expected="$2"
  local result="$3"
  local context="$4"       # Further context (such as a description of the test iteration) as the fourth parameter

  # Check if context is provided and prepend it to the output
  local output=""
  if [ -n "$context" ]; then
    output="$context: "
  fi

  if [ "$result" != "$expected" ]; then
    echo "${output}Test failed for input '$input': Expected '$expected', got '$result'"
    TESTS_PASSED=1  # Set the flag to indicate a test failed
  elif [ "$VERBOSE" -eq 1 ]; then
    echo "${output}Test passed for input '$input': Got '$result'"
  fi
}

test_http_request() {
  local url="http://www.testingmcafeesites.com/testcat_ac.html"
  local headers="User-Agent: Mozilla/5.0"
  
  local expected_output=$(< ./testcase1.html)


  for tool in curl wget nc; do
    tool=$tool
    get_request "$url" "$headers"

  # For the expected_html variable
  expected_output=$(echo "$expected_output" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\n')

  # For a variable containing HTML received from each tool (let's call it received_html for example)
  received_html=$(echo "$RESPONSE_BODY" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\n')


    # Pass the result to your print_test_result function for only RESPONSE_BODY
    print_test_result "$tool" "$expected_output" "$received_html" "Testing RESPONSE_BODY with $tool"
  done
}

test_https_request() {
  local url="https://httpbin.org/user-agent"
  local headers="User-Agent: Mozilla/5.0"
  
  expected_output='{"user-agent": "Mozilla/5.0"}'


  for tool in curl wget s_client; do
    tool=$tool
    get_request "$url" "$headers"

  # For the expected_html variable
  expected_output=$(echo "$expected_output" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\n')

  # For a variable containing HTML received from each tool (let's call it received_html for example)
  received_html=$(echo "$RESPONSE_BODY" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\n')


    # Pass the result to your print_test_result function for only RESPONSE_BODY
    print_test_result "$tool" "$expected_output" "$received_html" "Testing RESPONSE_BODY with $tool"
  done
}



test_get_url_component() {
  # Test format: "url|component|expected_output"
  local tests=(
    "https://sub.example.com/path/to/resource?query=value|protocol|https"
    "https://sub.example.com/path/to/resource?query=value|host|sub.example.com"
    "https://sub.example.com/path/to/resource?query=value|domain|example.com"
    "https://sub.example.com/path/to/resource?query=value|subdomain|sub"
    "https://sub.example.com/path/to/resource?query=value|path|/path/to/resource"
    "https://sub.example.com/path/to/resource?query=value|query|?query=value"
    "https://sub.example.com/path/to/resource?query=value|pathquery|/path/to/resource?query=value"
    "https://sub.example.com/path/to/resource?query=value|port|443"
    "http://example.com/path|port|80"
    "https://example.com|unknown|Unknown part requested: unknown"
  )

  for test in "${tests[@]}"; do
    IFS="|" read -r url component expected <<< "$test"

    # Call get_url_component with the url and component for extraction
    result=$(get_url_component "$url" "$component")

    # If the result is an error message, capture the exit status
    exit_code=$?
    if [[ "$expected" == *"Unknown part"* && $exit_code -ne 1 ]]; then
      echo "Test failed for URL '$url' and component '$component': Expected an exit code of 1, got $exit_code"
      TESTS_PASSED=1  # Set the flag to indicate a test failed
    else
      # Build the context for the output
      context="URL: $url, Component: $component"
      
      # Using the modified print_test_result function with the context
      print_test_result "$context" "$expected" "$result"
    fi
  done
}

# Unit test function with all test cases
test_urlencode() {
    # Test format: "input|expected_output"
    tests=(
        "abc|abc"
        "123|123"
        " |%20"
        "!|%21"
        "\"|%22"
        "#|%23"
        "\$|%24"
        "&|%26"
        "%|%25"
        "%%|%25%25"
        "@@|%40%40"
        "!!|%21%21"
        "%!|%25%21"
        "!%|%21%25"
        "'|%27"
        "(|%28"
        ")|%29"
        "*|%2a"
        "+|%2b"
        ",|%2c"
        "-|-"
        ".|."
        "/|%2f"
        ":|%3a"
        ";|%3b"
        "<|%3c"
        "=|%3d"
        ">|%3e"
        "?|%3f"
        "@|%40"
        "[|%5b"
        "\\|%5c"
        "]|%5d"
        "^|%5e"
        "_|_"
        "\`|%60"
        "{|%7b"
        "||%7c"
        "}|%7d"
        "~|~"
        # Real-world examples
        "https://www.example.com|https%3a%2f%2fwww.example.com"
        "http://user:pass@example.com|http%3a%2f%2fuser%3apass%40example.com"
        "https://example.com/path/to/file|https%3a%2f%2fexample.com%2fpath%2fto%2ffile"
        "https://example.com/search?q=query|https%3a%2f%2fexample.com%2fsearch%3fq%3dquery"
        "https://example.com/#fragment|https%3a%2f%2fexample.com%2f%23fragment"
        "mailto:user@example.com|mailto%3auser%40example.com"
        "/path/to/file|%2fpath%2fto%2ffile"
        "q=this+is+a+search+query|q%3dthis%2bis%2ba%2bsearch%2bquery"
        "special*&^%0@!chars|special%2a%26%5e%250%40%21chars"
    )

    for test in "${tests[@]}"; do
        IFS="|" read -r input expected <<< "$test"
        
        if [ -z "$input" ]; then
            input="|"
            expected="%7c"  # Explicitly set the expected value for the pipe character
        fi

        result=$(urlencode "$input")
        
    # Call the output function
    print_test_result "$input" "$expected" "$result"
    done
}

# Test cases for encode_query_params
test_encode_query_params() {
  # Test format: "input|expected_output"
  tests=(
    "?name=John Doe&age=30|?name=John%20Doe&age=30"
    "?title=Jack and Jill&price=30.56|?title=Jack%20and%20Jill&price=30.56"
    "?name=John+Doe&age=30|?name=John%2bDoe&age=30"
    "?special_chars=*!@#^*()|?special_chars=%2a%21%40%23%5e%2a%28%29"
    "?mixed=JohnDoe!2023|?mixed=JohnDoe%212023"
  )

  for test in "${tests[@]}"; do
    IFS="|" read -r input_query expected <<< "$test"
    result=$(encode_query_params "$input_query")
    print_test_result "$input_query" "$expected" "$result"
  done
}

test_response_code() {
  local functions=("request" "get_request" "request_curl" "request_openssl" "request_wget" "request_nc")
  local headers="User-Agent: $DEFAULT_USER_AGENT"  # Using DEFAULT_USER_AGENT for headers

  # Test format: "url|expected_response_code"
  local tests=(
    "https://httpbin.org/status/200|200"
    "https://httpbin.org/status/201|201"
    "https://httpbin.org/status/204|204"
    "https://httpbin.org/status/400|400"
    "https://httpbin.org/status/401|401"
    "https://httpbin.org/status/403|403"
    "https://httpbin.org/status/404|404"
    "https://httpbin.org/status/500|500"
    "https://httpbin.org/status/502|502"
    "https://httpbin.org/status/503|503"
  )

  for func in "${functions[@]}"; do
    for test in "${tests[@]}"; do
      IFS="|" read -r url expected <<< "$test"
      
      # For the "request" function, call it directly with the URL
      if [ "$func" == "request" ]; then
        $func "$url"
      else
        # For all other functions, including "get_request", call them with the url and headers
        $func "$url" "$headers"
      fi
      
      # Using the modified print_test_result function with the function context
      print_test_result "$url" "$expected" "$RESPONSE_CODE" "Function: $func"
    done
  done
}

test_select_tool() {
  # Mock the command function to simulate the presence or absence of a tool
  command() {
    case $1 in
      -v) shift;;
    esac
    if [[ "${MOCK_COMMANDS[@]}" =~ "$1" ]]; then
      return 0  # Tool is available
    else
      return 1  # Tool is not available
    fi
  }

  # Test format: "mocked_tools|REQUEST|expected_tool"
  local tests=(
    "curl|https://example.com|curl"
    "wget|https://example.com|wget"
    "openssl|https://example.com|s_client"
    "nc|http://example.com|nc"
    "nc|https://example.com|Neither curl, wget, s_client, nor nc is installed. Please install one of them."
    "curl wget openssl nc|https://example.com|curl"  # The priority check
  )

  for test in "${tests[@]}"; do
    IFS="|" read -r mocked_tools request expected <<< "$test"
    
    # Mock the available tools based on the test case
    IFS=" " read -ra MOCK_COMMANDS <<< "$mocked_tools"

    # Set the REQUEST for the tool selection
    REQUEST="$request"
    
    # Call select_tool and capture its output and exit code
    result=$(select_tool)
    exit_code=$?

    # Build the context for the output
    context="Available tools: $mocked_tools, Request: $request"
    
    # Using the modified print_test_result function with the context
    print_test_result "$context" "$expected" "$result"
    
    # Additional check for the exit code, in case of error scenario
    if [[ "$expected" == *"Please install"* && $exit_code -ne 1 ]]; then
      echo "Test failed for context '$context': Expected an exit code of 1, got $exit_code"
      TESTS_PASSED=1  # Set the flag to indicate a test failed
    fi
  done
}

test_pack_and_unpack_headers() {
    local headers=("User-Agent: CustomAgent" "Authorization: Bearer token" "Content-Type: application/json" "Accept: application/xml")
    local packed_headers=$(pack_headers "${headers[@]}")
    local unpacked_headers
    local formats=("curl" "wget" "openssl" "nc")
    
    for format in "${formats[@]}"; do
        unpacked_headers=$(unpack_headers "$packed_headers" "$format")

        # Verify for each format
        case "$format" in
            "curl")
                expected="-H \"User-Agent: CustomAgent\" -H \"Authorization: Bearer token\" -H \"Content-Type: application/json\" -H \"Accept: application/xml\""
                ;;
            "wget")
                expected="--header=\"User-Agent: CustomAgent\" --header=\"Authorization: Bearer token\" --header=\"Content-Type: application/json\" --header=\"Accept: application/xml\""
                ;;
            "openssl"|"s_client")
                expected="User-Agent: CustomAgent\r\nAuthorization: Bearer token\r\nContent-Type: application/json\r\nAccept: application/xml\r\n\r\n"
                ;;
            "nc")
                expected="User-Agent: CustomAgent\r\nAuthorization: Bearer token\r\nContent-Type: application/json\r\nAccept: application/xml\r\n"
                ;;
            *)
                echo "Error: Unknown format $format"
                exit 1
                ;;
        esac

        print_test_result "Format: $format" "$expected" "$unpacked_headers"
    done
}


# Call the test functions
test_pack_and_unpack_headers
test_get_url_component
test_select_tool
test_encode_query_params
test_urlencode
test_response_code
test_http_request
test_https_request
exit $TESTS_PASSED  # Exit with status code 0 if all tests passed, or 1 if any test failed
