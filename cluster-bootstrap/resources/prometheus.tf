data "http" "prometheus_manifest_file" {
    url = "https://raw.githubusercontent.com/cilium/cilium/1.16.6/examples/kubernetes/addons/prometheus/monitoring-example.yaml"
  }

  # Apply portainer - Then access cluster via the UI supplying URL to load balanced IP
  resource "kubectl_manifest" "prometheus" {
    depends_on       = [time_sleep.wait_cilium]
    for_each = setsubtract(toset(split("---", data.http.prometheus_manifest_file.response_body)), [""])
    yaml_body        = each.value
  }
#
#   resource "kubectl_manifest" "prometheus_cluster_ip" {
#     depends_on = [kubectl_manifest.prometheus, kubectl_manifest.certificate_cert_manager_apicius_local_ca]
#     yaml_body = yamlencode({
#       "apiVersion" = "v1",
#       "kind" = "Service",
#       "metadata" = {
#         "name" = "prometheus"
#         "namespace" = "cilium-monitoring"
#       }
#       "spec" = {
#         "selector" = {
#           "app" = "prometheus"
#         }
#         "ports" = [
#           {
#             "protocol"=  "TCP"
#             "port"= 9090
#             "targetPort" = 9090
#           }]
#           "type" = "ClusterIP"
#         }})
#       }
#
  resource "kubectl_manifest" "gateway_prometheus_gateway" {
    depends_on = [kubectl_manifest.prometheus, kubectl_manifest.certificate_cert_manager_apicius_local_ca]
    yaml_body = yamlencode({
      "apiVersion" = "gateway.networking.k8s.io/v1"
      "kind"       = "Gateway"
      "metadata" = {
        "annotations" = {
          "cert-manager.io/cluster-issuer" = "local-issuer"
        }
        "name"      = "prometheus-gateway"
        "namespace" = "cilium-monitoring"
      }
      "spec" = {
        "gatewayClassName" = "cilium"
        "infrastructure" = {
          "annotations" = {
            "external-dns.alpha.kubernetes.io/hostname" = "prometheus.${var.local_domain}"
          }
        }
        "listeners" = [
          {
            "hostname" = "prometheus.${var.local_domain}"
            "name"     = "http"
            "port"     = 80
            "protocol" = "HTTP"
          },
          {
            "hostname" = "prometheus.${var.local_domain}"
            "name"     = "https"
            "port"     = 443
            "protocol" = "HTTPS"
            "tls" = {
              "certificateRefs" = [
                {
                  "kind" = "Secret"
                  "name" = "prometheus-server-tls"
                },
              ]
              "mode" = "Terminate"
            }
          },
        ]
      }
    })
  }

  resource "kubectl_manifest" "httproute_prometheus_https_route" {
    depends_on = [kubectl_manifest.prometheus, kubectl_manifest.certificate_cert_manager_apicius_local_ca]
    yaml_body = yamlencode({
      "apiVersion" = "gateway.networking.k8s.io/v1"
      "kind"       = "HTTPRoute"
      "metadata" = {
        "name"      = "prometheus-https-route"
        "namespace" = "cilium-monitoring"
      }
      "spec" = {
        "hostnames" = [
          "prometheus.${var.local_domain}",
        ]
        "parentRefs" = [
          {
            "name" = "prometheus-gateway"
          },
        ]
        "rules" = [
          {
            "backendRefs" = [
              {
                "name" = "prometheus"
                "port" = 9090
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

  resource "kubectl_manifest" "httproute_prometheus_http_route_redirect" {
    depends_on = [kubectl_manifest.prometheus, kubectl_manifest.certificate_cert_manager_apicius_local_ca]
    yaml_body = yamlencode({
      "apiVersion" = "gateway.networking.k8s.io/v1"
      "kind"       = "HTTPRoute"
      "metadata" = {
        "name"      = "prometheus-http-route-redirect"
        "namespace" = "cilium-monitoring"
      }
      "spec" = {
        "hostnames" = [
          "prometheus.${var.local_domain}",
        ]
        "parentRefs" = [
          {
            "name"        = "prometheus-gateway"
            "namespace"   = "cilium-monitoring"
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
#
#   resource "kubectl_manifest" "grafana_cluster_ip" {
#     depends_on = [kubectl_manifest.prometheus, kubectl_manifest.certificate_cert_manager_apicius_local_ca]
#     yaml_body = yamlencode({
#       "apiVersion" = "v1",
#       "kind" = "Service",
#       "metadata" = {
#         "name" = "grafana"
#         "namespace" = "cilium-monitoring"
#       }
#       "spec" = {
#         "selector" = {
#           "app" = "grafana"
#         }
#         "ports" = [
#           {
#             "protocol"=  "TCP"
#             "port"= 3000
#             "targetPort" = 3000
#           }]
#           "type" = "ClusterIP"
#         }})
#       }
#
  resource "kubectl_manifest" "gateway_grafana_gateway" {
    depends_on = [kubectl_manifest.prometheus, kubectl_manifest.certificate_cert_manager_apicius_local_ca]
    yaml_body = yamlencode({
      "apiVersion" = "gateway.networking.k8s.io/v1"
      "kind"       = "Gateway"
      "metadata" = {
        "annotations" = {
          "cert-manager.io/cluster-issuer" = "local-issuer"
        }
        "name"      = "grafana-gateway"
        "namespace" = "cilium-monitoring"
      }
      "spec" = {
        "gatewayClassName" = "cilium"
        "infrastructure" = {
          "annotations" = {
            "external-dns.alpha.kubernetes.io/hostname" = "grafana.${var.local_domain}"
          }
        }
        "listeners" = [
          {
            "hostname" = "grafana.${var.local_domain}"
            "name"     = "http"
            "port"     = 80
            "protocol" = "HTTP"
          },
          {
            "hostname" = "grafana.${var.local_domain}"
            "name"     = "https"
            "port"     = 443
            "protocol" = "HTTPS"
            "tls" = {
              "certificateRefs" = [
                {
                  "kind" = "Secret"
                  "name" = "grafana-server-tls"
                },
              ]
              "mode" = "Terminate"
            }
          },
        ]
      }
    })
  }

  resource "kubectl_manifest" "httproute_grafana_https_route" {
    depends_on = [kubectl_manifest.prometheus, kubectl_manifest.certificate_cert_manager_apicius_local_ca]
    yaml_body = yamlencode({
      "apiVersion" = "gateway.networking.k8s.io/v1"
      "kind"       = "HTTPRoute"
      "metadata" = {
        "name"      = "grafana-https-route"
        "namespace" = "cilium-monitoring"
      }
      "spec" = {
        "hostnames" = [
          "grafana.${var.local_domain}",
        ]
        "parentRefs" = [
          {
            "name" = "grafana-gateway"
          },
        ]
        "rules" = [
          {
            "backendRefs" = [
              {
                "name" = "grafana"
                "port" = 3000
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

  resource "kubectl_manifest" "httproute_grafana_http_route_redirect" {
    depends_on = [kubectl_manifest.prometheus, kubectl_manifest.certificate_cert_manager_apicius_local_ca]
    yaml_body = yamlencode({
      "apiVersion" = "gateway.networking.k8s.io/v1"
      "kind"       = "HTTPRoute"
      "metadata" = {
        "name"      = "grafana-http-route-redirect"
        "namespace" = "cilium-monitoring"
      }
      "spec" = {
        "hostnames" = [
          "grafana.${var.local_domain}",
        ]
        "parentRefs" = [
          {
            "name"        = "grafana-gateway"
            "namespace"   = "cilium-monitoring"
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