provider "namecheap" {
  user_name   = var.namecheap_username
  api_user    = var.namecheap_username
  api_key     = var.namecheap_token
  client_ip   = var.namecheap_ip
  use_sandbox = false
}

resource "namecheap_domain_records" "lark-dog" {
  domain     = var.namecheap_domain
  mode       = "OVERWRITE"
  email_type = "FWD"

  record {
    hostname = "@"
    type     = "A"
    address  = google_compute_address.ipv4.address
  }

  # Certification Authority Authorization record
  record {
    hostname = "@"
    type     = "CAA"
    address  = "0 issue \"letsencrypt.org\""
  }


}
