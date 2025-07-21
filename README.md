# immanent-grove

[![Renovate](https://github.com/vaughnw128/immanent-grove/actions/workflows/renovate.yaml/badge.svg)](https://github.com/vaughnw128/immanent-grove/actions/workflows/renovate.yaml)
[![Flux Tests](https://github.com/vaughnw128/immanent-grove/actions/workflows/test.yaml/badge.svg)](https://github.com/vaughnw128/immanent-grove/actions/workflows/test.yaml)

K8s cluster bootstrapping, because nuking and rebuilding your homelab should be _easy_.

## Overview

This repository serves to let me control my entire k8s homelab environment with IaC, and is a test bed for my knowledge on modern DevOps principles. 
The cluster is bootstrapped with Terraform via Digger and then managed with FluxCD.

## Deployment

This cluster is built around Talos and Cilium, and heavily leverages the new Gateway API for exposing HTTPRoutes to both public and local audiences. 
I like building publicly facing things, so I want that proccess to be easy for me. This cluster is deployed on low-powered intel mini-pcs, using Talos as the base OS image. 
This makes for an easily IaC controlled environment, and the bootstrap process is quite quickly. The single Terraform script can get the entire lab fully deployed.

## Hardware

My k8s hardware is dead simple and 'cheap':
 - 1x UN100L Amd64 16gb memory
 - 1x UN150p Amd64 16gb memory
 - 1x UN1290 Amd64 32gb memory

I love these stupid Mini PCs, and they keep my power bill quite low. This is supplemented by a TrueNAS Scale 
system that runs some nice persistence services like Minio and is the backend for Democratic CSI.

## Core Features

### Terraform Features

| Category | Component           | Description                                  | File Path |
|----------|---------------------|----------------------------------------------|-----------|
| Infrastructure | Talos Kubernetes    | Bootstrapping Talos-based Kubernetes cluster | [talos-bootstrap/main.tf](talos-bootstrap/main.tf) |
| Infrastructure | Proxmox Nodes       | VM Node information for Proxmox              | [talos-bootstrap/proxmox-nodes.tf](talos-bootstrap/proxmox-nodes.tf) |
| Infrastructure | Talos Configuration | Talos-specific configurations                | [talos-bootstrap/talos-configs.tf](talos-bootstrap/talos-configs.tf) |


### Flux Features

| Category | Component                 | Description                              | File Path |
|----------|---------------------------|------------------------------------------|-----------|
| Core | Flux Operator             | Kubernetes resource reconciliation       | [cluster/flux-operator.yaml](cluster/flux-operator.yaml) |
| Infrastructure | Cert Manager              | TLS certificate management               | [infrastructure/controllers/cert-manager/helmrelease.yaml](infrastructure/controllers/cert-manager/helmrelease.yaml) |
| Infrastructure | Cilium                    | Network policy and CNI                   | [infrastructure/controllers/cilium/helmrelease.yaml](infrastructure/controllers/cilium/helmrelease.yaml) |
| Infrastructure | Cloudflare Tunnel         | External access via Cloudflare           | [infrastructure/controllers/cloudflare-tunnel/helmrelease.yaml](infrastructure/controllers/cloudflare-tunnel/helmrelease.yaml) |
| Infrastructure | Democratic CSI            | Storage management w/ TrueNAS            | [infrastructure/controllers/democratic-csi/helmrelease.yaml](archive/democratic-csi/helmrelease.yaml) |
| Infrastructure | External DNS              | DNS management w/ Unifi                  | [infrastructure/controllers/external-dns/helmrelease.yaml](infrastructure/controllers/external-dns/helmrelease.yaml) |
| Infrastructure | 1Password Connect         | Secret management integration            | [infrastructure/operators/1password-connect/helmrelease.yaml](infrastructure/operators/1password-connect/helmrelease.yaml) |
| Infrastructure | External Secrets Operator | External secrets management w/ 1Password | [infrastructure/operators/external-secrets/helmrelease.yaml](infrastructure/operators/external-secrets/helmrelease.yaml) |
| Infrastructure | Tailscale Operator        | VPN ingress resources                    | [infrastructure/operators/tailscale/helmrelease.yaml](infrastructure/operators/tailscale/helmrelease.yaml) |
| Applications | Uptime Kuma               | Uptime monitoring                        | [applications/uptime-kuma/helmrelease.yaml](applications/uptime-kuma/helmrelease.yaml) |
| Applications | Crosstown Traffic         | Personal location tracker                | [applications/crosstown-traffic/crosstown-traffic.yaml](applications/crosstown-traffic/crosstown-traffic.yaml) |
| Applications | Fission                   | Serverless framework deployment          | [applications/fission/helmrelease.yaml](applications/fission/helmrelease.yaml) |
| Applications | Minecraft                 | It's Minecraft!!                         | [applications/minecraft/helmrelease.yaml](applications/minecraft/helmrelease.yaml) |
| Applications | Whoami                    | Simple test application                  | [applications/whoami/deployment.yaml](applications/whoami/deployment.yaml) |

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

# Then finally the control plane node
$ talosctl upgrade --nodes 10.0.0.50 -e 10.0.0.50 --image factory.talos.dev/nocloud-installer/84f66f3fa52900a0234636ae1da07d5b356cce774673951af35866142158fce6:v1.10.5 
```

## Upgrading Controlplanes with Terraform

Upgrading via terraform can be a bit nerve-wracking and annoying, but is sometimes needed in order to get the images all set up properly.

> NOTE!!!! DO NOT DO THIS IF YOU ONLY HAVE ONE CONTROLPLANE NODE!! THIS WILL BREAK EVERYTHING!!
> 
> THIS UPDATE PROCEDURE REQUIRES AT LEAST THREE CONTROLPLANE NODES FOR HA!!

1. Generate a new Talos factory image at [factory.talos.dev](https://factory.talos.dev)
   1. The image must be: amd64, Nocloud, and have the addons iscsi-tools, qemu-guest-agent, and nfsd.
2. Replace the node image in proxmox-nodes.tf
3. Plan and apply the Terraform, ensuring that there are only the talos machine config, proxmox node, and talos image modified.
4. If the node fails to join etcd, delete the member from etcd to ensure it can reach quorum

```bash
talosctl --endpoints 10.0.0.53 -n 10.0.0.53,10.0.0.54 etcd remove-member <id>
```

6. Check etcd to ensure quorum. This should show learners as well. Do not proceed to upgrade another controlplane unless there are no learners.

```bash
talosctl --endpoints 10.0.0.53 etcd status
```

7. Check that the node is started

```bash
k get nodes
```