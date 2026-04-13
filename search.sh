#!/bin/bash

# Usage check
if [[ -z "$1" ]]; then
    echo "Need to query something"
    exit 1
fi


# Accept quoted single arg or multiple unquoted args
if [ "$#" -eq 1 ]; then
    input="$1"
else
    input="$*"
fi

# Strip surrounding quotes and trailing question mark
input="${input#[\"\']}"
input="${input%[\"\']}"
input="${input%%\?*( )}"

# URL encode query
query=$(printf '%s' "$input" | jq -sRr @uri)

# Load session token
kagi_session=$(<~/.kagi_session)

# Fetch result from Kagi
json_result=$(curl "https://kagi.com/mother/context?q=$query" \
  --silent \
  --compressed \
  -X POST \
  -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:144.0) Gecko/20100101 Firefox/144.0' \
  -H 'Accept: application/vnd.kagi.stream' \
  -H 'Accept-Language: en-US,en;q=0.5' \
  -H 'Accept-Encoding: gzip, deflate, br, zstd' \
  -H "Referer: https://kagi.com/search?q=$query" \
  -H 'Origin: https://kagi.com' \
  -H 'DNT: 1' \
  -H 'Sec-GPC: 1' \
  -H 'Connection: keep-alive' \
  -H "Cookie: kagi_session=$kagi_session;" \
  -H 'Sec-Fetch-Dest: empty' \
  -H 'Sec-Fetch-Mode: cors' \
  -H 'Sec-Fetch-Site: same-origin' \
  -H 'Priority: u=4' \
  -H 'Content-Length: 0' \
  -H 'TE: trailers' \
  --output - | tr -d '\0')

# Parse JSON from streamed response
json_result="${json_result##*new_message.json:}"

# Check for auth error
if [[ $(echo -n $json_result | jq '.error' 2>/dev/null) == "unauthorized" ]]; then
	echo "Something broke!!! UNAUTHORIZED"
	exit 1
fi

# Output answer
echo -n "$json_result" | jq '.md' --raw-output

# Output citations if present
if [[ $(echo -n "$json_result" | jq 'if .references_md == [] then "nothing" end') != "nothing" ]]; then
	echo -n "$json_result" | jq '.references_md' --raw-output
fi
