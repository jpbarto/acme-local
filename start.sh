#!/bin/sh

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ENV_NAME="${1:-acme-local}"
INSTALL_ARGOCD=false

# Parse optional flags
shift
while [ $# -gt 0 ]; do
    case "$1" in
        --argocd)
            INSTALL_ARGOCD=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: start.sh [env-name] [--argocd]"
            exit 1
            ;;
    esac
done

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

# Install ArgoCD if requested
if [ "$INSTALL_ARGOCD" = true ]; then
    echo "Installing ArgoCD via Helm..."
    kubectl create namespace argocd || true
    
    # Add ArgoCD Helm repository
    helm repo add argo https://argoproj.github.io/argo-helm
    helm repo update
    
    # Install ArgoCD using Helm with insecure mode for non-HTTPS access
    # Configure base path for proper URL generation behind Istio ingress
    helm upgrade --install argocd argo/argo-cd \
        --namespace argocd \
        --create-namespace \
        --set server.insecure=true \
        --set 'server.extraArgs={--basehref=/argocd,--rootpath=/argocd,--insecure}' \
        --wait \
        --timeout 10m
    
    # Configure Istio Gateway and VirtualService for ArgoCD
    echo "Configuring Istio ingress for ArgoCD..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: argocd-gateway
  namespace: argocd
spec:
  selector:
    app: istio-ingress
    istio: ingress
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: argocd-virtualservice
  namespace: argocd
spec:
  hosts:
  - "*"
  gateways:
  - argocd-gateway
  http:
  - match:
    - uri:
        prefix: /argocd
    route:
    - destination:
        host: argocd-server.argocd.svc.cluster.local
        port:
          number: 80
EOF
    
    # Get the ingress IP
    INGRESS_IP=$(kubectl get svc istio-ingress -n istio-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    # Wait for the secret to be created and get the password
    echo "Waiting for ArgoCD initial admin secret..."
    for i in {1..30}; do
        ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)
        if [ -n "$ARGOCD_PASSWORD" ]; then
            break
        fi
        sleep 2
    done
    
    echo ""
    echo "ArgoCD installed successfully!"
    echo ""
    echo "Access ArgoCD UI at:"
    echo "  http://${INGRESS_IP}/argocd"
    echo ""
    echo "Login credentials:"
    echo "  Username: admin"
    echo "  Password: ${ARGOCD_PASSWORD}"
    echo ""
fi

# Start LocalStack in detached mode to simulate AWS services
localstack start -d
