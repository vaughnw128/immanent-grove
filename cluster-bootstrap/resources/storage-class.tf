resource "kubectl_manifest" "democratic_csi_namespace" {
  depends_on = [talos_cluster_kubeconfig.kubeconfig, data.talos_cluster_health.bootstrap_health]
  yaml_body = yamlencode({
    "apiVersion" = "v1"
    "kind"       = "Namespace"
    "metadata" = {
      "name" = "democratic-csi"
      "labels" = {
        "pod-security.kubernetes.io/enforce" = "privileged"
      }
    }
  })
}

# Deploy the custom cilium helm release from ./charts/democratic-csi
# Values are defined in ./charts/democratic-csi/values.yaml
# The chart is pulled in as a chart dependant, and additional configs are added to ./charts/democratic-csi/templates
# This release also waits for the cluster to be bootstrapped

# https://jonathangazeley.com/2021/01/05/using-truenas-to-provide-persistent-storage-for-kubernetes/
# https://github.com/democratic-csi/democratic-csi/blob/master/examples/freenas-api-nfs.yaml

resource "helm_release" "democratic_csi" {
  depends_on = [talos_cluster_kubeconfig.kubeconfig, kubectl_manifest.democratic_csi_namespace]
  name       = "democratic-csi"
  chart      = "${path.module}/charts/democratic-csi"
  namespace  = "democratic-csi"

  # Wait is false due to issues with helm 3.0.0-pre1
  wait          = false
  wait_for_jobs = false

  set = [
    { name = "democratic-csi.driver.config.httpConnection.host"
    value = var.truenas_server },
    { name = "democratic-csi.driver.config.httpConnection.apiKey"
    value = var.truenas_api_key },
    { name = "democratic-csi.driver.config.nfs.shareHost"
    value = var.truenas_server }
  ]
}

# Wait for democratic csi to finish
resource "time_sleep" "wait_democratic_csi" {
  depends_on = [helm_release.democratic_csi]

  create_duration = "30s"
}