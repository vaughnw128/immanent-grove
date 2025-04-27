# CRD Manifests for HTTP Gateway
# Waits for cluster to be bootstrapped before applying

locals {
  gateway_crd_version = "v1.2.0" # Maybe find a way to pass in this version?
  gateway_crd_manifests = {
    gatewayclasses : "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${local.gateway_crd_version}/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml",
    gateways : "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${local.gateway_crd_version}/config/crd/standard/gateway.networking.k8s.io_gateways.yaml",
    httproutes : "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${local.gateway_crd_version}/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml",
    referencegrants : "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${local.gateway_crd_version}/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml",
    grpcroutes : "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${local.gateway_crd_version}/config/crd/experimental/gateway.networking.k8s.io_grpcroutes.yaml",
    tlsroutes : "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${local.gateway_crd_version}/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml"
  }
}

data "http" "gateway_manifest_file" {
  for_each = local.gateway_crd_manifests
  url      = each.value
}

resource "kubectl_manifest" "gateway_crds" {
  depends_on       = [talos_cluster_kubeconfig.kubeconfig, data.talos_cluster_health.bootstrap_health, local_file.talosconfig_localfile, local_file.kubeconfig_localfile]
  for_each         = local.gateway_crd_manifests
  yaml_body        = data.http.gateway_manifest_file[each.key].response_body
  sensitive_fields = ["apiVersion", "kind", "metadata", "status", "spec"] # This is to reduce noise in plan logs
}

# Deploy the custom cilium helm release from ./charts/cilium
# Values are defined in ./charts/cilium/values.yaml
# The chart is pulled in as a chart dependant, and additional configs are added to ./charts/cilium/templates
# Templates are weighted with helm hooks to install after cilium CRDs have been added
# This release also waits for the cluster to be bootstrapped

resource "helm_release" "cilium" {
  depends_on = [kubectl_manifest.gateway_crds, talos_cluster_kubeconfig.kubeconfig]
  name       = "cilium"
  chart      = "${path.module}/charts/cilium"
  namespace  = "kube-system"

  # Wait is false due to issues with helm 3.0.0-pre1
  wait          = false
  wait_for_jobs = false
}

# We need to wait for the cilium chart due to issues with helm terraform provider.
# Cilium must be set up before anything else can be initialized
resource "time_sleep" "wait_cilium" {
  depends_on = [helm_release.cilium]

  create_duration = "30s"
}

resource "kubectl_manifest" "ciliuml2announcementpolicy_kube_system_external" {
  depends_on = [helm_release.cilium, time_sleep.wait_cilium]
  yaml_body = yamlencode({
    "apiVersion" = "cilium.io/v2alpha1"
    "kind"       = "CiliumL2AnnouncementPolicy"
    "metadata" = {
      "name"      = "external"
      "namespace" = "kube-system"
    }
    "spec" = {
      "interfaces" = [
        "^eth[0-9]+",
      ]
      "loadBalancerIPs" = true
      "nodeSelector" = {
        "matchExpressions" = [
          {
            "key"      = "node-role.kubernetes.io/control-plane"
            "operator" = "DoesNotExist"
          },
        ]
      }
    }
  })
}

# Initialize IP pool to be used by cilium for l2 announcements.
# I typically pass in a full /24 subnet, and have my local IP space set up in the /16 cidr block
resource "kubectl_manifest" "ciliumloadbalancerippool_kube_system_external" {
  depends_on = [helm_release.cilium, time_sleep.wait_cilium]
  yaml_body = yamlencode({
    "apiVersion" = "cilium.io/v2alpha1"
    "kind"       = "CiliumLoadBalancerIPPool"
    "metadata" = {
      "name"      = "external"
      "namespace" = "kube-system"
    }
    "spec" = {
      "blocks" = [
        {
          "cidr" = var.cilium_ip_pool
        }
      ]
    }
  })
}


