output "service_account_email" {
  value       = local.service_account_email
  description = "Email of the GCP service account impersonated by the Cloud Account"
}
output "service_account_member" {
  value       = "serviceAccount:${local.service_account_email}"
  description = "IAM member string of the GCP service account impersonated by the Cloud Account. Use it to grant the service account permissions on GCP resources"
}
output "cloud_account_id" {
  value       = humanitec_resource_account.gcp_identity.id
  description = "ID of the Orchestrator Cloud Account"
}
output "cloud_account_name" {
  value       = humanitec_resource_account.gcp_identity.name
  description = "Name of the Orchestrator Cloud Account"
}
output "workload_identity_pool_provider_name" {
  value       = local.workload_identity_pool_provider_name
  description = "Full resource name of the workload identity pool provider. If the name of an existing provider was passed in, it is that value, otherwise the name of the newly created provider"
}
output "workload_identity_pool_name" {
  value       = local.workload_identity_pool_name
  description = "Full resource name of the workload identity pool containing the workload identity pool provider"
}
output "gcp_audience" {
  value       = local.gcp_audience
  description = "Audience of the OIDC token used by the Cloud Account, i.e. the URL of the workload identity pool provider"
}
output "workload_identity_principal" {
  value       = local.workload_identity_principal
  description = "Workload identity federation principal representing the Cloud Account. The module grants it `roles/iam.workloadIdentityUser` on the service account"
}
