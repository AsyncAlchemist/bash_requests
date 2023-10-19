#!/bin/bash

source bash_requests.sh
request "https://www.google.com/" "User-Agent: Mozilla/5.0"
echo "RESPONSE CODE = \n$RESPONSE_CODE"
echo "RESPONSE_HEADERS = \n$RESPONSE_HEADERS"
echo "RESPONSE_HEADERS = \n$RESPONSE_BODY"

