# Certificates Directory

This directory contains CA certificates that need to be installed in the Colima VM to enable proper SSL/TLS communication with corporate or custom certificate authorities.

## Purpose

When running Kubernetes clusters via Colima, the VM needs to trust your organization's certificate authorities. This is particularly important if you're behind a corporate proxy or using internal services with custom certificates.

## Usage

1. Copy your organization's CA certificate(s) to this directory:
   ```bash
   cp ~/path/to/your-ca-cert.crt certs/
   # or
   cp ~/path/to/your-ca-cert.pem certs/
   ```

2. Run `acme-local start` to create the environment with all certificates installed

All `.crt` and `.pem` files in this directory will be automatically copied to the Colima VM and installed as trusted certificates during startup.

## Notes

- Certificate files should be in PEM format with a `.crt` or `.pem` extension
- Multiple certificates can be stored in this directory
- Certificates are copied into the Colima VM during the `start.sh` script execution
- This directory is included in `.gitignore` to avoid committing sensitive certificate data
