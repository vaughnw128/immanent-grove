locals {
  nodes = [
      {
        name         = "controlplane"
        pve_node     = "havnor"
        controlplane = true
        ip           = "10.0.0.50"
        cpu          = 4
        memory       = 16
        disk         = 100
        arch         = "amd64"
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
      },
    #   {
    #     name         = "worker-1"
    #     pve_node     = "atuan"
    #     controlplane = false
    #     ip           = "10.0.0.51"
    #     cpu          = 12
    #     memory       = 16
    #     disk         = 100
    #     arch         = "amd64"
    #   },
    #   {
    #     name         = "worker-2"
    #     pve_node     = "atuan"
    #     controlplane = false
    #     ip           = "10.0.0.52"
    #     cpu          = 12
    #     memory       = 16
    #     disk         = 100
    #     arch         = "amd64"
    # }
  ]
}