terraform {
  required_version = ">= 1.11.0"

  required_providers {
    humanitec = {
      source  = "humanitec/humanitec"
      version = "~> 1.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
