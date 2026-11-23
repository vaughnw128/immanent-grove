# Talos and Kubernetes versions.

locals {
  # talos_os_version:  Installed Talos version. Changing it upgrades the nodes one at a time through chained nodes
  # with a proper drain prior to reboot
  talos_os_version = "v1.13.12"

  # kubernetes_version Changing it runs Talos's upgrade-k8s through talos_cluster. Each Talos minor
  # supports Kubernetes up to: 1.12 -> 1.35, 1.13 -> 1.36, 1.14 -> 1.37. Cilium must also support the k8s version.
  kubernetes_version = "v1.35.0"

  # talos_config_version: Config-generation the cluster was created with. Leave it alone on
  # upgrades, bumping it regenerates the machine configuration.
  talos_config_version = "v1.12.0"

  # Image Factory schematic with iscsi-tools, nfsd and qemu-guest-agent
  talos_schematic = "84f66f3fa52900a0234636ae1da07d5b356cce774673951af35866142158fce6"
  talos_installer = "factory.talos.dev/nocloud-installer/${local.talos_schematic}:${local.talos_os_version}"
}
