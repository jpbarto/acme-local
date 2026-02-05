#!/bin/sh

set -e

ENV_NAME="${1:-acme-local}"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

"$SCRIPT_DIR/start.sh $ENV_NAME"

export AWS_ENDPOINT_URL='http://localhost:4566'
export AWS_REGION='us-east-1'
export AWS_ACCESS_KEY_ID='test'
export AWS_SECRET_ACCESS_KEY='test'

$SHELL

"$SCRIPT_DIR/stop.sh $ENV_NAME"
