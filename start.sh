#!/bin/sh

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ENV_NAME="${1:-acme-local}"

# Start a kubernetes cluster using k3s on Colima, configure it with CA certificates
colima start --profile $ENV_NAME --kubernetes --k3s-arg='"--disable=traefik"' --cpu 4 --memory 8 --disk 20 --network-address --vm-type vz

# Copy all certificate files from certs directory to the VM
for cert in "$SCRIPT_DIR/certs"/*.crt "$SCRIPT_DIR/certs"/*.pem; do
    if [ -f "$cert" ]; then
        colima exec --profile $ENV_NAME sudo cp "$cert" /usr/local/share/ca-certificates/
    fi
done
colima exec --profile $ENV_NAME sudo /usr/sbin/update-ca-certificates
colima exec --profile $ENV_NAME sudo systemctl restart docker

# Install Istio using Helm
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
helm upgrade --install istio-base istio/base -n istio-system --set defaultRevision=default --create-namespace
helm upgrade --install istiod istio/istiod -n istio-system --wait
kubectl create namespace istio-ingress || true
helm upgrade --install istio-ingress istio/gateway -n istio-ingress --wait

# Start LocalStack in detached mode to simulate AWS services
localstack start -d
