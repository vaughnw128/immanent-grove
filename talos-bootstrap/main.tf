locals {
  name            = "immanent-grove"
  default_gateway = "10.0.0.1"

  ### TALOS IMAGES ###
  # Super super important, these have:
  #   - qemu-guest-agent
  #   - iscsi-tools
  #   - nfsd
  #   - vm
  # It has no CLI arguments

  talos_image_amd64     = "https://factory.talos.dev/image/4ec563327034da664de0e0f4b92cfbd68a4eac6700cd5f4f0ab2966eed213469/v1.10.5/nocloud-amd64.raw.zst"
  talos_image_arm64     = "https://factory.talos.dev/image/84f66f3fa52900a0234636ae1da07d5b356cce774673951af35866142158fce6/v1.10.5/nocloud-arm64.raw.zst"
}

# #### Proxmox VM base setup ####

# Nocloud image must exist on all nodes of the proxmox cluster

resource "proxmox_virtual_environment_download_file" "talos_nocloud_image" {
  for_each     = { for node in local.nodes : node.pve_node => node... }
  content_type = "iso"
  datastore_id = "local"
  node_name    = each.key

  file_name               = "talos-nocloud-amd64.img"
  url                     = each.key == "pve_node" ? local.talos_image_amd64 : local.talos_image_arm64
  decompression_algorithm = "zst"
  overwrite               = false
}

resource "proxmox_virtual_environment_vm" "talos_vm" {
  for_each    = { for node in local.nodes : node.name => node }
  name        = "talos-${each.key}"
  description = "Managed by Terraform"
  tags        = ["terraform", "talos"]
  node_name   = each.value.pve_node
  on_boot     = true

  cpu {
    cores = each.value.cpu
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = each.value.memory * 1024
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = "vmbr0"
  }

  disk {
    datastore_id = "local-lvm"
    file_id      = proxmox_virtual_environment_download_file.talos_nocloud_image[each.value.pve_node].id
    file_format  = "raw"
    interface    = "virtio0"
    size         = each.value.disk
  }

  operating_system {
    type = "l26" # Linux Kernel 2.6 - 5.X.
  }

  initialization {
    datastore_id = "local-lvm"
    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = local.default_gateway
      }
    }
  }

  lifecycle {
    ignore_changes = [
      network_device,
      vga,
      initialization,
      network_interface_names,
      mac_addresses,
      ipv4_addresses,
      ipv6_addresses
    ]
  }
}

# #### Talos Cluster Setup ####

resource "talos_machine_secrets" "machine_secrets" {}

locals {
  cluster_endpoint_ip      = { for k, v in local.nodes : k => v if v.controlplane == true }[0].ip
  cluster_controlplane_ips = [for node in local.nodes : node.ip if node.controlplane == true]
}

# Bootstrap talos cluster with custom configs from talos-configs.tf

data "talos_client_configuration" "talosconfig" {
  cluster_name         = local.name
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  endpoints            = local.cluster_controlplane_ips
}

data "talos_machine_configuration" "machineconfig" {
  for_each         = { for node in local.nodes : node.name => node }
  cluster_name     = local.name
  cluster_endpoint = "https://${local.cluster_endpoint_ip}:6443"
  machine_type     = each.value.controlplane == true ? "controlplane" : "worker"
  machine_secrets  = talos_machine_secrets.machine_secrets.machine_secrets
}

resource "talos_machine_configuration_apply" "config_apply" {
  for_each                    = { for node in local.nodes : node.name => node }
  depends_on                  = [proxmox_virtual_environment_vm.talos_vm]
  client_configuration        = talos_machine_secrets.machine_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.machineconfig[each.key].machine_configuration
  node                        = each.value.ip
  config_patches              = local.shared_machine_config
}

resource "talos_machine_bootstrap" "bootstrap" {
  depends_on           = [talos_machine_configuration_apply.config_apply]
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  node                 = local.cluster_endpoint_ip
}