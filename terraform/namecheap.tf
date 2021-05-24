provider "namecheap" {
  username    = var.namecheap_username
  api_user    = var.namecheap_username
  token       = var.namecheap_token
  ip          = var.namecheap_ip
  use_sandbox = false
}

# ipv4 address record
resource "namecheap_record" "ipv4_record" {
  name    = "@"
  domain  = var.namecheap_domain
  address = google_compute_address.ipv4.address
  type    = "A"
}

# Certification Authority Authorization record
resource "namecheap_record" "caa_record" {
  name    = "@"
  domain  = var.namecheap_domain
  address = "0 issue \"letsencrypt.org\""
  type    = "CAA"
}
