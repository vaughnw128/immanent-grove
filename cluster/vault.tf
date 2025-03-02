# TODO: Add vault/operator - Make auto http gateway and dns

resource "helm_release" "vault" {
  depends_on       = [time_sleep.wait_cert_manager, time_sleep.wait_democratic_csi]
  name             = "vault"
  chart            = "vault"
  namespace        = "vault"
  repository       = "https://helm.releases.hashicorp.com"
  create_namespace = true

  # Wait is false due to issues with helm provider
  wait          = false
  wait_for_jobs = false
}

# Wait for vault to finish
resource "time_sleep" "wait_vault" {
  depends_on = [helm_release.vault]

  create_duration = "30s"
}

# Deploy gateway resources to sit in front of Vault

resource "kubectl_manifest" "gateway_vault_gateway" {
  depends_on = [time_sleep.wait_vault]
  yaml_body = yamlencode({
    "apiVersion" = "gateway.networking.k8s.io/v1"
    "kind"       = "Gateway"
    "metadata" = {
      "annotations" = {
        "cert-manager.io/cluster-issuer" = "local-issuer"
      }
      "name"      = "gateway"
      "namespace" = "vault"
    }
    "spec" = {
      "gatewayClassName" = "cilium"
      "infrastructure" = {
        "annotations" = {
          "external-dns.alpha.kubernetes.io/hostname" = "vault.${var.local_domain}"
        }
      }
      "listeners" = [
        {
          "hostname" = "vault.${var.local_domain}"
          "name"     = "http"
          "port"     = 80
          "protocol" = "HTTP"
        },
        {
          "hostname" = "vault.${var.local_domain}"
          "name"     = "https"
          "port"     = 443
          "protocol" = "HTTPS"
          "tls" = {
            "certificateRefs" = [
              {
                "kind" = "Secret"
                "name" = "vault-server-tls"
              },
            ]
            "mode" = "Terminate"
          }
        },
      ]
    }
  })
}

resource "kubectl_manifest" "httproute_vault_https_route" {
  depends_on = [time_sleep.wait_vault]
  yaml_body = yamlencode({
    "apiVersion" = "gateway.networking.k8s.io/v1"
    "kind"       = "HTTPRoute"
    "metadata" = {
      "name"      = "https-route"
      "namespace" = "vault"
    }
    "spec" = {
      "hostnames" = [
        "vault.${var.local_domain}",
      ]
      "parentRefs" = [
        {
          "name" = "gateway"
        },
      ]
      "rules" = [
        {
          "backendRefs" = [
            {
              "name" = "vault"
              "port" = 8200
            },
          ]
          "matches" = [
            {
              "path" = {
                "type"  = "PathPrefix"
                "value" = "/"
              }
            },
          ]
        },
      ]
    }
  })
}

resource "kubectl_manifest" "httproute_vault_http_route_redirect" {
  depends_on = [time_sleep.wait_vault]
  yaml_body = yamlencode({
    "apiVersion" = "gateway.networking.k8s.io/v1"
    "kind"       = "HTTPRoute"
    "metadata" = {
      "name"      = "http-route-redirect"
      "namespace" = "vault"
    }
    "spec" = {
      "hostnames" = [
        "vault.${var.local_domain}",
      ]
      "parentRefs" = [
        {
          "name"        = "gateway"
          "namespace"   = "vault"
          "sectionName" = "http"
        },
      ]
      "rules" = [
        {
          "filters" = [
            {
              "requestRedirect" = {
                "scheme"     = "https"
                "statusCode" = 301
              }
              "type" = "RequestRedirect"
            },
          ]
        },
      ]
    }
  })
}

resource "helm_release" "vault_secrets_operator" {
  depends_on       = [time_sleep.wait_vault]
  name             = "vault-secrets-operator"
  chart            = "vault-secrets-operator"
  namespace        = "vault-secrets-operator-system"
  repository       = "https://helm.releases.hashicorp.com"
  create_namespace = true

  # Wait is false due to issues with helm provider
  wait          = false
  wait_for_jobs = false

  set = [
    {
      name = "defaultVaultConnection.enabled"
      value = "true"
    },
    {
      name = "defaultVaultConnection.address"
      value = "http://vault.vault.svc.cluster.local:8200"
    },
    {
      name = "defaultVaultConnection.skipTLSVerify"
      value = "true"
    }
  ]
}

