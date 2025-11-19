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

variable "image" {
  description = "Image Docker à utiliser"
  type        = string
}

variable "env_vars" {
  description = "Variables d'environnement"
  type        = map(string)
  default     = {}
}

variable "env_from_secret" {
  description = "Variables depuis K8s Secret"
  type = map(object({
    secret_name = string
    key         = string
  }))
  default = {}
}

variable "service_account_email" {
  description = "Email du service account GCP (pour Workload Identity)"
  type        = string
}

variable "resources_requests" {
  description = "Ressources demandées"
  type = object({
    memory = string
    cpu    = string
  })
  default = {
    memory = "512Mi"
    cpu    = "500m"
  }
}

variable "resources_limits" {
  description = "Limites de ressources"
  type = object({
    memory = string
    cpu    = string
  })
  default = {
    memory = "1Gi"
    cpu    = "1000m"
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
