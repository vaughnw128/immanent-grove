# Talos configs to be used in cluster.tf

locals {
  log_intake = "tcp://10.0.10.20:6051/"

  shared_machine_config = [
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
        allowSchedulingOnControlPlanes = true
      }
      machine = {
        logging = {
          destinations = [
            {
              endpoint = local.log_intake
              format   = "json_lines"
            }
          ]
        }
      }
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "KmsgLogConfig"
      name       = "log-intake"
      url        = local.log_intake
    }),
  ]

  controlplane_machine_config = [
    yamlencode({
      cluster = {
        controllerManager = {
          extraArgs = {
            bind-address = "0.0.0.0"
          }
        }
        scheduler = {
          extraArgs = {
            bind-address = "0.0.0.0"
          }
        }
        etcd = {
          extraArgs = {
            listen-metrics-urls = "http://0.0.0.0:2381"
          }
        }
      }
    }),
  ]
}
