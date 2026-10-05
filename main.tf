resource "random_string" "cloud_account_id_suffix" {
  count   = var.cloud_account_id == null ? 1 : 0
  length  = 8
  upper   = false
  special = false
}

locals {
  cloud_account_type = "gcp-identity"
  cloud_account_id   = var.cloud_account_id != null ? var.cloud_account_id : "gcp-identity-${random_string.cloud_account_id_suffix[0].result}"
  cloud_account_name = var.cloud_account_name != null ? var.cloud_account_name : local.cloud_account_id

  # GCP limits IDs to 30 (service account) or 32 (pool, pool provider) characters. Truncate and drop trailing hyphens
  generated_id          = "hum-${local.cloud_account_id}"
  service_account_id    = var.service_account_id != null ? var.service_account_id : replace(substr(local.generated_id, 0, 30), "/-+$/", "")
  workload_identity_id  = replace(substr(local.generated_id, 0, 32), "/-+$/", "")
  service_account_email = var.service_account_create ? google_service_account.cloud_account[0].email : var.service_account_email
  # The "-" wildcard lets GCP infer the project from the service account email
  service_account_name = var.service_account_create ? google_service_account.cloud_account[0].name : "projects/-/serviceAccounts/${var.service_account_email}"

  workload_identity_pool_provider_name = var.workload_identity_pool_provider_name != null ? var.workload_identity_pool_provider_name : google_iam_workload_identity_pool_provider.humanitec_oidc[0].name
  workload_identity_pool_name          = regex("^(.+)/providers/[^/]+$", local.workload_identity_pool_provider_name)[0]
  gcp_audience                         = "//iam.googleapis.com/${local.workload_identity_pool_provider_name}"
  workload_identity_principal          = "principal://iam.googleapis.com/${local.workload_identity_pool_name}/subject/${var.humanitec_org_id}/${local.cloud_account_id}"
}

# Workload identity pool and OIDC provider for service account impersonation. Create only if requested
resource "google_iam_workload_identity_pool" "humanitec_oidc" {
  count                     = var.workload_identity_pool_provider_name == null ? 1 : 0
  project                   = var.gcp_project_id
  workload_identity_pool_id = local.workload_identity_id
  description               = "Humanitec Platform Orchestrator Cloud Account ${var.humanitec_org_id}/${local.cloud_account_id}"
}

resource "google_iam_workload_identity_pool_provider" "humanitec_oidc" {
  count                              = var.workload_identity_pool_provider_name == null ? 1 : 0
  project                            = var.gcp_project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.humanitec_oidc[0].workload_identity_pool_id
  workload_identity_pool_provider_id = local.workload_identity_id
  description                        = "Humanitec Platform Orchestrator OIDC issuer"
  attribute_mapping = {
    "google.subject" = "assertion.sub"
  }
  # Only accept tokens issued for Cloud Accounts of this Humanitec Organization
  attribute_condition = "assertion.sub.startsWith(\"${var.humanitec_org_id}/\")"
  oidc {
    issuer_uri = "https://idtoken.humanitec.io"
  }
}

# Service account to impersonate. Create only if requested
resource "google_service_account" "cloud_account" {
  count        = var.service_account_create ? 1 : 0
  project      = var.gcp_project_id
  account_id   = local.service_account_id
  display_name = "Humanitec Cloud Account ${local.cloud_account_id}"
  description  = "Used by Humanitec Platform Orchestrator Cloud Account ${var.humanitec_org_id}/${local.cloud_account_id}"
}

# Allow the Cloud Account principal to impersonate the service account. Non-authoritative, so other bindings are preserved
resource "google_service_account_iam_member" "workload_identity_user" {
  service_account_id = local.service_account_name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.workload_identity_principal
}

# Orchestrator Cloud Account
resource "humanitec_resource_account" "gcp_identity" {
  id   = local.cloud_account_id
  name = local.cloud_account_name
  type = local.cloud_account_type
  credentials = jsonencode({
    gcp_service_account = local.service_account_email
    gcp_audience        = local.gcp_audience
  })

  # Keep the impersonation permission in place for the whole lifecycle of the Cloud Account
  depends_on = [google_service_account_iam_member.workload_identity_user]
}
