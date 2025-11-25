
locals {
  # Utilise le SA créé ou celui fourni
  gcp_sa_email   = var.create_service_account ? google_service_account.job_sa[0].email : var.service_account_email
  secret_project = var.secret_project_id != "" ? var.secret_project_id : var.project_id
}

# Service Account GCP
resource "google_service_account" "job_sa" {
  count        = var.create_service_account ? 1 : 0
  project      = var.project_id
  account_id   = substr("${var.name}-sa", 0, 30)
  display_name = "Service Account for ${var.name} CronJob"
}

# Rôles IAM sur le projet
resource "google_project_iam_member" "sa_roles" {
  for_each = var.create_service_account ? toset(var.gcp_service_account_roles) : toset([])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${local.gcp_sa_email}"
}

# Accès aux Secrets
resource "google_secret_manager_secret_iam_member" "secret_access" {
  for_each = var.create_service_account ? toset(values(var.secrets_env_vars)) : toset([])

  project   = local.secret_project
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.gcp_sa_email}"
}

# Workload Identity binding
resource "google_service_account_iam_member" "workload_identity" {
  count = var.create_service_account ? 1 : 0

  service_account_id = google_service_account.job_sa[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.gke_project_id}.svc.id.goog[${var.namespace}/${kubernetes_service_account.cronjob_sa.metadata[0].name}]"
}

# Service Account Kubernetes
resource "kubernetes_service_account" "cronjob_sa" {
  metadata {
    name      = "${var.name}-sa"
    namespace = var.namespace
    annotations = {
      "iam.gke.io/gcp-service-account" = local.gcp_sa_email
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
            service_account_name = kubernetes_service_account.cronjob_sa.metadata[0].name
            restart_policy       = "OnFailure"

            container {
              name  = var.name
              image = var.image_url

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
