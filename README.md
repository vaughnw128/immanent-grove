# immanent-grove

[![Renovate](https://github.com/vaughnw128/immanent-grove/actions/workflows/renovate.yaml/badge.svg)](https://github.com/vaughnw128/immanent-grove/actions/workflows/renovate.yaml)
[![Flux Tests](https://github.com/vaughnw128/immanent-grove/actions/workflows/test.yaml/badge.svg)](https://github.com/vaughnw128/immanent-grove/actions/workflows/test.yaml)

K8s cluster bootstrapping, because nuking and rebuilding your homelab should be _easy_.

## Overview

This repository serves to let me control my entire k8s homelab environment with IaC, and is a test bed for my knowledge on modern DevOps principles. 
The cluster is bootstrapped with Terraform and then managed with FluxCD.

---

## Deployment

This cluster is built around Talos and Cilium, and heavily leverages the new Gateway API for exposing HTTPRoutes to both public and local audiences. I like building publicly facing things, so I want that proccess to be easy for me. This cluster is deployed on low-powered intel mini-pcs, using Talos as the base OS image. This makes for an easily IaC controlled environment, and the bootstrap process is quite quickly. The single Terraform script can get the entire lab fully deployed.

## Core Services
- [cilium](https://cilium.io/) - Container Network Interface, supporting Gateway API and networking observability
- [FluxCD](https://argo-cd.readthedocs.io/en/stable/) - GitOps and continuous deployment
- [Cloudflare-operator](https://github.com/adyanth/cloudflare-operator) - k8s operator for cloudflare tunnels and external DNS
- [democratic-csi](https://github.com/democratic-csi/democratic-csi) - k8s storageclass on TrueNAS
- [cert-manager](https://cert-manager.io/) - Automatic certificate requests
- trust-manager - Easy trust bundles for trusted local CAs!
- [reflector](https://github.com/emberstack/kubernetes-reflector) - Copy secrets across namespaces
- tailscale-operator - Create simple ingress routes to my tailnet
- external-secrets - Grab secrets from a secret store (1password) and expose them to the cluster

---

## Plans
- Add another local DNS server off-of-router, and set up a DNS terraform provider
- Set up external OIDC provider with Auth0
- UptimeKuma with preconfigured config

---

## Terraform Deployment

To bootstrap the cluster simply deploy with Terraform `terraform plan` & `terraform apply`. All of the variables will need to be
customized to your own cluster.

### Variables

Secret variables in `secret.auto.tfvars` must be configured:

```
# Proxmox
proxmox_api_token    = "tf-provisioner@pam!tf-provisioner=<secret>"
proxmox_ssh_username = "root"
proxmox_ssh_password = "<secretstuff>"

# Tailscale
ts_auth_key          = "tskey-auth-<secretstuff>"
```

## Testing

Tests can be run by applying manifests in `/examples` and verifying their output.