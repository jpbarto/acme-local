#!/bin/sh

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ENV_NAME="${1:-acme-local}"
INSTALL_ARGOCD=false
CPU_COUNT=4

# Parse optional flags
shift
while [ $# -gt 0 ]; do
    case "$1" in
        --argocd)
            INSTALL_ARGOCD=true
            shift
            ;;
        --cpu)
            CPU_COUNT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: start.sh [env-name] [--argocd] [--cpu <count>]"
            exit 1
            ;;
    esac
done

# Start a kubernetes cluster using k3s on Colima, configure it with CA certificates
colima start --profile $ENV_NAME --kubernetes --k3s-arg='"--disable=traefik"' --cpu $CPU_COUNT --memory 8 --disk 20 --network-address --vm-type vz

# Copy all certificate files from certs directory to the VM
for cert in "$SCRIPT_DIR/certs"/*.crt "$SCRIPT_DIR/certs"/*.pem; do
    if [ -f "$cert" ]; then
        colima exec --profile $ENV_NAME sudo cp "$cert" /usr/local/share/ca-certificates/
    fi
done
colima exec --profile $ENV_NAME sudo /usr/sbin/update-ca-certificates
colima exec --profile $ENV_NAME "kubectl -n default get configmap ca-pemstore 2>/dev/null || kubectl -n default create configmap ca-pemstore --from-file=/etc/ssl/certs/ca-certificates.crt"
colima exec --profile $ENV_NAME sudo systemctl restart docker

# Install Kyverno using helm, it will insert CA certificates into newly created namespaces and inject them into pods as an attached volume
helm repo add kyverno https://kyverno.github.io/kyverno/ 
helm repo update
helm upgrade --install kyverno kyverno/kyverno --namespace kyverno --create-namespace --wait
kubectl apply -f "$SCRIPT_DIR/kyverno-policies" -n kyverno

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
    # Use NodePort to avoid port conflicts with Istio ingress (which uses ports 80/443)
    helm upgrade --install argocd argo/argo-cd \
        --namespace argocd \
        --create-namespace \
        --set server.insecure=true \
        --set server.service.type=NodePort \
        --set server.service.nodePortHttp=30080 \
        --wait \
        --timeout 10m
    
    # Get the Colima VM IP (ArgoCD is accessible via NodePort)
    ARGOCD_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' | awk '{print $1}')
    ARGOCD_PORT=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')
    
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
    echo "  http://${ARGOCD_IP}:${ARGOCD_PORT}/"
    echo ""
    echo "Login credentials:"
    echo "  Username: admin"
    echo "  Password: ${ARGOCD_PASSWORD}"
    echo ""
    echo "To use ArgoCD CLI:"
    echo "  1. Install ArgoCD CLI: brew install argocd"
    echo "  2. Login to ArgoCD:"
    echo "     argocd login ${ARGOCD_IP}:${ARGOCD_PORT} --username admin --password ${ARGOCD_PASSWORD} --insecure"
    echo ""
fi

# Start LocalStack in detached mode to simulate AWS services
localstack start -d
