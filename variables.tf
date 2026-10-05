variable "humanitec_org_id" {
  type        = string
  description = "Humanitec Organization ID"
  nullable    = false
}
variable "cloud_account_id" {
  type        = string
  description = "ID for the Cloud Account. If not set, the module generates an ID with a random suffix"
  nullable    = true
  default     = null
}
variable "cloud_account_name" {
  type        = string
  description = "Name for the Cloud Account. If not set, will be set to the value of `cloud_account_id`"
  nullable    = true
  default     = null
}
variable "gcp_project_id" {
  type        = string
  description = "ID of the GCP project in which the module creates GCP objects (service account, workload identity pool and provider). If not set, the project configured for the `google` provider is used"
  nullable    = true
  default     = null
}
variable "workload_identity_pool_provider_name" {
  type        = string
  description = "Full resource name of an existing workload identity pool provider for the Humanitec OIDC issuer, like `projects/123456789012/locations/global/workloadIdentityPools/my-pool/providers/my-provider`. Note that it requires the project number, not the project ID. If not set, the module generates a pool and provider as a convenience but doing so is not recommended for production use as they will be bound to this specific Cloud Account lifecycle"
  nullable    = true
  default     = null

  validation {
    condition     = var.workload_identity_pool_provider_name == null || can(regex("^projects/[0-9]+/locations/global/workloadIdentityPools/[a-z0-9-]+/providers/[a-z0-9-]+$", var.workload_identity_pool_provider_name))
    error_message = "workload_identity_pool_provider_name must be a full provider resource name like projects/123456789012/locations/global/workloadIdentityPools/my-pool/providers/my-provider"
  }
}
variable "service_account_create" {
  type        = bool
  description = "Whether to create the GCP service account impersonated via the Cloud Account. If `false`, `service_account_email` must be the email of an existing service account. In both cases, the module adds the IAM policy binding allowing the Cloud Account to impersonate the service account"
  nullable    = false
  default     = true
}
variable "service_account_id" {
  type        = string
  description = "The account ID (the part before the `@`) for the service account created by the module. If not set, the module generates an ID including the cloud account id, truncated to 30 characters. Only used if `service_account_create` is `true`"
  nullable    = true
  default     = null

  validation {
    condition     = var.service_account_create || var.service_account_id == null
    error_message = "service_account_id must not be set if service_account_create is false. Use service_account_email to pass in an existing service account"
  }

  validation {
    condition     = var.service_account_id == null || can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.service_account_id))
    error_message = "service_account_id must be 6-30 characters long, consist of lowercase letters, digits and hyphens, start with a letter and not end with a hyphen"
  }
}
variable "service_account_email" {
  type        = string
  description = "The email of an existing GCP service account impersonated via the Cloud Account. Required if `service_account_create` is `false`, must not be set otherwise"
  nullable    = true
  default     = null

  validation {
    condition     = var.service_account_create ? var.service_account_email == null : var.service_account_email != null
    error_message = "service_account_email must be set if service_account_create is false, and must not be set otherwise"
  }

  validation {
    condition     = var.service_account_email == null || can(regex("^[a-z0-9._-]+@[a-z0-9.-]+\\.gserviceaccount\\.com$", var.service_account_email))
    error_message = "service_account_email must be a service account email like my-sa@my-project.iam.gserviceaccount.com"
  }
}
