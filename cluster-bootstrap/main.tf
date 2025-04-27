locals {
  nodes = [{
    name         = "controlplane"
    pve_node     = "havnor"
    controlplane = true
    ip           = "10.0.0.50"
    cpu          = 4
    memory       = 16
    disk         = 100
    },
    {
      name         = "worker-1"
      pve_node     = "atuan"
      controlplane = false
      ip           = "10.0.0.51"
      cpu          = 12
      memory       = 16
      disk         = 100
    },
    {
      name         = "worker-2"
      pve_node     = "atuan"
      controlplane = false
      ip           = "10.0.0.52"
      cpu          = 12
      memory       = 16
      disk         = 100
  }]
}

module "cluster" {
  source = "./cluster-mod"

  # Base cluster details
  name            = "immanent-grove"
  subnet          = "10.0.0.0/16"
  default_gateway = "10.0.0.1"
  nodes           = local.nodes
  talos_image     = "https://factory.talos.dev/image/58e4656b31857557c8bad0585e1b2ee53f7446f4218f3fae486aa26d4f6470d8/v1.9.2/nocloud-amd64.raw.zst"
  local_domain    = "apicius.local"
  public_domain   = var.public_domain

  # Cilium
  cilium_ip_pool = "10.0.10.0/24"

  # Config locations - If configs should not be saved, remove the below paths.
  talosconfig_path = "/home/apicius/.talos/config"
  kubeconfig_path  = "/home/apicius/.kube/config"

  # Cloudflare - External access via tunnels and DNS
  tls_email             = var.email
  cloudflare_token      = var.cloudflare_token
  cloudflare_api_key    = var.cloudflare_api_key
  cloudflare_account_id = var.cloudflare_account_id

  # TrueNAS - NFS StorageClass
  truenas_server  = "roke.apicius.local"
  truenas_api_key = var.truenas_api_key

  # Optional features
  ts_auth_key = var.ts_auth_key # Talos Extension Setup - This is not needed, but will need a different image provided as the listed one uses tailscale.
  portainer   = true

}

output "talosconfig" {
  value     = module.cluster.talosconfig
  sensitive = true
}

output "kubeconfig" {
  value     = module.cluster.kubeconfig
  sensitive = true
}