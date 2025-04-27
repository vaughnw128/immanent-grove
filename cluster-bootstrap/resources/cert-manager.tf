# Deploy the cert-manager chart with gateway api enabled
# This release also waits for the cluster to be bootstrapped

resource "helm_release" "cert_manager" {
  depends_on       = [data.talos_cluster_health.bootstrap_health]
  name             = "cert-manager"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  repository       = "https://charts.jetstack.io"
  create_namespace = true

  # Set values
  set = [{
    name  = "extraArgs"
    value = "{--enable-gateway-api}" # Needed for Cilium Gateway
    }
    , {
      name  = "installCRDs"
      value = "true"
  }]

  # Wait is false due to issues with helm provider
  wait          = false
  wait_for_jobs = false
}

# Wait for cert manager to finish
resource "time_sleep" "wait_cert_manager" {
  depends_on = [helm_release.cert_manager]

  create_duration = "30s"
}

# Reflector is needed for the duplication of all clusterissuer required secrets (cloudflare token) to all namespaces

resource "helm_release" "reflector" {
  depends_on       = [data.talos_cluster_health.bootstrap_health]
  name             = "reflector"
  namespace        = "reflector"
  chart            = "reflector"
  repository       = "https://emberstack.github.io/helm-charts"
  create_namespace = true

  # Wait is false due to issues with helm tf
  wait = false
}

# Secrets are reflected over ALL kubernetes namespaces.
resource "kubectl_manifest" "secret_cloudflare_api_token_secret" {
  depends_on       = [helm_release.reflector]
  sensitive_fields = ["spec"]
  yaml_body = yamlencode({
    "apiVersion" = "v1"
    "data" = {
      "api-token" = base64encode(var.cloudflare_token)
    }
    "kind" = "Secret"
    "metadata" = {
      "annotations" = {
        "reflector.v1.k8s.emberstack.com/reflection-allowed"            = "true"
        "reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces" = ""
        "reflector.v1.k8s.emberstack.com/reflection-auto-enabled"       = "true"
        "reflector.v1.k8s.emberstack.com/reflection-auto-namespaces"    = ""
      }
      "name"      = "cloudflare-token"
      "namespace" = "cert-manager"
    }
    "type" = "Opaque"
  })
}

# Cluster issuer for cloudflare / letsencrypt / dns01 to generate public TLS certs
resource "kubectl_manifest" "clusterissuer_cloudflare_issuer" {
  depends_on       = [helm_release.reflector, kubectl_manifest.secret_cloudflare_api_token_secret, helm_release.cert_manager, time_sleep.wait_cert_manager]
  sensitive_fields = ["spec"]
  yaml_body = yamlencode({
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "ClusterIssuer"
    "metadata" = {
      "name"      = "cloudflare-issuer"
      "namespace" = "cert-manager"
    }
    "spec" = {
      "acme" = {
        "email" = var.tls_email
        "privateKeySecretRef" = {
          "name" = "cloudflare-private-key"
        }
        "server" = "https://acme-v02.api.letsencrypt.org/directory"
        "solvers" = [
          {
            "dns01" = {
              "cloudflare" = {
                "apiTokenSecretRef" = {
                  "key"  = "api-token"
                  "name" = "cloudflare-token"
                }
              }
            }
          },
        ]
      }
    }
  })
}

resource "kubectl_manifest" "certificate_cert_manager_apicius_local_ca" {
  depends_on = [helm_release.reflector, kubectl_manifest.secret_cloudflare_api_token_secret, helm_release.cert_manager, time_sleep.wait_cert_manager]
  yaml_body = yamlencode({
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "Certificate"
    "metadata" = {
      "annotations" = {
        "reflector.v1.k8s.emberstack.com/reflection-allowed"            = "true"
        "reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces" = ""
        "reflector.v1.k8s.emberstack.com/reflection-auto-enabled"       = "true"
        "reflector.v1.k8s.emberstack.com/reflection-auto-namespaces"    = ""
      }
      "name"      = "${replace(var.local_domain, ".", "-")}-ca"
      "namespace" = "cert-manager"
    }
    "spec" = {
      "commonName" = var.local_domain
      "isCA"       = true
      "issuerRef" = {
        "group" = "cert-manager.io"
        "kind"  = "ClusterIssuer"
        "name"  = "local-self-signed-issuer"
      }
      "privateKey" = {
        "algorithm" = "ECDSA"
        "size"      = 256
      }
      "secretName" = replace(var.local_domain, ".", "-")
    }
  })
}

resource "kubectl_manifest" "clusterissuer_cert_manager_local_self_signed_issuer" {
  depends_on = [helm_release.reflector, kubectl_manifest.secret_cloudflare_api_token_secret, helm_release.cert_manager, time_sleep.wait_cert_manager]
  yaml_body = yamlencode({
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "ClusterIssuer"
    "metadata" = {
      "name"      = "local-self-signed-issuer"
      "namespace" = "cert-manager"
    }
    "spec" = {
      "selfSigned" = {}
    }
  })
}

resource "kubectl_manifest" "clusterissuer_cert_manager_local_issuer" {
  depends_on = [helm_release.reflector, kubectl_manifest.secret_cloudflare_api_token_secret, helm_release.cert_manager, time_sleep.wait_cert_manager]
  yaml_body = yamlencode({
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "ClusterIssuer"
    "metadata" = {
      "name"      = "local-issuer"
      "namespace" = "cert-manager"
    }
    "spec" = {
      "ca" = {
        "secretName" = replace(var.local_domain, ".", "-")
      }
    }
  })
}

