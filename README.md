# immanent-grove

K8s cluster bootstrapping, because nuking and rebuilding your homelab should be _easy_.

## Overview

This repository serves to let me control my entire k8s homelab environment with IaC, and is a test bed for my knowledge on modern DevOps principles. The primary method of deployment is built on [Terraform](https://www.terraform.io/) and [Helm](https://helm.sh/).

---

## Deployment

This cluster is built around Talos and Cilium, and heavily leverages the new Gateway API for exposing HTTPRoutes to both public and local audiences. I like building publicly facing things, so I want that proccess to be easy for me. This cluster is deployed on low-powered intel mini-pcs, using Talos as the base OS image. This makes for an easily IaC controlled environment, and the bootstrap process is quite quickly. The single Terraform script can get the entire lab fully deployed.

## Core Services
- [cilium](https://cilium.io/) - Container Network Interface, supporting Gateway API and networking observability
- [Prometheus/Grafana](https://grafana.com/) - Observability and metrics
- [ArgoCD](https://argo-cd.readthedocs.io/en/stable/) - GitOps and continuous deployment
- [Cloudflare-operator](https://github.com/adyanth/cloudflare-operator) - k8s operator for cloudflare tunnels and external DNS
- [democratic-csi](https://github.com/democratic-csi/democratic-csi) - k8s storageclass on TrueNAS
- [cert-manager](https://cert-manager.io/) - Automatic certificate requests
- [portainer](https://www.portainer.io/) - Hook k8s into existing portainer
- [synkronized](https://github.com/vaughnw128/synkronized) - ArgoCD based deployment pipeline
- [reflector](https://github.com/emberstack/kubernetes-reflector) - Copy secrets across namespaces

---

## Plans
- Add another local DNS server off-of-router, and set up a DNS terraform provider
- Set up external OIDC provider with Auth0
- UptimeKuma with preconfigured config

---

## Terraform Deployment

The Terraform IaC can easily be deployed using the `immanent-grove` script, but requires some secret variables to first be set.

### Variables

Secret variables in `secret.auto.tfvars` must be configured:

```
# Proxmox
proxmox_api_token    = "tf-provisioner@pam!tf-provisioner=<secret>"
proxmox_ssh_username = "root"
proxmox_ssh_password = "<secretstuff>"

# Tailscale
ts_auth_key          = "tskey-auth-<secretstuff>"

# Cloudflare
email = "fake@person.com"
public_domain = "fake.domain"
cloudflare_token = "<secretstuff>"
cloudflare_api_key = "<secretstuff>"
cloudflare_account_id = "<secretstuff>"

# TrueNAS
truenas_api_key = 3-<secretstuff>
```

### Deploy script

Terraform can be applied using the handy `./immanent-grove` script. This allows for pulling of recent helm chart versions prior to apply.

1. `./immanent-grove plan` to plan
2. `./immanent-grove apply` to apply (will auto-approve)
3. `./immanent-grove vault-init` to initialize vault
4. `./immanent-grove dns` to grab gateway IPs for internal DNS records

## Testing

Tests can be run by applying manifests in `/examples` and verifying their output.
