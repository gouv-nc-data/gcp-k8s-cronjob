# Module Terraform - GKE CronJob

Module pour déployer des CronJobs sur GKE avec Workload Identity.

## Usage

```hcl
resource "kubernetes_namespace" "dir_jobs" {
  metadata {
    name = "${local.dir_name}-jobs"
    labels = {
      name      = "${local.dir_name}-jobs"
      managedBy = "terraform"
    }
  }
}


module "my_cronjob" {
  source = "git::https://github.com/gouv-nc-data/gcp-k8s-cronjob.git?ref=v1"
  
  namespace = kubernetes_namespace.dir_jobs.metadata[0].name
  name      = "my-cronjob"
  schedule  = "0 3 * * *"
  image     = "gcr.io/project/image:latest"
  project_id = module.dir-datawarehouse.project_id
  
  gcp_service_account_roles = [
    "roles/bigquery.dataEditor",
    "roles/bigquery.jobUser"
  ]
  secrets_env_vars = {
    ENV_VAR_NAME = "secret_name"
  }
  env_vars = {
    ENV_VAR_NAME = "value"
  }
}
```
<!-- BEGIN_TF_DOCS -->
## Inputs

| Nom | Description | Type | Défaut | Requis |
|-----|-------------|------|--------|--------|
| namespace | Namespace Kubernetes | string | - | oui |
| name | Nom du CronJob | string | - | oui |
| schedule | Schedule cron | string | - | oui |
| image | Image Docker | string | - | oui |
| service_account_email | Email SA GCP | string | - | oui |
| env_vars | Variables d'environnement | map(string) | {} | non |
| env_from_secret | Variables depuis K8s Secret | map(object) | {} | non |
| resources_requests | Ressources demandées | object | {memory="512Mi", cpu="500m"} | non |
| resources_limits | Limites ressources | object | {memory="1Gi", cpu="1000m"} | non |
| active_deadline_seconds | Timeout | number | 3600 | non |
| backoff_limit | Tentatives | number | 2 | non |

## Outputs

| Nom | Description |
|-----|-------------|
| cronjob_name | Nom du CronJob |
| service_account_name | Nom du SA K8s |
| schedule | Schedule |
| namespace | Namespace |

<!-- END_TF_DOCS -->