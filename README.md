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
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | n/a |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_project_iam_member.sa_roles](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_secret_manager_secret_iam_member.secret_access](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_member) | resource |
| [google_service_account.job_sa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_member.workload_identity](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |
| [kubernetes_cron_job_v1.cronjob](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cron_job_v1) | resource |
| [kubernetes_service_account.cronjob_sa](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_active_deadline_seconds"></a> [active\_deadline\_seconds](#input\_active\_deadline\_seconds) | Délai maximum d'exécution en secondes | `number` | `3600` | no |
| <a name="input_backoff_limit"></a> [backoff\_limit](#input\_backoff\_limit) | Nombre de tentatives en cas d'échec | `number` | `2` | no |
| <a name="input_create_service_account"></a> [create\_service\_account](#input\_create\_service\_account) | Créer un Service Account GCP dédié pour ce job | `bool` | `true` | no |
| <a name="input_env_from_k8s_secret"></a> [env\_from\_k8s\_secret](#input\_env\_from\_k8s\_secret) | Variables d'environnement injectées depuis des Secrets Kubernetes (et non GCP) | <pre>map(object({<br/>    secret_name = string<br/>    key         = string<br/>  }))</pre> | `{}` | no |
| <a name="input_env_vars"></a> [env\_vars](#input\_env\_vars) | Variables d'environnement | `map(string)` | `{}` | no |
| <a name="input_gcp_service_account_roles"></a> [gcp\_service\_account\_roles](#input\_gcp\_service\_account\_roles) | Liste des rôles IAM à attribuer au Service Account sur le projet | `list(string)` | `[]` | no |
| <a name="input_gke_project_id"></a> [gke\_project\_id](#input\_gke\_project\_id) | ID du projet GCP hébergeant le cluster GKE (pour Workload Identity) | `string` | `"prj-dinum-gke-f8f8"` | no |
| <a name="input_image_gcp_project"></a> [image\_gcp\_project](#input\_image\_gcp\_project) | Projet GCP où se trouve l'image Docker (pour permissions de pull) | `string` | `"prj-dinum-data-templates-66aa"` | no |
| <a name="input_image_url"></a> [image\_url](#input\_image\_url) | url de l'image Docker à utiliser | `string` | n/a | yes |
| <a name="input_job_timezone"></a> [job\_timezone](#input\_job\_timezone) | Timezone for the CronJob schedule (e.g., 'Pacific/Noumea') | `string` | `"Pacific/Noumea"` | no |
| <a name="input_name"></a> [name](#input\_name) | Nom du CronJob | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace Kubernetes | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | ID du projet GCP où créer le Service Account et les ressources | `string` | `null` | no |
| <a name="input_resources_limits"></a> [resources\_limits](#input\_resources\_limits) | Limites de ressources | <pre>object({<br/>    memory            = string<br/>    cpu               = string<br/>    ephemeral-storage = optional(string, "2Gi")<br/>  })</pre> | <pre>{<br/>  "cpu": "1000m",<br/>  "ephemeral-storage": "2Gi",<br/>  "memory": "2Gi"<br/>}</pre> | no |
| <a name="input_resources_requests"></a> [resources\_requests](#input\_resources\_requests) | Ressources demandées | <pre>object({<br/>    memory            = string<br/>    cpu               = string<br/>    ephemeral-storage = optional(string, "1Gi")<br/>  })</pre> | <pre>{<br/>  "cpu": "500m",<br/>  "ephemeral-storage": "1Gi",<br/>  "memory": "512Mi"<br/>}</pre> | no |
| <a name="input_schedule"></a> [schedule](#input\_schedule) | Schedule cron (ex: '15 4 * * 1' pour lundi à 04:15) | `string` | n/a | yes |
| <a name="input_secret_project_id"></a> [secret\_project\_id](#input\_secret\_project\_id) | ID du projet contenant les secrets | `string` | `"prj-dinum-p-secret-mgnt-aaf4"` | no |
| <a name="input_secrets_env_vars"></a> [secrets\_env\_vars](#input\_secrets\_env\_vars) | Map de variables d'environnement pointant vers des secrets GCP. Clé = Nom de la variable d'env, Valeur = ID du secret (sans projects/...) | `map(string)` | `{}` | no |
| <a name="input_service_account_email"></a> [service\_account\_email](#input\_service\_account\_email) | Email du service account GCP (optionnel si create\_service\_account = true) | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cronjob_name"></a> [cronjob\_name](#output\_cronjob\_name) | Nom du CronJob créé |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Namespace du CronJob |
| <a name="output_schedule"></a> [schedule](#output\_schedule) | Schedule du CronJob |
| <a name="output_service_account_name"></a> [service\_account\_name](#output\_service\_account\_name) | Nom du Service Account Kubernetes |
<!-- END_TF_DOCS -->