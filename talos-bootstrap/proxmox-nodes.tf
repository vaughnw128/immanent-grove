 ### TALOS IMAGES ###
# Super super important, these have:
#   - qemu-guest agent
#   - iscsi-tools
#   - nfsd
# No CLI options. This image here just needs to be used for the first install, images later will
# need to be updated with the talosctl command after generating a new image from factory.talos.dev

locals {
  nodes = [
      {
        name         = "controlplane-1"
        pve_node     = "havnor"
        controlplane = true
        ip           = "10.0.0.50"
        cpu          = 4
        memory       = 16
        disk         = 100
        arch         = "amd64"
        image        = "https://factory.talos.dev/image/4ec563327034da664de0e0f4b92cfbd68a4eac6700cd5f4f0ab2966eed213469/v1.10.5/nocloud-amd64.raw.zst"
      },
      {
        name         = "controlplane-2"
        pve_node     = "selidor"
        controlplane = true
        ip           = "10.0.0.53"
        cpu          = 4
        memory       = 16
        disk         = 100
        arch         = "amd64"
        image        = "https://factory.talos.dev/image/58e4656b31857557c8bad0585e1b2ee53f7446f4218f3fae486aa26d4f6470d8/v1.9.2/nocloud-amd64.raw.zst"
      },
      {
        name         = "controlplane-3"
        pve_node     = "gont"
        controlplane = true
        ip           = "10.0.0.54"
        cpu          = 4
        memory       = 16
        disk         = 100
        arch         = "amd64"
        image        = "https://factory.talos.dev/image/58e4656b31857557c8bad0585e1b2ee53f7446f4218f3fae486aa26d4f6470d8/v1.9.2/nocloud-amd64.raw.zst"
      },
      {
        name         = "worker-1"
        pve_node     = "atuan"
        controlplane = false
        ip           = "10.0.0.51"
        cpu          = 12
        memory       = 32
        disk         = 100
        arch         = "amd64"
        image        = "https://factory.talos.dev/image/58e4656b31857557c8bad0585e1b2ee53f7446f4218f3fae486aa26d4f6470d8/v1.9.2/nocloud-amd64.raw.zst"
      }
  ]
}