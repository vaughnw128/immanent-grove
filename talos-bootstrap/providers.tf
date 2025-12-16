terraform {
  backend "s3" {
    bucket = "tfstate"
    key    = "talos-bootstrap.tfstate"
    region = "us-east"

    endpoints = {
      s3 = "https://s3.vaughn.sh"
    }

    skip_credentials_validation = true
    skip_requesting_account_id = true
    skip_metadata_api_check = true
    skip_region_validation = true
    use_path_style = true
  }

  required_providers {
    onepassword = {
      source  = "1Password/onepassword"
      version = "3.0.1"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.87.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.8.1"
    }
  }
}

variable "onepassword_sdk_token" {
  type = string
  sensitive = true
}

provider "onepassword" {
  service_account_token = var.onepassword_sdk_token
}

data "onepassword_item" "proxmox_token" {
  vault = "immanent-grove"
  title = "proxmox-api-token"
}

data "onepassword_item" "proxmox_ssh" {
  vault = "immanent-grove"
  title = "proxmox-ssh"
}

# Provide SSH access to all nodes as well as an admin API token
provider "proxmox" {
  endpoint  = "https://havnor.pve.internal.vw-ops.net:8006/"
  insecure  = true
  api_token = data.onepassword_item.proxmox_token.credential

  ssh {
    agent    = true
    username = data.onepassword_item.proxmox_ssh.username
    password = data.onepassword_item.proxmox_ssh.password
  }
}