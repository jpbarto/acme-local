#!/bin/sh

ENV_NAME="${1:-acme-local}"

localstack stop
colima stop --profile $ENV_NAME
