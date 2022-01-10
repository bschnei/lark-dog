terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    namecheap = {
      source  = "robgmills/namecheap"
      version = "~> 1.7.0"
    }
  }
}
