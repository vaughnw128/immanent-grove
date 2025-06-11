terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.78.1"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.7.0"
    }
  }
}

# Provide SSH access to all nodes as well as an admin API token
provider "proxmox" {
  endpoint  = "https://havnor.pve.apicius.local:8006/"
  insecure  = true
  api_token = var.proxmox_api_token

  ssh {
    agent    = true
    username = var.proxmox_ssh_username
    password = var.proxmox_ssh_password
  }
}