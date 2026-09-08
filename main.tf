
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
  # Nom du bucket (doit être unique globalement)
  staging_bucket_name = "dlt-staging-${var.name}-${var.project_id}"
}

# CronJob
resource "kubernetes_cron_job_v1" "cronjob" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }

  # S'assure que toutes les permissions IAM sont appliquées avant de créer le CronJob
  depends_on = [
    module.iam
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

        # Décide si l'échec d'un pod compte dans `backoff_limit`.
        # Usage principal : `Ignore` sur la condition `DisruptionTarget` pour
        # qu'une préemption/éviction GKE ne fasse pas échouer le Job, tout en
        # gardant le fail-fast sur les erreurs applicatives.
        dynamic "pod_failure_policy" {
          for_each = length(var.pod_failure_policy_rules) > 0 ? [1] : []
          content {
            dynamic "rule" {
              for_each = var.pod_failure_policy_rules
              content {
                action = rule.value.action

                dynamic "on_pod_condition" {
                  for_each = rule.value.on_pod_condition
                  content {
                    type   = on_pod_condition.value.type
                    status = on_pod_condition.value.status
                  }
                }

                dynamic "on_exit_codes" {
                  for_each = rule.value.on_exit_codes == null ? [] : [rule.value.on_exit_codes]
                  content {
                    container_name = on_exit_codes.value.container_name
                    operator       = on_exit_codes.value.operator
                    values         = on_exit_codes.value.values
                  }
                }
              }
            }
          }
        }

        template {
          metadata {
            labels = {
              app = var.name
            }
            annotations = var.is_spot ? {} : {
              "cluster-autoscaler.kubernetes.io/safe-to-evict" = "false"
            }
          }

          spec {
            service_account_name = module.iam.k8s_service_account_name
            restart_policy       = var.restart_policy

            node_selector = var.is_spot ? {
              "cloud.google.com/gke-spot" = "true"
            } : null

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

              # Injection automatique du bucket de staging (DLT)
              dynamic "env" {
                for_each = var.create_staging_bucket ? [1] : []
                content {
                  name  = "BUCKET_URL"
                  value = "gs://${local.staging_bucket_name}"
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

# Ressources pour le staging GCS (optionnel)
resource "google_storage_bucket" "staging" {
  count    = var.create_staging_bucket ? 1 : 0
  project  = var.project_id
  name     = local.staging_bucket_name
  location = var.staging_bucket_location

  force_destroy               = true
  uniform_bucket_level_access = true

  public_access_prevention = "enforced"
}

resource "google_storage_bucket_iam_member" "staging_access" {
  count  = var.create_staging_bucket ? 1 : 0
  bucket = google_storage_bucket.staging[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${module.iam.gcp_service_account_email}"
}

# objectAdmin ne contient aucune permission storage.buckets.*, or les clients GCS
# (dlt via gcsfs, par exemple) vérifient l'existence du bucket avant d'écrire.
# Privé de storage.buckets.get, GCS répond 404 plutôt que 403 pour ne pas divulguer
# l'existence du bucket, et le client conclut à tort que le bucket est absent.
# legacyBucketReader apporte ce storage.buckets.get.
resource "google_storage_bucket_iam_member" "staging_bucket_get" {
  count  = var.create_staging_bucket ? 1 : 0
  bucket = google_storage_bucket.staging[0].name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${module.iam.gcp_service_account_email}"
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

# Pas de bloc `moved` pour le ServiceAccount Kubernetes : la v1 utilisait
# `kubernetes_service_account`, le sous-module iam utilise
# `kubernetes_service_account_v1`. Terraform refuse de déplacer un state entre
# deux types de ressources tant que le provider n'implémente pas
# MoveResourceState, ce que le provider Kubernetes ne fait pas :
#
#   Error: Move Resource State Not Supported
#   The "kubernetes_service_account_v1" resource type does not support moving
#   resource state across resource types.
#
# Le bloc présent jusqu'ici faisait donc échouer le plan de tout appelant
# migrant de v1 vers v2.x. Sans lui, le SA est détruit puis recréé à
# l'identique (même nom, même namespace, même annotation Workload Identity) :
# à appliquer hors exécution des jobs.
#
# ATTENTION lors de la migration v1 -> v2.x : l'ancien SA (type v1) et le
# nouveau (type v1 du sous-module iam) n'ont aucune dépendance entre eux et
# sont dans des modules différents, donc Terraform les traite EN PARALLÈLE.
# La création part avant la fin de la destruction et l'apply échoue sur :
#
#   Error: serviceaccounts "<nom>-sa" already exists
#
# L'ancien SA est alors bien détruit : relancer l'apply suffit, il aboutit.
# Pour l'éviter, détruire d'abord l'ancien SA dans un apply séparé
# (`terraform destroy -target=module.<nom>.kubernetes_service_account.cronjob_sa`)
# avant de basculer le ref.
#
# Pour une migration sans aucune recréation, utiliser `removed` (avec
# `lifecycle { destroy = false }`) puis `import` côté appelant.
