# Portainer for some easy viewing of resources. This expects that you have a pre-existing portainer installation

data "http" "portainer_manifest_file" {
  url = "https://downloads.portainer.io/ce2-22/portainer-agent-k8s-lb.yaml"
}

# Apply portainer - Then access cluster via the UI supplying URL to load balanced IP
resource "kubectl_manifest" "portainer" {
  depends_on       = [kubectl_manifest.ciliumloadbalancerippool_kube_system_external]
  for_each         = var.portainer ? toset(split("---", data.http.portainer_manifest_file.response_body)) : set()
  yaml_body        = each.value
  sensitive_fields = ["spec"]
}