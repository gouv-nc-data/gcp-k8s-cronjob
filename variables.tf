variable "namespace" {
  description = "Namespace Kubernetes"
  type        = string
}

variable "name" {
  description = "Nom du CronJob"
  type        = string
}

variable "schedule" {
  description = "Schedule cron (ex: '15 4 * * 1' pour lundi à 04:15)"
  type        = string
}

variable "image_url" {
  description = "url de l'image Docker à utiliser"
  type        = string
}

variable "image_gcp_project" {
  description = "Projet GCP où se trouve l'image Docker (pour permissions de pull)"
  type        = string
  default     = "prj-dinum-data-templates-66aa"
}

variable "job_timezone" {
  description = "Timezone for the CronJob schedule (e.g., 'Pacific/Noumea')"
  type        = string
  default     = "Pacific/Noumea"
}

variable "env_vars" {
  description = "Variables d'environnement"
  type        = map(string)
  default     = {}
}

variable "env_from_k8s_secret" {
  description = "Variables d'environnement injectées depuis des Secrets Kubernetes (et non GCP)"
  type = map(object({
    secret_name = string
    key         = string
  }))
  default = {}
}

variable "service_account_email" {
  description = "Email du service account GCP (optionnel si create_service_account = true)"
  type        = string
  default     = null
}

variable "create_service_account" {
  description = "Créer un Service Account GCP dédié pour ce job"
  type        = bool
  default     = true
}

variable "project_id" {
  description = "ID du projet GCP où créer le Service Account et les ressources"
  type        = string
  default     = null
}

variable "gke_project_id" {
  description = "ID du projet GCP hébergeant le cluster GKE (pour Workload Identity)"
  type        = string
  default     = "prj-dinum-gke-f8f8"
}

variable "gcp_service_account_roles" {
  description = "Liste des rôles IAM à attribuer au Service Account sur le projet"
  type        = list(string)
  default     = []
}

variable "secret_project_id" {
  description = "ID du projet contenant les secrets"
  type        = string
  default     = "prj-dinum-p-secret-mgnt-aaf4"
}

variable "secrets_env_vars" {
  description = "Map de variables d'environnement pointant vers des secrets GCP. Clé = Nom de la variable d'env, Valeur = ID du secret (sans projects/...)"
  type        = map(string)
  default     = {}
}

variable "resources_requests" {
  description = "Ressources demandées"
  type = object({
    memory            = string
    cpu               = string
    ephemeral-storage = optional(string, "1Gi")
  })
  default = {
    memory            = "512Mi"
    cpu               = "500m"
    ephemeral-storage = "1Gi"
  }
}

variable "resources_limits" {
  description = "Limites de ressources"
  type = object({
    memory            = string
    cpu               = string
    ephemeral-storage = optional(string, "2Gi")
  })
  default = {
    memory            = "2Gi"
    cpu               = "1000m"
    ephemeral-storage = "2Gi"
  }
}

variable "active_deadline_seconds" {
  description = "Délai maximum d'exécution en secondes"
  type        = number
  default     = 3600
}

variable "backoff_limit" {
  description = "Nombre de tentatives en cas d'échec"
  type        = number
  default     = 2
}

