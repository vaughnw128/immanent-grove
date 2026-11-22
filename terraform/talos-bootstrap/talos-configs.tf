# Talos configs to be used in cluster.tf

locals {
  shared_machine_config = [
    yamlencode({
      cluster = {
        discovery = {
          enabled = true
        }
        network = {
          cni = {
            name = "none"
          }
        }
        proxy = {
          disabled = true
        }
        allowSchedulingOnControlPlanes = true
      }
    })
  ]
}