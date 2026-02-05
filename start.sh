#!/bin/sh

set -e

ENV_NAME="${1:-acme-local}"

# Start a kubernetes cluster using k3s on Colima, configure it with the Visa Netskope CA certificate
colima start --profile $ENV_NAME --kubernetes --k3s-arg='"--disable=traefik"' --cpu 4 --memory 8 --disk 20 --network-address --vm-type vz
colima exec --profile $ENV_NAME sudo cp $HOME/caadmin.netskope.com.crt /usr/local/share/ca-certificates
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
