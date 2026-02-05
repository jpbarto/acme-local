#!/bin/sh

ENV_NAME="${1:-acme-local}"

colima stop $ENV_NAME
colima delete -fd $ENV_NAME
