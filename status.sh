#!/bin/sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_NAME="${1:-acme-local}"

# Load environment variables (includes AWS_ENDPOINT_URL set by start.sh)
if [ -f "$SCRIPT_DIR/local.env" ]; then
    . "$SCRIPT_DIR/local.env"
fi

echo "Checking acme-local environment status..."
echo ""

# Check Colima/Kubernetes cluster status
echo "=== Kubernetes Cluster (Colima) ==="
COLIMA_OUTPUT=$(colima status --profile "$ENV_NAME" 2>&1 || true)
COLIMA_EXIT_CODE=$?

if [ $COLIMA_EXIT_CODE -eq 0 ] && echo "$COLIMA_OUTPUT" | grep -q "is running"; then
    echo "✓ Colima VM: Running"
    
    # Check if kubectl can connect
    if kubectl cluster-info > /dev/null 2>&1; then
        echo "✓ Kubernetes: Running"
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null | awk '{print $1}')
        echo "  Node IP: $NODE_IP"
    else
        echo "✗ Kubernetes: Not accessible"
    fi
elif echo "$COLIMA_OUTPUT" | grep -q "is not running"; then
    echo "✗ Colima VM: Stopped"
    echo "✗ Kubernetes: Not running"
    echo ""
    echo "=== Istio Service Mesh ==="
    echo "✗ Istio: Not running (Colima VM is stopped)"
    echo ""
    echo "=== ArgoCD ==="
    echo "✗ ArgoCD: Not running (Colima VM is stopped)"
    echo ""
    echo "=== LocalStack ==="
    echo "✗ LocalStack: Not running (Colima VM is stopped)"
    echo ""
    echo "=== Summary ==="
    echo "To start the environment: acme-local start [--argocd] [--cpu <count>]"
    exit 0
else
    echo "✗ Colima VM: Not found (profile: $ENV_NAME)"
    echo "✗ Kubernetes: Not running"
    echo ""
    echo "=== Istio Service Mesh ==="
    echo "✗ Istio: Not deployed (Colima VM not found)"
    echo ""
    echo "=== ArgoCD ==="
    echo "✗ ArgoCD: Not deployed (Colima VM not found)"
    echo ""
    echo "=== LocalStack ==="
    echo "✗ LocalStack: Not running (Colima VM not found)"
    echo ""
    echo "=== Summary ==="
    echo "To start the environment: acme-local start [--argocd] [--cpu <count>]"
    exit 0
fi
echo ""

# Check Istio status
echo "=== Istio Service Mesh ==="
if kubectl get namespace istio-system > /dev/null 2>&1; then
    echo "✓ Istio namespace: Exists"
    
    # Check istiod
    ISTIOD_STATUS=$(kubectl get pods -n istio-system -l app=istiod -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
    if [ "$ISTIOD_STATUS" = "Running" ]; then
        echo "✓ Istiod (control plane): Running"
    else
        echo "✗ Istiod (control plane): $ISTIOD_STATUS"
    fi
    
    # Check ingress gateway
    INGRESS_STATUS=$(kubectl get pods -n istio-ingress -l app=istio-ingress -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
    if [ "$INGRESS_STATUS" = "Running" ]; then
        echo "✓ Istio ingress gateway: Running"
        INGRESS_IP=$(kubectl get svc istio-ingress -n istio-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ -n "$INGRESS_IP" ]; then
            echo "  Ingress IP: $INGRESS_IP"
        fi
    else
        echo "✗ Istio ingress gateway: $INGRESS_STATUS"
    fi
else
    echo "✗ Istio: Not deployed"
fi
echo ""

# Check ArgoCD status
echo "=== ArgoCD ==="
if kubectl get namespace argocd > /dev/null 2>&1; then
    echo "✓ ArgoCD namespace: Exists"
    
    # Check ArgoCD server
    ARGOCD_STATUS=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
    if [ "$ARGOCD_STATUS" = "Running" ]; then
        echo "✓ ArgoCD server: Running"
        ARGOCD_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null | awk '{print $1}')
        ARGOCD_PORT=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}' 2>/dev/null)
        ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
        if [ -n "$ARGOCD_IP" ] && [ -n "$ARGOCD_PORT" ]; then
            echo "  Access URL: http://$ARGOCD_IP:$ARGOCD_PORT/"
            echo "  Username: admin"
            echo "  Password: $ARGOCD_PASS"
        fi
    else
        echo "✗ ArgoCD server: $ARGOCD_STATUS"
    fi
else
    echo "✗ ArgoCD: Not deployed"
fi
echo ""

# Check OCI Registry status
echo "=== OCI Registry ==="
REGISTRY_STATUS=$(colima exec --profile "$ENV_NAME" -- docker ps --filter "name=registry" --format "{{.Status}}" 2>/dev/null || echo "")
if [ -n "$REGISTRY_STATUS" ] && echo "$REGISTRY_STATUS" | grep -q "Up"; then
    echo "✓ OCI Registry: Running"
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null | awk '{print $1}')
    if [ -n "$NODE_IP" ]; then
        echo "  Endpoint: ${NODE_IP}:5000"
        echo "  Example: docker tag myimage:latest ${NODE_IP}:5000/myimage:latest"
    fi
else
    echo "✗ OCI Registry: Not running"
fi
echo ""

# Check LocalStack status
echo "=== LocalStack ==="
if command -v localstack > /dev/null 2>&1; then
    LOCALSTACK_STATUS=$(localstack status 2>&1)
    if echo "$LOCALSTACK_STATUS" | grep -q "running"; then
        echo "✓ LocalStack: Running"
        echo "  Endpoint: ${AWS_ENDPOINT_URL:-http://localhost:4566}"
    else
        echo "✗ LocalStack: Not running"
    fi
else
    echo "✗ LocalStack: Not installed"
fi
echo ""

# Summary
echo "=== Summary ==="
echo "To start the environment: acme-local start [--argocd] [--cpu <count>]"
echo "To stop the environment:  acme-local stop"
echo "To delete the environment: acme-local delete"
