terraform {
  backend "s3" {
    bucket = "tfstate"
    key    = "unifi.tfstate"
    region = "us-east"

    endpoints = {
      s3 = "https://s3.vaughn.sh"
    }

    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true
  }

  required_providers {
    onepassword = {
      source  = "1Password/onepassword"
      version = "3.3.1"
    }
    unifi = {
      source  = "filipowm/unifi"
      version = "1.1.0"
    }
  }
}

variable "onepassword_sdk_token" {
  type      = string
  sensitive = true
}

provider "onepassword" {
  service_account_token = var.onepassword_sdk_token
}

data "onepassword_item" "unifi_api_key" {
  vault = "immanent-grove"
  title = "unifi-terraform"
}

provider "unifi" {
  api_url        = "https://10.0.0.1"
  api_key        = data.onepassword_item.unifi_api_key.credential
  allow_insecure = true
}
