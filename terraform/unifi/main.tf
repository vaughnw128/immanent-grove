locals {
  # LoadBalancer IPs from the Cilium pool (10.0.10.0/24). The gateway IP is pinned
  # in infrastructure/configs/networking/public-gateway.yaml.
  public_gateway_ip = "10.0.10.7"
  minecraft_ip      = "10.0.10.3"
  factorio_ip       = "10.0.10.6"
}


resource "unifi_port_forward" "public_http" {
  count = var.route_public_web_to_cluster ? 1 : 0

  name                   = "public-gateway-http"
  protocol               = "tcp"
  dst_port               = "80"
  fwd_ip                 = local.public_gateway_ip
  fwd_port               = "80"
  port_forward_interface = "wan"
}

resource "unifi_port_forward" "public_https" {
  count = var.route_public_web_to_cluster ? 1 : 0

  name                   = "public-gateway-https"
  protocol               = "tcp"
  dst_port               = "443"
  fwd_ip                 = local.public_gateway_ip
  fwd_port               = "443"
  port_forward_interface = "wan"
}

# Game servers

resource "unifi_port_forward" "minecraft" {
  name                   = "minecraft"
  protocol               = "tcp"
  dst_port               = "25565"
  fwd_ip                 = local.minecraft_ip
  fwd_port               = "25565"
  port_forward_interface = "wan"
}

resource "unifi_port_forward" "factorio" {
  name                   = "factorio"
  protocol               = "udp"
  dst_port               = "34197"
  fwd_ip                 = local.factorio_ip
  fwd_port               = "34197"
  port_forward_interface = "wan"
}
