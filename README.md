# acme-local

A local development environment tool that creates an isolated Kubernetes cluster with Istio service mesh and LocalStack for AWS service emulation. Perfect for developing and testing cloud-native applications locally.

## Overview

`acme-local` automates the setup of a complete local development environment using:
- **Colima** - Container runtime and Kubernetes cluster (k3s)
- **Istio** - Service mesh for microservices
- **LocalStack** - AWS cloud service emulator
- **Custom CA certificates** - Support for corporate proxy/certificate authorities

## Prerequisites

Before using `acme-local`, ensure you have the following installed:

- **macOS** (with VZ virtualization support)
- **Homebrew** - Package manager for macOS
- **Colima** - `brew install colima`
- **Docker** - `brew install docker`
- **kubectl** - `brew install kubectl`
- **Helm** - `brew install helm`
- **LocalStack** - `brew install localstack` or `pip install localstack`

## Installation

To install `acme-local` as a system-wide utility:

1. Clone or download this repository:
   ```bash
   git clone https://github.com/jpbarto/acme-local.git
   cd acme-local
   ```

2. Create a symlink to make `acme-local` accessible from anywhere:
   ```bash
   sudo ln -s "$(pwd)/acme-local" /usr/local/bin/acme-local
   ```

3. Verify the installation:
   ```bash
   acme-local
   ```

You should see the usage information.

## Configuration

### Certificate Configuration

If you're behind a corporate proxy or need custom CA certificates:

1. Copy your certificate files to the `certs/` directory:
   ```bash
   cp ~/path/to/your-ca-cert.crt certs/
   # or
   cp ~/path/to/your-ca-cert.pem certs/
   ```

2. All `.crt` and `.pem` files in the `certs/` directory will be automatically installed in the Colima VM during startup.

See `certs/README.md` for more details.

### Environment Variables

Edit `local.env` to customize AWS credentials and endpoints for LocalStack:

```bash
AWS_ENDPOINT_URL='http://localhost:4566'
AWS_REGION='us-east-1'
AWS_ACCESS_KEY_ID='test'
AWS_SECRET_ACCESS_KEY='test'
```

You can source these variables in your shell or use `acme-local env` to export them.

## Usage

### Start the Environment

Start the local Kubernetes cluster with Istio and LocalStack:

```bash
acme-local start
```

This will:
- Create a Colima VM with 4 CPUs, 8GB RAM, and 20GB disk
- Install any CA certificates from the `certs/` directory
- Set up a k3s Kubernetes cluster (without Traefik)
- Install Istio service mesh with ingress gateway
- Start LocalStack for AWS service emulation

### Stop the Environment

Stop all running services and the Colima VM:

```bash
acme-local stop
```

This preserves the VM and its state for later use.

### Delete the Environment

Completely remove the environment and free up resources:

```bash
acme-local delete
```

This deletes the Colima VM and all associated data.

### Shell Access

Start an interactive shell with environment variables pre-configured:

```bash
acme-local shell
```

This starts the environment, exports AWS variables for LocalStack, and opens a shell. The environment is stopped when you exit the shell.

### Export Environment Variables

Export environment variables without starting the environment:

```bash
eval "$(acme-local env)"
```

This loads the variables from `local.env` into your current shell.

## Resource Configuration

The default resource allocation is:
- **CPU**: 4 cores
- **Memory**: 8 GB
- **Disk**: 20 GB
- **Network**: Enabled with address assignment
- **VM Type**: Apple Virtualization Framework (VZ)

To modify these settings, edit the `colima start` command in `start.sh`.

## Components

### Kubernetes (k3s)
- Lightweight Kubernetes distribution
- Traefik disabled to avoid conflicts with Istio
- Accessible via `kubectl` commands

### Istio Service Mesh
- Installed via Helm charts
- Control plane (`istiod`) in `istio-system` namespace
- Ingress gateway in `istio-ingress` namespace
- Default revision enabled

### LocalStack
- Emulates AWS services (S3, DynamoDB, Lambda, etc.)
- Accessible at `http://localhost:4566`
- Uses test credentials (see `local.env`)

## Troubleshooting

### Check Colima Status
```bash
colima status --profile acme-local
```

### Check Kubernetes Cluster
```bash
kubectl cluster-info
kubectl get nodes
```

### Check Istio Installation
```bash
kubectl get pods -n istio-system
kubectl get pods -n istio-ingress
```

### Check LocalStack
```bash
localstack status
```

### View Colima VM Logs
```bash
colima logs --profile acme-local
```

## Uninstallation

1. Delete the environment:
   ```bash
   acme-local delete
   ```

2. Remove the symlink:
   ```bash
   sudo rm /usr/local/bin/acme-local
   ```

3. Optionally remove the cloned repository:
   ```bash
   rm -rf /path/to/acme-local
   ```

## License

This project is provided as-is for internal development use.
