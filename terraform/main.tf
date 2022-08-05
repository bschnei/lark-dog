terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    namecheap = {
      source  = "namecheap/namecheap"
      version = "~> 2.0"
    }
  }
}
