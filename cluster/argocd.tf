# Deploy ArgoCD behind a gateway class

# ArgoCD installed with helm-secrets plugin
# https://github.com/jkroepke/helm-secrets/wiki/ArgoCD-Integration
# https://github.com/FiloSottile/age

resource "helm_release" "argocd" {
  depends_on = [helm_release.cert_manager, time_sleep.wait_cert_manager]
  name       = "argocd"
  chart      = "${path.module}/charts/argocd"
  namespace  = "argocd"

  # Wait is false due to issues with helm 3.0.0-pre1
  wait          = false
  wait_for_jobs = false
}


# Wait for argocd to finish
resource "time_sleep" "wait_argocd" {
  depends_on = [helm_release.argocd]

  create_duration = "30s"
}

# Deploy gateway resources to sit in front of ArgoCD

resource "kubectl_manifest" "gateway_argocd_gateway" {
  depends_on = [time_sleep.wait_argocd]
  yaml_body = yamlencode({
    "apiVersion" = "gateway.networking.k8s.io/v1"
    "kind"       = "Gateway"
    "metadata" = {
      "annotations" = {
        "cert-manager.io/cluster-issuer" = "local-issuer"
      }
      "name"      = "gateway"
      "namespace" = "argocd"
    }
    "spec" = {
      "gatewayClassName" = "cilium"
      "infrastructure" = {
        "annotations" = {
          "external-dns.alpha.kubernetes.io/hostname" = "argo.${var.local_domain}"
        }
      }
      "listeners" = [
        {
          "hostname" = "argo.${var.local_domain}"
          "name"     = "http"
          "port"     = 80
          "protocol" = "HTTP"
        },
        {
          "hostname" = "argo.${var.local_domain}"
          "name"     = "https"
          "port"     = 443
          "protocol" = "HTTPS"
          "tls" = {
            "certificateRefs" = [
              {
                "kind" = "Secret"
                "name" = "argocd-server-tls"
              },
            ]
            "mode" = "Terminate"
          }
        },
      ]
    }
  })
}

resource "kubectl_manifest" "httproute_argocd_https_route" {
  depends_on = [time_sleep.wait_argocd]
  yaml_body = yamlencode({
    "apiVersion" = "gateway.networking.k8s.io/v1"
    "kind"       = "HTTPRoute"
    "metadata" = {
      "name"      = "https-route"
      "namespace" = "argocd"
    }
    "spec" = {
      "hostnames" = [
        "argo.${var.local_domain}",
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
              "name" = "argocd-server"
              "port" = 80
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

resource "kubectl_manifest" "httproute_argocd_http_route_redirect" {
  depends_on = [time_sleep.wait_argocd]
  yaml_body = yamlencode({
    "apiVersion" = "gateway.networking.k8s.io/v1"
    "kind"       = "HTTPRoute"
    "metadata" = {
      "name"      = "http-route-redirect"
      "namespace" = "argocd"
    }
    "spec" = {
      "hostnames" = [
        "argo.${var.local_domain}",
      ]
      "parentRefs" = [
        {
          "name"        = "gateway"
          "namespace"   = "argocd"
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