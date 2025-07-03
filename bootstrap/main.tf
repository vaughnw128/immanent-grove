locals {
  name            = "immanent-grove"
  default_gateway = "10.0.0.1"
  talos_image     = "https://factory.talos.dev/image/58e4656b31857557c8bad0585e1b2ee53f7446f4218f3fae486aa26d4f6470d8/v1.9.2/nocloud-amd64.raw.zst"
}

# #### Proxmox VM base setup ####

# Nocloud image must exist on all nodes of the proxmox cluster

resource "proxmox_virtual_environment_download_file" "talos_nocloud_image" {
  for_each     = toset([for node in local.nodes : node.pve_node])
  content_type = "iso"
  datastore_id = "local"
  node_name    = each.key

  file_name               = "talos-nocloud-amd64.img"
  url                     = local.talos_image
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
}

# #### Talos Cluster Setup ####

resource "talos_machine_secrets" "machine_secrets" {}

locals {
  cluster_endpoint_ip      = { for k, v in local.nodes : k => v if v.controlplane == true }[0].ip
  cluster_controlplane_ips = [for node in local.nodes : node.ip if node.controlplane == true]
  cluster_worker_ips       = [for node in local.nodes : node.ip if node.controlplane == false]
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

# Check the health after bootstrap

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

output "bootstrap_health" {
  value = data.talos_cluster_health.bootstrap_health
  description = "Health of the cluster"
}