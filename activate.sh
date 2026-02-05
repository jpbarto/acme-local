#!/bin/sh

set -e

# Receive the environment name as the first argument to the script
ENV_NAME=$1

if [ -z "$ENV_NAME" ]; then
    echo "Error: Environment name is required"
    echo "Usage: activate.sh <environment-name>"
    exit 1
fi

echo "Checking Colima instance for environment: $ENV_NAME"

# Check if the correct colima instance is running
COLIMA_STATUS=$(colima status --profile "$ENV_NAME" 2>&1 || echo "not found")

if echo "$COLIMA_STATUS" | grep -q "is running"; then
    echo "✓ Colima instance '$ENV_NAME' is running"
else
    echo "✗ Colima instance '$ENV_NAME' is not running"
    exit 1
fi

# Set the Docker context to the colima instance with the specified environment name
docker context use "colima-$ENV_NAME"
echo "✓ Docker context set to 'colima-$ENV_NAME'"

# Check if LocalStack is running on the Colima host
echo "Checking LocalStack status..."
LOCALSTACK_RUNNING=$(docker ps --filter "name=localstack" --filter "status=running" --format "{{.Names}}" 2>/dev/null || echo "")

if [ -n "$LOCALSTACK_RUNNING" ]; then
    echo "✓ LocalStack is running: $LOCALSTACK_RUNNING"
else
    echo "✗ LocalStack is not running on Colima instance '$ENV_NAME'"
    echo "You may need to start LocalStack with: localstack start -d"
    exit 1
fi

echo ""
echo "Environment '$ENV_NAME' activated successfully with Colima and LocalStack."
