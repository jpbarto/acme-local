#!/bin/sh

ENV_NAME="${1:-acme-local}"

# Stop the OCI registry container if running
colima exec --profile $ENV_NAME -- docker stop registry 2>/dev/null || true

localstack stop
colima stop --profile $ENV_NAME
