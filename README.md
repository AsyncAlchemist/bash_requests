# Bash Requests Library

## Description

This Bash script is a versatile tool for making HTTP/HTTPS requests. It aims to provide a simple yet flexible way to interact with web services directly from your terminal. In addition, it is designed to function as a library, offering a function for making HTTP/HTTPS requests. This function allows you to save each component of the request - response headers, response body, and response code - to a variable.

## Features

- Supports multiple tools for making requests (curl, wget, openssl s_client, nc)
- Autodetects what tools are available and uses the appropriate one for the request
- Customizable environment variables
- Basic error handling and logging
- Extract components from URLs

## Installation

Clone the repository or download the `bash_requests.sh` file and give it executable permissions:

```bash
chmod +x bash_requests.sh
```

## Usage

### Standard Command-Line Usage

Run the script from the command line as shown below:

#### Usage:

```bash
./bash_requests.sh [OPTIONS] <URL> "<HEADER>" "<HEADER>"
```

#### Options:
- -h, --help: Display the help screen.
- -d, --debug: Enable debug output.
- -t, --tool <TOOL>: Choose the tool to be used. Available tools are: curl, wget, openssl, and nc.
- "<HEADER>": Add headers for the request. You can add multiple headers; just enclose each in quotes.
- <URL>: The URL for the request. No need for quotes here, but you can use them if your URL is complex.

#### Examples:

1. **Making a request with debug output and a specified header:**
```bash
   ./bash_requests.sh -d https://api.twitter.com/2/tweets/123456789 "Authorization: Bearer TOKEN"
```
2. **Using a specific tool (curl in this example) with debug output and a specified user-agent:**
```bash
   ./bash_requests.sh -t curl -d https://api.twitter.com/2/tweets/123456789 "User-Agent: MyUserAgent"
```
### Advanced Usage: Using the `request()` Function

To leverage the power of `bash_requests.sh` directly in your script, you can source the file and utilize the `request()` function:

```
source bash_requests.sh
request "$url" "$header1" "$header2" "$header3"
```

#### About the `request()` Function

The `request()` function streamlines the process of making HTTP/HTTPS requests. Here's how it works:

- **Parameters:** 
  - `URL`: The first argument is always the URL for the request.
  - `HEADERS`: All subsequent arguments are treated as headers. Multiple headers can be passed, and they should each be enclosed in quotes.

- **Global Variables Set After Execution:**
  - `RESPONSE_CODE`: Holds the HTTP response code from the server.
  - `RESPONSE_BODY`: Contains the body content of the HTTP response.
  - `RESPONSE_HEADERS`: Captures the headers returned in the HTTP response.

**Important:** After each request, these global variables are overwritten. If you need their values for further processing, ensure you capture and store them before initiating a new request.

#### Examples:

1. **Making a simple GET request to a website:**
```
source bash_requests.sh
request "https://www.example.com"
echo $RESPONSE_BODY
```

2. **Making a request with multiple headers:**
```
source bash_requests.sh
request "https://api.example.com/data" "Authorization: Bearer TOKEN" "User-Agent: MyUserAgent"
echo $RESPONSE_HEADERS
```

3. **Making a request and capturing the response code:**
```
source bash_requests.sh
request "https://api.example.com/data"
echo "Received Response Code: $RESPONSE_CODE"
```

## Environment Variables

The script uses the following environment variables:

- `DEFAULT_USER_AGENT`: Default user agent if none is provided
- `LOG_FILE`: Log file for storing errors

## Error Handling

The script logs any request that doesn't return a status code of 200 or 203. If such a non-compliant status code is received, the details are captured and saved to the specified log file.

## Unit Tests

The included [unit tests](TEST_BASH_REQUESTS.md) can be used to validate any changes or improvements are non-breaking.

## Logging

Logs are stored in `bash_requests_error.log` by default.

## Contributing

Feel free to open an issue or submit a pull request if you find any bugs or have suggestions for improvements. Include the testing library output in your pull request.

## License

MIT License

## FAQ

- **How do I change the default log file?**
  - Modify the `LOG_FILE` environment variable.
