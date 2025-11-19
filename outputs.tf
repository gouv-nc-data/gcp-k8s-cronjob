output "cronjob_name" {
  value       = kubernetes_cron_job_v1.cronjob.metadata[0].name
  description = "Nom du CronJob créé"
}

output "service_account_name" {
  value       = kubernetes_service_account.cronjob_sa.metadata[0].name
  description = "Nom du Service Account Kubernetes"
}

output "schedule" {
  value       = kubernetes_cron_job_v1.cronjob.spec[0].schedule
  description = "Schedule du CronJob"
}

output "namespace" {
  value       = kubernetes_cron_job_v1.cronjob.metadata[0].namespace
  description = "Namespace du CronJob"
}
