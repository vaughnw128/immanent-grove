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

My k8s hardware is quite simple and 'cheap':
 - 1x UN100L Amd64 16gb memory
 - 2x UN150p Amd64 16gb memory
 - 1x UN1290 Amd64 32gb memory

I love these stupid Mini PCs, and they keep my power bill quite low. This is supplemented by a TrueNAS Scale 
system that runs some nice persistence services like Minio and is the backend for Democratic CSI.

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

Before upgrades, it may be smart to take an etcd snapshot:

```bash
talosctl -n 10.0.0.50 etcd snapshot etcd-backup.db
```

Upgrades run through Terraform (Digger) by editing `terraform/talos-bootstrap/talos-versions.tf`. Nodes upgrade one at a time (controlplane-1, 2, 3, then worker-1), each drained before reboot.

1. Bump `talos_os_version` one minor at a time (e.g. `v1.12.7` -> `v1.13.12`). Leave `talos_config_version` alone.
   1. To change extensions, build a new schematic at [factory.talos.dev](https://factory.talos.dev) (amd64, nocloud, iscsi-tools, qemu-guest-agent, nfsd) and update `talos_schematic`.
2. Open a PR. The plan should only update the four `talos_machine` resources.
3. Run `digger apply`, and after application, check etcd has no nodes still joining:

```bash
talosctl -n 10.0.0.50 etcd status
```

4. If a control plane fails to rejoin etcd, remove its stale member and re-run the apply:

```bash
talosctl -n 10.0.0.50 etcd remove-member <id>
```

## Kubernetes Upgrades

1. Check for component and Talos support. The current Talos minor must support the target (Talos 1.12 -> 1.35, 1.13 -> 1.36, 1.14 -> 1.37), and so must Cilium.
2. Bump `kubernetes_version` in `terraform/talos-bootstrap/talos-versions.tf`, one minor at a time.
3. Open a PR. The plan should only update `talos_cluster` (and the generated machine configs).
4. Run `digger apply`, and the Talos provider will run through a progressive upgrade over all the nodes.

```bash
kubectl get nodes
```

## Grabbing kubeconfig

```bash
export AWS_ACCESS_KEY_ID=<key-id>
export AWS_SECRET_ACCESS_KEY=<secret-key>
terraform init && terraform output -json kubeconfig | jq -r '.kubeconfig_raw' > ~/.kube/config
```