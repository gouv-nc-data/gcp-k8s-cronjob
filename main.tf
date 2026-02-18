
# Module IAM (SA GCP + K8s + Workload Identity)
module "iam" {
  source = "git::https://github.com/gouv-nc-data/gcp-k8s-iam.git//?ref=v1"

  name                   = var.name
  namespace              = var.namespace
  project_id             = var.project_id
  gke_project_id         = var.gke_project_id
  gcp_roles              = var.create_service_account ? var.gcp_service_account_roles : []
  secret_project_id      = var.secret_project_id
  secrets                = var.create_service_account ? var.secrets_env_vars : {}
  display_name           = "Service Account for ${var.name} CronJob"
  create_service_account = var.create_service_account
}

locals {
  secret_project = var.secret_project_id != "" ? var.secret_project_id : var.project_id
}

# CronJob
resource "kubernetes_cron_job_v1" "cronjob" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }

  # S'assure que toutes les permissions IAM sont appliquées avant de créer le CronJob
  depends_on = [
    kubernetes_service_account.cronjob_sa,
    google_secret_manager_secret_iam_member.secret_access,
    google_service_account_iam_member.workload_identity
  ]

  spec {
    schedule                      = var.schedule
    concurrency_policy            = "Forbid"
    successful_jobs_history_limit = 3
    failed_jobs_history_limit     = 3
    timezone                      = var.job_timezone

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
            service_account_name = module.iam.k8s_service_account_name
            restart_policy       = "OnFailure"

            container {
              name              = var.name
              image             = var.image_url
              image_pull_policy = "Always"

              # Injection automatique du Project ID
              dynamic "env" {
                for_each = var.project_id != null ? [1] : []
                content {
                  name  = "GOOGLE_CLOUD_PROJECT"
                  value = var.project_id
                }
              }

              # Variables d'environnement simples
              dynamic "env" {
                for_each = var.env_vars
                content {
                  name  = env.key
                  value = env.value
                }
              }

              # Variables d'environnement pointant vers des secrets GCP (Path)
              dynamic "env" {
                for_each = var.secrets_env_vars
                content {
                  name  = env.key
                  value = "projects/${local.secret_project}/secrets/${env.value}/versions/latest"
                }
              }

              # Variables depuis secrets K8s
              dynamic "env" {
                for_each = var.env_from_k8s_secret
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
                  memory            = var.resources_requests.memory
                  cpu               = var.resources_requests.cpu
                  ephemeral-storage = var.resources_requests.ephemeral-storage
                }
                limits = {
                  memory            = var.resources_limits.memory
                  cpu               = var.resources_limits.cpu
                  ephemeral-storage = var.resources_limits.ephemeral-storage
                }
              }
            }
          }
        }
      }
    }
  }
}

# ─────────────────────────────────────────────
# Blocs moved pour la migration du state
# ─────────────────────────────────────────────
moved {
  from = google_service_account.job_sa[0]
  to   = module.iam.google_service_account.sa[0]
}

moved {
  from = google_project_iam_member.sa_roles
  to   = module.iam.google_project_iam_member.roles
}

moved {
  from = google_secret_manager_secret_iam_member.secret_access
  to   = module.iam.google_secret_manager_secret_iam_member.secret_access
}

moved {
  from = google_service_account_iam_member.workload_identity[0]
  to   = module.iam.google_service_account_iam_member.workload_identity
}

moved {
  from = kubernetes_service_account.cronjob_sa
  to   = module.iam.kubernetes_service_account.sa
}
