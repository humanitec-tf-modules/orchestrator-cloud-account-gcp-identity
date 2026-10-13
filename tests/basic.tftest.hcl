# See https://developer.hashicorp.com/terraform/language/tests for more on how to write tests.
# See https://developer.hashicorp.com/terraform/language/tests/mocking for information on mocking providers.

# A static access token keeps the provider from looking up real credentials. Plans make no API calls
provider "google" {
  project      = "my-project"
  access_token = "mock_access_token"
}

# Mocked so the tests need no Humanitec API token
mock_provider "humanitec" {}

run "test_existing_pool_provider" {
  command = plan

  variables {
    humanitec_org_id                     = "my-org"
    cloud_account_id                     = "my-cloud-account"
    workload_identity_pool_provider_name = "projects/123456789012/locations/global/workloadIdentityPools/my-pool/providers/my-provider"
  }

  assert {
    condition     = length(google_iam_workload_identity_pool.humanitec_oidc) == 0 && length(google_iam_workload_identity_pool_provider.humanitec_oidc) == 0
    error_message = "The module must not create a workload identity pool or provider if workload_identity_pool_provider_name is set"
  }

  assert {
    condition     = output.workload_identity_pool_provider_name == var.workload_identity_pool_provider_name
    error_message = "The workload_identity_pool_provider_name output must equal the workload_identity_pool_provider_name variable"
  }

  assert {
    condition     = output.workload_identity_pool_name == "projects/123456789012/locations/global/workloadIdentityPools/my-pool"
    error_message = "The workload_identity_pool_name output must be the pool part of workload_identity_pool_provider_name"
  }

  assert {
    condition     = output.gcp_audience == "//iam.googleapis.com/${var.workload_identity_pool_provider_name}"
    error_message = "The gcp_audience output must be the URL of the existing pool provider"
  }

  assert {
    condition     = google_service_account_iam_member.workload_identity_user.member == "principal://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/my-pool/subject/my-org/my-cloud-account"
    error_message = "The IAM binding must grant access to the principal of the Cloud Account in the existing pool"
  }

  assert {
    condition     = output.workload_identity_principal == google_service_account_iam_member.workload_identity_user.member
    error_message = "The workload_identity_principal output must equal the member of the IAM binding"
  }

  assert {
    condition     = google_service_account_iam_member.workload_identity_user.role == "roles/iam.workloadIdentityUser"
    error_message = "The IAM binding must grant roles/iam.workloadIdentityUser"
  }
}

run "test_custom_service_account_id" {
  command = plan

  variables {
    humanitec_org_id   = "my-org"
    service_account_id = "my-service-account"
  }

  assert {
    condition     = google_service_account.cloud_account[0].account_id == var.service_account_id
    error_message = "The service account must use service_account_id as its account ID"
  }
}

run "test_existing_service_account" {
  command = plan

  variables {
    humanitec_org_id                     = "my-org"
    cloud_account_id                     = "my-cloud-account"
    workload_identity_pool_provider_name = "projects/123456789012/locations/global/workloadIdentityPools/my-pool/providers/my-provider"
    service_account_create               = false
    service_account_email                = "my-existing-sa@my-project.iam.gserviceaccount.com"
  }

  assert {
    condition     = length(google_service_account.cloud_account) == 0
    error_message = "The module must not create a service account if service_account_create is false"
  }

  assert {
    condition     = google_service_account_iam_member.workload_identity_user.service_account_id == "projects/-/serviceAccounts/${var.service_account_email}"
    error_message = "The IAM binding must target the existing service account"
  }

  assert {
    condition = jsondecode(humanitec_resource_account.gcp_identity.credentials) == {
      gcp_service_account = var.service_account_email
      gcp_audience        = "//iam.googleapis.com/${var.workload_identity_pool_provider_name}"
    }
    error_message = "The Cloud Account credentials must contain the existing service account and pool provider"
  }

  assert {
    condition     = output.service_account_email == var.service_account_email
    error_message = "The service_account_email output must equal the service_account_email variable"
  }

  assert {
    condition     = output.service_account_member == "serviceAccount:${var.service_account_email}"
    error_message = "The service_account_member output must be the IAM member string of the existing service account"
  }
}

run "test_existing_service_account_requires_email" {
  command = plan

  variables {
    humanitec_org_id       = "my-org"
    service_account_create = false
  }

  expect_failures = [
    var.service_account_email,
  ]
}

run "test_existing_service_account_rejects_id" {
  command = plan

  variables {
    humanitec_org_id       = "my-org"
    service_account_create = false
    service_account_id     = "my-existing-sa"
    service_account_email  = "my-existing-sa@my-project.iam.gserviceaccount.com"
  }

  expect_failures = [
    var.service_account_id,
  ]
}

run "test_new_service_account_rejects_email" {
  command = plan

  variables {
    humanitec_org_id      = "my-org"
    service_account_email = "my-existing-sa@my-project.iam.gserviceaccount.com"
  }

  expect_failures = [
    var.service_account_email,
  ]
}

run "test_invalid_service_account_email" {
  command = plan

  variables {
    humanitec_org_id       = "my-org"
    service_account_create = false
    service_account_email  = "my-existing-sa"
  }

  expect_failures = [
    var.service_account_email,
  ]
}

run "test_invalid_service_account_id" {
  command = plan

  variables {
    humanitec_org_id   = "my-org"
    service_account_id = "My_Service_Account"
  }

  expect_failures = [
    var.service_account_id,
  ]
}

run "test_invalid_pool_provider_name" {
  command = plan

  variables {
    humanitec_org_id                     = "my-org"
    workload_identity_pool_provider_name = "projects/my-project/locations/global/workloadIdentityPools/my-pool/providers/my-provider"
  }

  expect_failures = [
    var.workload_identity_pool_provider_name,
  ]
}
