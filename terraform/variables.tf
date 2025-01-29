variable "proxmox_api_token" {
  type      = string
  sensitive = true
}

variable "proxmox_ssh_username" {
  type      = string
  sensitive = true
}

variable "proxmox_ssh_password" {
  type      = string
  sensitive = true
}

variable "ts_auth_key" {
  type      = string
  sensitive = true
}

variable "cloudflare_token" {
  type      = string
  sensitive = true
}

variable "truenas_api_key" {
  type      = string
  sensitive = true
}

variable "cloudflare_api_key" {
  type      = string
  sensitive = true
}

variable "public_domain" {
  type      = string
  sensitive = true
}

variable "email" {
  type      = string
  sensitive = true
}

variable "cloudflare_account_id" {
  type      = string
  sensitive = true
}