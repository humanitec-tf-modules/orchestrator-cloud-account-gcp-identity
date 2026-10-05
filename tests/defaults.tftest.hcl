# All providers are mocked so runs can use "command = apply" without real credentials.
# This makes values only known after apply (like the random suffix) available to assertions.
# These runs live in their own file because each test file has its own state, so the
# mocked resources never get refreshed by the real providers used in other test files.

mock_provider "google" {
  # Realistic values for attributes computed by GCP, as the module parses the pool provider name
  mock_resource "google_service_account" {
    defaults = {
      email = "hum-gcp-identity-abcd1234@my-project.iam.gserviceaccount.com"
      name  = "projects/my-project/serviceAccounts/hum-gcp-identity-abcd1234@my-project.iam.gserviceaccount.com"
    }
  }
  mock_resource "google_iam_workload_identity_pool" {
    defaults = {
      name = "projects/123456789012/locations/global/workloadIdentityPools/hum-gcp-identity-abcd1234"
    }
  }
  mock_resource "google_iam_workload_identity_pool_provider" {
    defaults = {
      name = "projects/123456789012/locations/global/workloadIdentityPools/hum-gcp-identity-abcd1234/providers/hum-gcp-identity-abcd1234"
    }
  }
}

mock_provider "humanitec" {}

mock_provider "random" {
  mock_resource "random_string" {
    defaults = {
      result = "abcd1234"
    }
  }
}

run "test_all_default" {
  command = apply

  variables {
    humanitec_org_id = "my-org"
  }

  assert {
    condition     = length(google_iam_workload_identity_pool.humanitec_oidc) == 1 && length(google_iam_workload_identity_pool_provider.humanitec_oidc) == 1
    error_message = "The module must create a workload identity pool and provider if workload_identity_pool_provider_name is not set"
  }

  assert {
    condition     = humanitec_resource_account.gcp_identity.id == "gcp-identity-abcd1234"
    error_message = "The Cloud Account ID must default to 'gcp-identity-' plus a random suffix"
  }

  assert {
    condition     = humanitec_resource_account.gcp_identity.name == humanitec_resource_account.gcp_identity.id
    error_message = "The Cloud Account name must default to the Cloud Account ID"
  }

  assert {
    condition     = humanitec_resource_account.gcp_identity.type == "gcp-identity"
    error_message = "The Cloud Account type must be 'gcp-identity'"
  }

  assert {
    condition     = google_service_account.cloud_account[0].account_id == "hum-gcp-identity-abcd1234"
    error_message = "The service account ID must default to 'hum-' plus the Cloud Account ID"
  }

  assert {
    condition     = google_iam_workload_identity_pool.humanitec_oidc[0].workload_identity_pool_id == "hum-gcp-identity-abcd1234"
    error_message = "The workload identity pool ID must default to 'hum-' plus the Cloud Account ID"
  }

  assert {
    condition = jsondecode(humanitec_resource_account.gcp_identity.credentials) == {
      gcp_service_account = google_service_account.cloud_account[0].email
      gcp_audience        = "//iam.googleapis.com/${google_iam_workload_identity_pool_provider.humanitec_oidc[0].name}"
    }
    error_message = "The Cloud Account credentials must contain the new service account and pool provider"
  }

  assert {
    condition     = google_service_account_iam_member.workload_identity_user.service_account_id == google_service_account.cloud_account[0].name
    error_message = "The IAM binding must target the new service account"
  }

  assert {
    condition     = google_service_account_iam_member.workload_identity_user.member == "principal://iam.googleapis.com/${google_iam_workload_identity_pool.humanitec_oidc[0].name}/subject/my-org/gcp-identity-abcd1234"
    error_message = "The IAM binding must grant access to the principal of the Cloud Account in the new pool"
  }

  assert {
    condition     = output.workload_identity_pool_name == google_iam_workload_identity_pool.humanitec_oidc[0].name
    error_message = "The workload_identity_pool_name output must be the name of the new pool"
  }

  assert {
    condition     = output.service_account_member == "serviceAccount:${google_service_account.cloud_account[0].email}"
    error_message = "The service_account_member output must be the IAM member string of the new service account"
  }
}
