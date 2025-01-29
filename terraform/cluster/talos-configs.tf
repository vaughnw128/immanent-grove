# Talos configs to be used in cluster.tf

locals {
  shared_machine_config = [
    # Don't add the tailscale if you aren't using it
    var.ts_auth_key != "" ? yamlencode({
      apiVersion = "v1alpha1"
      kind       = "ExtensionServiceConfig"
      name       = "tailscale"
      environment = [
        "TS_AUTHKEY=${var.ts_auth_key}",
        "TS_ROUTES=${var.subnet}"
      ]
    }) : "",
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
      }
    })
  ]
}