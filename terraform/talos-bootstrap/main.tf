locals {
  name            = "immanent-grove"
  default_gateway = "10.0.0.1"
}

# #### Proxmox VM base setup ####

# Nocloud image must exist on all nodes of the proxmox cluster

resource "proxmox_virtual_environment_download_file" "talos_nocloud_image" {
  for_each     = { for node in local.nodes : node.pve_node => node }
  content_type = "iso"
  datastore_id = "local"
  node_name    = each.key

  file_name               = "talos-nocloud-amd64.img"
  url                     = each.value.image
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

  reboot_after_update = true

  cpu {
    cores = each.value.cpu
    type  = each.value.cpu_type
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
    prevent_destroy = true
    ignore_changes = [
      network_device
    ]
  }
}

# #### Talos Cluster Setup ####

resource "talos_machine_secrets" "machine_secrets" {

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }

}

locals {
  cluster_endpoint_ip      = "cluster.internal.vw-ops.net"
  cluster_controlplane_ips = [for node in local.nodes : node.ip if node.controlplane == true]
}

data "talos_client_configuration" "talosconfig" {
  cluster_name         = local.name
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  endpoints            = local.cluster_controlplane_ips
}

data "talos_machine_configuration" "machineconfig" {
  for_each           = { for node in local.nodes : node.name => node }
  cluster_name       = local.name
  cluster_endpoint   = "https://${local.cluster_endpoint_ip}:6443"
  machine_type       = each.value.controlplane == true ? "controlplane" : "worker"
  machine_secrets    = talos_machine_secrets.machine_secrets.machine_secrets
  talos_version      = local.talos_config_version
  kubernetes_version = local.kubernetes_version
  config_patches = concat(local.shared_machine_config, [
    yamlencode({
      machine = {
        install = {
          image = local.talos_installer
        }
      }
    })
  ])
}

removed {
  from = talos_machine_configuration_apply.config_apply

  lifecycle {
    destroy = false
  }
}

removed {
  from = talos_machine_bootstrap.bootstrap

  lifecycle {
    destroy = false
  }
}

locals {
  talos_nodes = { for node in local.nodes : node.name => node }
}

# Chained talos machines such that upgrades reboot one at a time, with the controlplanes first and then the workers.
resource "talos_machine" "controlplane_1" {
  depends_on                      = [proxmox_virtual_environment_vm.talos_vm]
  node                            = local.talos_nodes["controlplane-1"].ip
  client_configuration            = talos_machine_secrets.machine_secrets.client_configuration
  machine_configuration           = data.talos_machine_configuration.machineconfig["controlplane-1"].machine_configuration
  kubeconfig                      = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  image                           = local.talos_installer
  drain_on_upgrade                = true
  ignore_kubernetes_upgrade_drift = true

  timeouts = {
    create = "30m"
    update = "30m"
  }
}

resource "talos_machine" "controlplane_2" {
  depends_on                      = [talos_machine.controlplane_1]
  node                            = local.talos_nodes["controlplane-2"].ip
  client_configuration            = talos_machine_secrets.machine_secrets.client_configuration
  machine_configuration           = data.talos_machine_configuration.machineconfig["controlplane-2"].machine_configuration
  kubeconfig                      = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  image                           = local.talos_installer
  drain_on_upgrade                = true
  ignore_kubernetes_upgrade_drift = true

  timeouts = {
    create = "30m"
    update = "30m"
  }
}

resource "talos_machine" "controlplane_3" {
  depends_on                      = [talos_machine.controlplane_2]
  node                            = local.talos_nodes["controlplane-3"].ip
  client_configuration            = talos_machine_secrets.machine_secrets.client_configuration
  machine_configuration           = data.talos_machine_configuration.machineconfig["controlplane-3"].machine_configuration
  kubeconfig                      = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  image                           = local.talos_installer
  drain_on_upgrade                = true
  ignore_kubernetes_upgrade_drift = true

  timeouts = {
    create = "30m"
    update = "30m"
  }
}

resource "talos_machine" "worker_1" {
  depends_on                      = [talos_machine.controlplane_3]
  node                            = local.talos_nodes["worker-1"].ip
  client_configuration            = talos_machine_secrets.machine_secrets.client_configuration
  machine_configuration           = data.talos_machine_configuration.machineconfig["worker-1"].machine_configuration
  kubeconfig                      = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  image                           = local.talos_installer
  drain_on_upgrade                = true
  ignore_kubernetes_upgrade_drift = true

  timeouts = {
    create = "30m"
    update = "30m"
  }
}

# Bootstraps etcd (a no-op on this already-bootstrapped cluster)
resource "talos_cluster" "cluster" {
  depends_on = [
    talos_machine.controlplane_1,
    talos_machine.controlplane_2,
    talos_machine.controlplane_3,
    talos_machine.worker_1,
  ]
  node                 = local.cluster_controlplane_ips[0]
  control_plane_nodes  = local.cluster_controlplane_ips
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  kubernetes_version   = local.kubernetes_version

  timeouts = {
    create = "30m"
    update = "60m"
  }
}

resource "talos_cluster_kubeconfig" "kubeconfig" {
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  node = local.cluster_controlplane_ips[0]
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.kubeconfig
  sensitive = true
}

output "talosconfig" {
  value     = data.talos_client_configuration.talosconfig
  sensitive = true
}

output "machine_config_inputs" {
  value = {
    for name, node in local.talos_nodes :
    name => {
      node   = node.ip
      config = data.talos_machine_configuration.machineconfig[name].machine_configuration
    }
  }
  sensitive = true
}
