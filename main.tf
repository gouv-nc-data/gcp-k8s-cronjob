
# Service Account Kubernetes
resource "kubernetes_service_account" "cronjob_sa" {
  metadata {
    name      = "${var.name}-sa"
    namespace = var.namespace
    annotations = {
      "iam.gke.io/gcp-service-account" = var.service_account_email
    } 
  }
}

# CronJob
resource "kubernetes_cron_job_v1" "cronjob" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }

  spec {
    schedule                      = var.schedule
    concurrency_policy            = "Forbid"
    successful_jobs_history_limit = 3
    failed_jobs_history_limit     = 3

    job_template {
      metadata {
        labels = {
          app       = var.name
          managedBy = "terraform"
        }
      }

      spec {
        active_deadline_seconds = var.active_deadline_seconds
        backoff_limit           = var.backoff_limit

        template {
          metadata {
            labels = {
              app = var.name
            }
          }

          spec {
            service_account_name = kubernetes_service_account.cronjob_sa.metadata[0].name
            restart_policy       = "OnFailure"

            container {
              name  = var.name
              image = var.image

              # Variables d'environnement simples
              dynamic "env" {
                for_each = var.env_vars
                content {
                  name  = env.key
                  value = env.value
                }
              }

              # Variables depuis secrets
              dynamic "env" {
                for_each = var.env_from_secret
                content {
                  name = env.key
                  value_from {
                    secret_key_ref {
                      name = env.value.secret_name
                      key  = env.value.key
                    }
                  }
                }
              }

              resources {
                requests = {
                  memory = var.resources_requests.memory
                  cpu    = var.resources_requests.cpu
                }
                limits = {
                  memory = var.resources_limits.memory
                  cpu    = var.resources_limits.cpu
                }
              }
            }
          }
        }
      }
    }
  }
}
