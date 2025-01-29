
# Pull docs with Kustomize

data "kubectl_kustomize_documents" "cloudflare_operator" {
  target = "https://github.com/adyanth/cloudflare-operator/config/default"
}

# resource "kubectl_manifest" "cloudflare_operator_namespace" {
#   depends_on = [ data.talos_cluster_health.bootstrap_health ]
#   yaml_body = yamlencode({
#     "apiVersion" = "v1"
#     "kind" = "Namespace"
#     "metadata" = {
#       "name"      = "cloudflare-operator-system"
#     }
#   })
# }

# Apply each Kustomize document
resource "kubectl_manifest" "cloudflare_operator" {
  depends_on       = [kubectl_manifest.clusterissuer_cloudflare_issuer]
  count            = length(data.kubectl_kustomize_documents.cloudflare_operator.documents)
  yaml_body        = element(data.kubectl_kustomize_documents.cloudflare_operator.documents, count.index)
  sensitive_fields = ["spec"] # Marked sensetive to reduce noise in plan logs
}

resource "kubectl_manifest" "cloudflare_operator_secrets" {
  depends_on       = [kubectl_manifest.cloudflare_operator]
  sensitive_fields = ["data"]
  yaml_body = yamlencode({
    "apiVersion" = "v1"
    "data" = {
      "CLOUDFLARE_API_TOKEN" = base64encode(var.cloudflare_token)
      "CLOUDFLARE_API_KEY"   = base64encode(var.cloudflare_api_key)
    }
    "kind" = "Secret"
    "metadata" = {
      "name"      = "cloudflare-secrets"
      "namespace" = "cloudflare-operator-system"
    }
    "type" = "Opaque"
  })
}

# Finally initialize the tunnel. Two tunnels and one operator are created.
resource "kubectl_manifest" "cluster_tunnel" {
  depends_on = [kubectl_manifest.cloudflare_operator, kubectl_manifest.cloudflare_operator_secrets]
  yaml_body = yamlencode({
    "apiVersion" = "networking.cfargotunnel.com/v1alpha1"
    "kind"       = "ClusterTunnel"
    "metadata" = {
      "name"      = "cluster-tunnel"
      "namespace" = "cloudflare-operator-system"
    }
    "spec" = {
      "cloudflare" = {
        "accountId" = var.cloudflare_account_id
        "domain"    = var.public_domain
        "email"     = var.tls_email
        "secret"    = "cloudflare-secrets"
      }
      "noTlsVerify" = false
      "protocol"    = "auto"
      "newTunnel" = {
        "name" = var.name
      }
      "image" = "cloudflare/cloudflared:2025.1.0" # TODO: Make this variable, or auto-read the latest release
      "size"  = 2
    }
  })
}