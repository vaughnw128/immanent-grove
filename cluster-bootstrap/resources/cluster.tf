# #### Proxmox VM base setup ####

# Nocloud image must exist on all nodes of the proxmox cluster

resource "proxmox_virtual_environment_download_file" "talos_nocloud_image" {
  for_each     = toset([for node in var.nodes : node.pve_node])
  content_type = "iso"
  datastore_id = "local"
  node_name    = each.key

  file_name               = "talos-nocloud-amd64.img"
  url                     = var.talos_image
  decompression_algorithm = "zst"
  overwrite               = false
}

resource "proxmox_virtual_environment_vm" "talos_vm" {
  for_each    = { for node in var.nodes : node.name => node }
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
        gateway = var.default_gateway
      }
    }
  }
}

# #### Talos Cluster Setup ####

resource "talos_machine_secrets" "machine_secrets" {}

locals {
  cluster_endpoint_ip      = { for k, v in var.nodes : k => v if v.controlplane == true }[0].ip
  cluster_controlplane_ips = [for node in var.nodes : node.ip if node.controlplane == true]
  cluster_worker_ips       = [for node in var.nodes : node.ip if node.controlplane == false]
}

# Bootstrap talos cluster with custom configs from talos-configs.tf

data "talos_client_configuration" "talosconfig" {
  cluster_name         = var.name
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  endpoints            = local.cluster_controlplane_ips
}

data "talos_machine_configuration" "machineconfig" {
  for_each         = { for node in var.nodes : node.name => node }
  cluster_name     = var.name
  cluster_endpoint = "https://${local.cluster_endpoint_ip}:6443"
  machine_type     = each.value.controlplane == true ? "controlplane" : "worker"
  machine_secrets  = talos_machine_secrets.machine_secrets.machine_secrets
}

resource "talos_machine_configuration_apply" "config_apply" {
  for_each                    = { for node in var.nodes : node.name => node }
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

# Check the health after bootstrap
# Skip kubernetes check until after cilium install as nodes will not be networked

data "talos_cluster_health" "bootstrap_health" {
  depends_on             = [talos_machine_configuration_apply.config_apply]
  client_configuration   = data.talos_client_configuration.talosconfig.client_configuration
  control_plane_nodes    = local.cluster_controlplane_ips
  worker_nodes           = local.cluster_worker_ips
  endpoints              = data.talos_client_configuration.talosconfig.endpoints
  skip_kubernetes_checks = true
}

resource "talos_cluster_kubeconfig" "kubeconfig" {
  depends_on           = [talos_machine_bootstrap.bootstrap]
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  node                 = local.cluster_endpoint_ip
}

# Check cluster health after cilium release

# data "talos_cluster_health" "health" {
#   depends_on           = [ helm_release.cilium ]
#   client_configuration = data.talos_client_configuration.talosconfig.client_configuration
#   control_plane_nodes  = local.cluster_controlplane_ips
#   worker_nodes         = local.cluster_worker_ips
#   endpoints            = data.talos_client_configuration.talosconfig.endpoints
# }

# Export talos and kubeconfig for saving to system

resource "local_file" "talosconfig_localfile" {
  count           = var.talosconfig_path != "" ? 1 : 0
  content         = data.talos_client_configuration.talosconfig.talos_config
  filename        = var.talosconfig_path
  file_permission = "0644"
}

resource "local_file" "kubeconfig_localfile" {
  count           = var.kubeconfig_path != "" ? 1 : 0
  content         = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  filename        = var.kubeconfig_path
  file_permission = "0644"
}

output "talosconfig" {
  value     = data.talos_client_configuration.talosconfig.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  sensitive = true
}