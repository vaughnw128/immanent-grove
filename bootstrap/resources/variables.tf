variable "nodes" {
  type = any
}

variable "default_gateway" {
  type = string
}

variable "name" {
  type = string
}

variable "subnet" {
  type = string
}

# Defaults to a preconfigured nocloud image with tailscale built in
variable "talos_image" {
  type    = string
  default = "https://factory.talos.dev/image/58e4656b31857557c8bad0585e1b2ee53f7446f4218f3fae486aa26d4f6470d8/v1.9.2/nocloud-amd64.raw.zst"
}

variable "ts_auth_key" {
  type      = string
  sensitive = true
}

variable "talosconfig_path" {
  type = string
}

variable "kubeconfig_path" {
  type = string
}