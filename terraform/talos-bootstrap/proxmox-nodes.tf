# Proxmox VMs for the Talos nodes. Talos and Kubernetes versions live in talos-versions.tf.

locals {
  # Disk image a new VM boots from. Only used when a VM is created, and does not need to be updated.
  talos_boot_image = "https://factory.talos.dev/image/${local.talos_schematic}/v1.12.7/nocloud-amd64.raw.zst"

  nodes = [
    {
      name         = "controlplane-1"
      pve_node     = "havnor"
      controlplane = true
      ip           = "10.0.0.50"
      cpu          = 4
      memory       = 16
      disk         = 100
    },
    {
      name         = "controlplane-2"
      pve_node     = "selidor"
      controlplane = true
      ip           = "10.0.0.51"
      cpu          = 4
      memory       = 16
      disk         = 100
    },
    {
      name         = "controlplane-3"
      pve_node     = "gont"
      controlplane = true
      ip           = "10.0.0.52"
      cpu          = 4
      memory       = 16
      disk         = 100
    },
    {
      name         = "worker-1"
      pve_node     = "atuan"
      controlplane = false
      ip           = "10.0.0.53"
      cpu          = 12
      memory       = 32
      disk         = 100
    }
  ]
}
