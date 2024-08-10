#!/bin/bash

URL="https://ha.web.mecan.ir:443"
NUM_REQUESTS=100

count_server_1=0
count_server_2=0
count_server_3=0
count_server_4=0

for ((i=1; i<=NUM_REQUESTS; i++)); do
  response=$(curl -s $URL)

  if echo "$response" | grep -q "Server 1"; then
    ((count_server_1++))
  elif echo "$response" | grep -q "Server 2"; then
    ((count_server_2++))
  elif echo "$response" | grep -q "Server 3"; then
    ((count_server_3++))
  elif echo "$response" | grep -q "Server 4"; then
    ((count_server_4++))
  fi
done

echo "Count of Server 1 responses: $count_server_1"
echo "Count of Server 2 responses: $count_server_2"
echo "Count of Server 3 responses: $count_server_3"
echo "Count of Server 3 responses: $count_server_4"
