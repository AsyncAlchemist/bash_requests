# Testing Library for Bash Requests

This is a testing library designed to validate the functionality of the Bash Requests library, which provides HTTP/HTTPS GET client capabilities in a Bash environment. The library runs a series of test cases to validate various functionalities, including URL encoding, HTTP and HTTPS requests, URL component extraction, and query parameter encoding.

## Requirements

- Bash 4.0 or later
- `bash_requests.sh` script, which this library will be testing
- Network access for HTTP/HTTPS testing
- Required tools installed: `curl`, `wget`, `nc`, `openssl`

## How to Run the Tests

To run the tests, execute the testing library script:

```bash
./test_bash_requests.sh
```

To run tests in verbose mode:

```bash
./test_bash_requests.sh -v
```

## Overview of Tests

1. **URL Encoding**: Tests the `urlencode` function with various kinds of input.
2. **HTTP and HTTPS Requests**: Tests `get_request` for both HTTP and HTTPS using multiple tools.
3. **URL Components**: Tests the `get_url_component` function to extract various parts from a URL.
4. **Query Parameter Encoding**: Tests the `encode_query_params` function for encoding query parameters.
5. **Response Code**: Tests various HTTP status codes.

### Example Test

Here is how a simple test case looks:

```bash
test_urlencode() {
    tests=(
        "abc|abc"
        "123|123"
        " |%20"
    )
    for test in "${tests[@]}"; do
        IFS="|" read -r input expected <<< "$test"
        result=$(urlencode "$input")
        print_test_result "$input" "$expected" "$result"
    done
}
```

## How to Add Additional Tests

### Step 1: Create a Test Function

Create a new function to house your new tests. The function name should start with `test_`.

```bash
test_new_feature() {
    # your code here
}
```

### Step 2: Populate Test Cases

Inside this function, populate your test cases. Generally, these are arrays that contain an input and an expected output separated by a delimiter, usually `|`.

```bash
tests=(
    "input1|expected_output1"
    "input2|expected_output2"
    "input3|expected_output3"
)
```

### Step 3: Loop Through Test Cases

Loop through these test cases and extract the input and expected output. Call the function you want to test with the input and capture the output.

```bash
for test in "${tests[@]}"; do
    IFS="|" read -r input expected <<< "$test"
    result=$(function_to_test "$input")
    print_test_result "$input" "$expected" "$result"
done
```

### Step 4: Include Test in Main Execution

Include your test function in the main execution of the script:

```bash
test_new_feature
```

### Step 5: Run the Tests

Execute the script again to include your new tests:

```bash
./test_bash_requests.sh
```

## Next Steps

- After setting up your tests, you can integrate this testing library into your CI/CD pipeline.
- Make sure to document each test function and what it's testing for easier maintenance.

