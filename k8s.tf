## Providers

provider "kubernetes" {
  config_path = "./src/kube-creds/kube.config"
}

provider "kubernetes-alpha" {
  alias       = "alpha"
  config_path = "./src/kube-creds/kube.config"
}

provider "helm" {
  kubernetes {
    config_path = "./src/kube-creds/kube.config"
  }
}

## Namespaces

resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
  depends_on = [time_sleep.wait]
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
  depends_on = [time_sleep.wait]
}

resource "kubernetes_namespace" "mongodb" {
  metadata {
    name = "mongodb"
  }
  depends_on = [time_sleep.wait]
}

resource "kubernetes_namespace" "mario" {
  metadata {
    name = "mario"
  }
  depends_on = [time_sleep.wait]
}

resource "kubernetes_namespace" "nginx" {
  metadata {
    name = "nginx"
  }
  depends_on = [time_sleep.wait]
}

## Services

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.5.1"
  namespace  = kubernetes_namespace.cert_manager.id

  values = [
    file("./src/cert-manager-values.yml")
  ]
  depends_on = [time_sleep.wait, kubernetes_namespace.cert_manager]
}

resource "kubernetes_manifest" "cluster_issuer" {
  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "ClusterIssuer"
    "metadata" = {
      "name" = "letsencrypt"
    }
    "spec" = {
      "acme" = {
        "email"  = "mousheghamirbekyan@gmail.com"
        "server" = "https://acme-v02.api.letsencrypt.org/directory"
        "privateKeySecretRef" = {
          "name" = "letsencrypt-account-key"
        }
        "solvers" = [
          {
            "http01" = {
              "ingress" = {
                "class" = "nginx"
              }
            }
          },
        ]
      }
    }
  }
  depends_on = [helm_release.cert_manager]
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "30.1.0"
  namespace  = kubernetes_namespace.monitoring.id

  values = [
    file("./src/prometheus-stack-values.yml")
  ]

  depends_on = [helm_release.cert_manager, kubernetes_namespace.monitoring]
}
# https://github.com/prometheus-operator/kube-prometheus.git

resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  # version    = "4.0.13"
  namespace = kubernetes_namespace.nginx.id

  # values = [
  #   file("./src/ingress-nginx-values.yml")
  # ]

  set {
    name  = "controller.service.type"
    value = "NodePort"
  }

  set {
    name  = "controller.service.nodePorts.http"
    value = "32080"
  }

  set {
    name  = "controller.service.nodePorts.https"
    value = "32443"
  }

  depends_on = [helm_release.cert_manager, kubernetes_namespace.nginx]
}

resource "kubernetes_ingress_v1" "ingress_mon" {
  metadata {
    name      = "ingress-mon"
    namespace = kubernetes_namespace.monitoring.id
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt"
      "kubernetes.io/ingress.class"    = "nginx"
    }
  }
  spec {
    tls {
      hosts = [
        "mon.devopschallenge.amirbekyan.com"
      ]
      secret_name = "devopschallenge"
    }
    rule {
      host = "mon.devopschallenge.amirbekyan.com"
      http {
        path {
          path = "/"
          backend {
            service {
              name = "prometheus-grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
  depends_on = [helm_release.ingress_nginx]
}

resource "helm_release" "mongodb" {
  name       = "mongodb"
  repository = "https://mongodb.github.io/helm-charts"
  chart      = "community-operator"
  namespace  = kubernetes_namespace.mongodb.id

  values = [
    file("./src/mongodb-community-operator-values.yml")
  ]
  depends_on = [helm_release.cert_manager, kubernetes_namespace.mongodb]
}

resource "kubernetes_manifest" "mongo_cluster" {
  manifest = {
    "apiVersion" = "mongodbcommunity.mongodb.com/v1"
    "kind"       = "MongoDBCommunity"
    "metadata" = {
      "name"      = "mongodb-replica-set"
      "namespace" = kubernetes_namespace.mongodb.id
    }
    "spec" = {
      "type"    = "ReplicaSet"
      "members" = "2"
      "version" = "4.4.0"
      "security" = {
        "authentication" = {
          "ignoreUnknownUsers" = "true"
          "modes"              = ["SCRAM"]
        }
        "tls" = {
          "enabled" = "true"
          "certificateKeySecretRef" = {
            "name" = "tls-certificate"
          }
          "caCertificateSecretRef" = {
            "name" = "tls-ca-key-pair"
          }
        }
      }
      "users" = []
      "statefulSet" = {
        "spec" = {
          "voluemClaimTemplates" = {
            "metadata" = {
              "name" = "mongo-pvc"
            }
            "spec" = {
              "accessModes" = ["ReadWriteOnce", "ReadWriteMany"]
              "resources" = {
                "requests" = {
                  "storage" = "10Gi"
                }
              }
            }
          }
        }
      }
    }
  }
  depends_on = [helm_release.mongodb, kubernetes_namespace.cert_manager]
}

## Main App

resource "kubernetes_deployment" "mario" {
  metadata {
    name      = "mario"
    namespace = kubernetes_namespace.mario.id
    labels = {
      app     = "mario"
      release = "prometheus"
    }
  }
  spec {
    selector {
      match_labels = {
        app = "mario"
      }
    }
    replicas          = 1
    min_ready_seconds = 5
    template {
      metadata {
        labels = {
          app     = "mario"
          release = "prometheus"
        }
      }
      spec {
        container {
          image             = "pengbai/docker-supermario"
          image_pull_policy = "IfNotPresent"
          name              = "mario"
          port {
            container_port = 8080
          }
          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
          }
        }
        termination_grace_period_seconds = 1
      }
    }
    strategy {
      rolling_update {
        max_surge       = 1
        max_unavailable = 0
      }
      type = "RollingUpdate"
    }
  }
  depends_on = [kubernetes_namespace.mario]
}

resource "kubernetes_service" "mario" {
  metadata {
    name      = "mario"
    namespace = kubernetes_namespace.mario.id
    labels = {
      app     = "mario"
      release = "prometheus"
    }
  }
  spec {
    selector = {
      app = "mario"
    }
    session_affinity = "ClientIP"
    port {
      port        = 80
      target_port = 8080
    }
    type = "ClusterIP"
  }
  depends_on = [kubernetes_namespace.mario]
}

resource "kubernetes_ingress_v1" "ingress_mario" {
  metadata {
    name      = "ingress-mario"
    namespace = kubernetes_namespace.mario.id
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt"
      "kubernetes.io/ingress.class"    = "nginx"
    }
  }
  spec {
    tls {
      hosts = [
        "devopschallenge.amirbekyan.com",
      ]
      secret_name = "devopschallenge"
    }
    rule {
      host = "devopschallenge.amirbekyan.com"
      http {
        path {
          path = "/"
          backend {
            service {
              name = "mario"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
  depends_on = [helm_release.ingress_nginx]
}

resource "kubernetes_manifest" "mario_monitor" {
  manifest = {
    "apiVersion" = "monitoring.coreos.com/v1"
    "kind"       = "ServiceMonitor"
    "metadata" = {
      "name"      = "mario-monitor"
      "namespace" = "mario"
      "labels" = {
        "release" = "prometheus"
      }
    }
    "spec" = {
      "jobLabel" = "mario-monitor"
      "selector" = {
        "matchLabels" = {
          "app" = "mario"
        }
      }
      "namespaceSelector" = {
        "matchNames" = [
          "mario"
        ]
      }
      "endpoints" = [{
        "port"     = "http-metrics"
        "interval" = "15s"
      }]
    }
  }
  depends_on = [helm_release.prometheus, kubernetes_deployment.mario]
}
