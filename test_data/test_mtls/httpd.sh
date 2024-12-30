#!/usr/bin/env bash

http_response () {
    HTTP_CODE=$1
    MESSAGE=${2:-Message Undefined}
    length=$((${#MESSAGE} + 2))
    if [[ "$HTTP_CODE" -eq 503 ]]; then
      echo -en "HTTP/1.1 503 Service Unavailable\r\n"
    elif [[ "$HTTP_CODE" -eq 200 ]]; then
      echo -en "HTTP/1.1 200 OK\r\n"
    else
      echo -en "HTTP/1.1 ${HTTP_CODE} UNKNOWN\r\n"
    fi
    echo -en "Content-Type: text/plain\r\n"
    echo -en "Connection: close\r\n"
    echo -en "Content-Length: ${length}\r\n"
    echo -en "\r\n"
    echo -en "$MESSAGE"
    echo -en "\r\n"
    sleep 0.1
    exit 0
}

http_response 200 "Success Message"
