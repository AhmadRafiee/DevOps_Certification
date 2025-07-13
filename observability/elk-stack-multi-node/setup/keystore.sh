#!/bin/bash
# Exit on Error
set -e

# Setting Bootstrap Password
echo "Setting bootstrap.password..."
(echo "$ELASTIC_PASSWORD" | elasticsearch-keystore add -x 'bootstrap.password')