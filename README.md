# immanent-grove

[![Renovate](https://github.com/vaughnw128/immanent-grove/actions/workflows/renovate.yaml/badge.svg)](https://github.com/vaughnw128/immanent-grove/actions/workflows/renovate.yaml)
[![Flux Tests](https://github.com/vaughnw128/immanent-grove/actions/workflows/test.yaml/badge.svg)](https://github.com/vaughnw128/immanent-grove/actions/workflows/test.yaml)

K8s cluster bootstrapping, because nuking and rebuilding your homelab should be _easy_.

## Overview

This repository serves to let me control my entire k8s homelab environment with IaC, and is a test bed for my knowledge on modern DevOps principles. 
The cluster is bootstrapped with Terraform via Digger and then managed with FluxCD.

---

## Deployment

This cluster is built around Talos and Cilium, and heavily leverages the new Gateway API for exposing HTTPRoutes to both public and local audiences. 
I like building publicly facing things, so I want that proccess to be easy for me. This cluster is deployed on low-powered intel mini-pcs, using Talos as the base OS image. 
This makes for an easily IaC controlled environment, and the bootstrap process is quite quickly. The single Terraform script can get the entire lab fully deployed.

## Hardware

My k8s hardware is dead simple and 'cheap':
 - 1x UN100L Arm64 16gb memory
 - 1x UN1290 Amd64 32gb memory

I love these stupid Mini PCs, and they keep my power bill quite low. This is supplemented by a TrueNAS Scale 
system that runs some nice persistence services like Minio and is the backend for Democratic CSI.

## Core Services
- [cilium](https://cilium.io/) - Container Network Interface, supporting Gateway API and networking observability
- [FluxCD](https://argo-cd.readthedocs.io/en/stable/) - GitOps and continuous deployment
- [Cloudflare-operator](https://github.com/adyanth/cloudflare-operator) - k8s operator for cloudflare tunnels and external DNS
- [democratic-csi](https://github.com/democratic-csi/democratic-csi) - k8s storageclass on TrueNAS
- [cert-manager](https://cert-manager.io/) - Automatic certificate requests
- [reflector](https://github.com/emberstack/kubernetes-reflector) - Copy secrets across namespaces
- tailscale-operator - Create simple ingress routes to my tailnet
- external-secrets - Grab secrets from a secret store (1password) and expose them to the cluster

---

## Plans
- UptimeKuma with preconfigured config

---

## Terraform Deployment

To bootstrap the cluster simply deploy with Terraform `terraform plan` & `terraform apply`. All of the variables will need to be
customized to your own cluster.


### Backend

All of my TF code w/ Digger in Github Actions is backed by Minio for S3-like storage of the Terraform state. This makes things far easier, and even works well when running locally.
Keep the state off of my PC!!

### Variables

I pull super-duper secret values in with the OnePassword provider straight from my OnePassword vault. If this doesn't work to your liking or you don't use OnePassword, it can be commented out in favor
of `secret.auto.tfvars`:

```
# Proxmox
proxmox_api_token    = "tf-provisioner@pam!tf-provisioner=<secret>"
proxmox_ssh_username = "root"
proxmox_ssh_password = "<secretstuff>"
```

## Testing

Tests can be run by applying manifests in `/examples` and verifying their output.

## Talos Upgrades

```bash
# First upgrade the worker nodes
$ talosctl upgrade --nodes 10.0.0.52 -e 10.0.0.50 --image factory.talos.dev/nocloud-installer/84f66f3fa52900a0234636ae1da07d5b356cce774673951af35866142158fce6:v1.10.5
$ talosctl upgrade --nodes 10.0.0.51 -e 10.0.0.50 --image factory.talos.dev/nocloud-installer/84f66f3fa52900a0234636ae1da07d5b356cce774673951af35866142158fce6:v1.10.5

# Then finally the control plane node - In my case this is arm64, so needs a different image
$ talosctl upgrade --nodes 10.0.0.50 -e 10.0.0.50 --image factory.talos.dev/nocloud-installer/84f66f3fa52900a0234636ae1da07d5b356cce774673951af35866142158fce6:v1.10.5 
```