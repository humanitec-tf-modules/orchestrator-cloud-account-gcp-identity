> [!NOTE]
> 🚧 The content of this repository is currently being curated. Please do not use before the first release has been cut.

# Cloud Accounts of type GCP Service account impersonation

This repository contains a OpenTofu/Terraform module for managing Cloud Accounts of type [GCP Service account impersonation](https://developer.humanitec.com/platform-orchestrator/docs/platform-orchestrator/security/cloud-accounts/gcp/#gcp-service-account-impersonation) in the [Humanitec Platform Orchestrator](https://developer.humanitec.com/platform-orchestrator/).

## Usage

The module always creates the Orchestrator Cloud Account and the IAM policy binding which allows the Cloud Account to impersonate the GCP service account. It provides flexibility as to which other GCP objects to create or to pass in if you prefer to manage them outside of the module.

The IAM policy binding is non-authoritative (`google_service_account_iam_member`) and leaves any other bindings on the service account in place.

Remember to [grant the required permissions](https://cloud.google.com/iam/docs/granting-changing-revoking-access) to the service account on the target GCP resources. Use the `service_account_member` output as the IAM member.

### Create service account, use existing workload identity pool provider

```hcl
resource "google_iam_workload_identity_pool" "humanitec" {
  workload_identity_pool_id = "humanitec-wif-pool"
}

resource "google_iam_workload_identity_pool_provider" "humanitec" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.humanitec.workload_identity_pool_id
  workload_identity_pool_provider_id = "humanitec-wif"
  attribute_mapping = {
    "google.subject" = "assertion.sub"
  }
  attribute_condition = "assertion.sub.startsWith(\"my-org/\")"
  oidc {
    issuer_uri = "https://idtoken.humanitec.io"
  }
}

module "cloud_account_gcp_identity" {
  source = "github.com/humanitec-tf-modules/orchestrator-cloud-account-gcp-identity?ref=vX.Y.Z"

  # Recommended: explicitly pass in the provider configurations
  providers = {
    humanitec = humanitec
    google    = google
  }

  humanitec_org_id                     = "my-org"
  cloud_account_id                     = "my-gcp-identity-account"
  cloud_account_name                   = "My GCP identity account"
  gcp_project_id                       = "my-gcp-project"
  workload_identity_pool_provider_name = google_iam_workload_identity_pool_provider.humanitec.name
  service_account_id                   = "humanitec-access-gke"
}

# Grant permissions to the service account
resource "google_project_iam_member" "gke_developer" {
  project = "my-gcp-project"
  role    = "roles/container.developer"
  member  = module.cloud_account_gcp_identity.service_account_member
}
```

### Create service account and workload identity pool provider

```hcl
  humanitec_org_id   = "my-org"
  cloud_account_id   = "my-gcp-identity-account"
  cloud_account_name = "My GCP identity account"
  gcp_project_id     = "my-gcp-project"
  service_account_id = "humanitec-access-gke"
```

### Create service account and workload identity pool provider, let module generate names

```hcl
  humanitec_org_id = "my-org"
```

The module uses the project configured for the `google` provider.

### Bring existing service account and workload identity pool provider

```hcl
module "cloud_account_gcp_identity" {
  source = "github.com/humanitec-tf-modules/orchestrator-cloud-account-gcp-identity?ref=vX.Y.Z"
  # ...
  workload_identity_pool_provider_name = "projects/123456789012/locations/global/workloadIdentityPools/humanitec-wif-pool/providers/humanitec-wif"
  service_account_create               = false
  service_account_email                = "my-existing-sa@my-gcp-project.iam.gserviceaccount.com"
}
```

The workload identity pool provider name must contain the project number, not the project ID. Find it via `gcloud projects describe my-gcp-project --format='get(projectNumber)'`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 7.0 |
| <a name="requirement_humanitec"></a> [humanitec](#requirement\_humanitec) | ~> 1.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_iam_workload_identity_pool.humanitec_oidc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool) | resource |
| [google_iam_workload_identity_pool_provider.humanitec_oidc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider) | resource |
| [google_service_account.cloud_account](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_member.workload_identity_user](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |
| [humanitec_resource_account.gcp_identity](https://registry.terraform.io/providers/humanitec/humanitec/latest/docs/resources/resource_account) | resource |
| [random_string.cloud_account_id_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cloud_account_id"></a> [cloud\_account\_id](#input\_cloud\_account\_id) | ID for the Cloud Account. If not set, the module generates an ID with a random suffix | `string` | `null` | no |
| <a name="input_cloud_account_name"></a> [cloud\_account\_name](#input\_cloud\_account\_name) | Name for the Cloud Account. If not set, will be set to the value of `cloud_account_id` | `string` | `null` | no |
| <a name="input_gcp_project_id"></a> [gcp\_project\_id](#input\_gcp\_project\_id) | ID of the GCP project in which the module creates GCP objects (service account, workload identity pool and provider). If not set, the project configured for the `google` provider is used | `string` | `null` | no |
| <a name="input_humanitec_org_id"></a> [humanitec\_org\_id](#input\_humanitec\_org\_id) | Humanitec Organization ID | `string` | n/a | yes |
| <a name="input_service_account_create"></a> [service\_account\_create](#input\_service\_account\_create) | Whether to create the GCP service account impersonated via the Cloud Account. If `false`, `service_account_email` must be the email of an existing service account. In both cases, the module adds the IAM policy binding allowing the Cloud Account to impersonate the service account | `bool` | `true` | no |
| <a name="input_service_account_email"></a> [service\_account\_email](#input\_service\_account\_email) | The email of an existing GCP service account impersonated via the Cloud Account. Required if `service_account_create` is `false`, must not be set otherwise | `string` | `null` | no |
| <a name="input_service_account_id"></a> [service\_account\_id](#input\_service\_account\_id) | The account ID (the part before the `@`) for the service account created by the module. If not set, the module generates an ID including the cloud account id, truncated to 30 characters. Only used if `service_account_create` is `true` | `string` | `null` | no |
| <a name="input_workload_identity_pool_provider_name"></a> [workload\_identity\_pool\_provider\_name](#input\_workload\_identity\_pool\_provider\_name) | Full resource name of an existing workload identity pool provider for the Humanitec OIDC issuer, like `projects/123456789012/locations/global/workloadIdentityPools/my-pool/providers/my-provider`. Note that it requires the project number, not the project ID. If not set, the module generates a pool and provider as a convenience but doing so is not recommended for production use as they will be bound to this specific Cloud Account lifecycle | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cloud_account_id"></a> [cloud\_account\_id](#output\_cloud\_account\_id) | ID of the Orchestrator Cloud Account |
| <a name="output_cloud_account_name"></a> [cloud\_account\_name](#output\_cloud\_account\_name) | Name of the Orchestrator Cloud Account |
| <a name="output_gcp_audience"></a> [gcp\_audience](#output\_gcp\_audience) | Audience of the OIDC token used by the Cloud Account, i.e. the URL of the workload identity pool provider |
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email of the GCP service account impersonated by the Cloud Account |
| <a name="output_service_account_member"></a> [service\_account\_member](#output\_service\_account\_member) | IAM member string of the GCP service account impersonated by the Cloud Account. Use it to grant the service account permissions on GCP resources |
| <a name="output_workload_identity_pool_name"></a> [workload\_identity\_pool\_name](#output\_workload\_identity\_pool\_name) | Full resource name of the workload identity pool containing the workload identity pool provider |
| <a name="output_workload_identity_pool_provider_name"></a> [workload\_identity\_pool\_provider\_name](#output\_workload\_identity\_pool\_provider\_name) | Full resource name of the workload identity pool provider. If the name of an existing provider was passed in, it is that value, otherwise the name of the newly created provider |
| <a name="output_workload_identity_principal"></a> [workload\_identity\_principal](#output\_workload\_identity\_principal) | Workload identity federation principal representing the Cloud Account. The module grants it `roles/iam.workloadIdentityUser` on the service account |
<!-- END_TF_DOCS -->