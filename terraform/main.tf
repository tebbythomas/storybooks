terraform {
  backend "gcs" {
    bucket = "storybook-304512-terraform"
    prefix = "/state/storybooks"
  }
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "3.56.0"
    }
    mongodbatlas = {
      source = "mongodb/mongodbatlas"
      version = "0.8.2"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "2.18.0"
    }
  }
}
