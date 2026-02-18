output "cronjob_name" {
  value       = kubernetes_cron_job_v1.cronjob.metadata[0].name
  description = "Nom du CronJob créé"
}

output "service_account_name" {
  value       = module.iam.k8s_service_account_name
  description = "Nom du Service Account Kubernetes"
}

output "gcp_service_account_email" {
  value       = module.iam.gcp_service_account_email
  description = "Email du Service Account GCP"
}

output "schedule" {
  value       = kubernetes_cron_job_v1.cronjob.spec[0].schedule
  description = "Schedule du CronJob"
}

output "namespace" {
  value       = kubernetes_cron_job_v1.cronjob.metadata[0].namespace
  description = "Namespace du CronJob"
}
