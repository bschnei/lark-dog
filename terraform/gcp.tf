provider "google" {

  # default project and region to apply to resources
  project     = var.gcp_project_id
  region      = "us-central1"

  credentials = file("terraform-sa-key.json")

}

# IP ADDRESS
resource "google_compute_address" "ipv4" {
  name = "${var.gcp_instance_name}-ip"
}

# NETWORK
data "google_compute_network" "default" {
  name = "default"
}

# FIREWALL RULES
resource "google_compute_firewall" "allow_web" {
  name    = "allow-web"
  network = data.google_compute_network.default.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]

  target_tags = ["allow-web"]
}

# OS IMAGE
data "google_compute_image" "boot_image" {
  family  = "ubuntu-minimal-2104"
  project = "ubuntu-os-cloud"
}

# web server instance
resource "google_compute_instance" "web_server" {

  boot_disk {
    initialize_params {
      image = data.google_compute_image.boot_image.self_link
    }
  }

  # f1-micro is the smallest/cheapest instance gcp offers
  machine_type = "e2-small"

  # this is a static hostname within the VPC
  # changing it requires a complete rebuild of the instance!
  name         = var.gcp_instance_name

  zone         = "us-central1-a"

  # required. specifies the VPC
  network_interface {
    network = data.google_compute_network.default.name

    access_config {
      nat_ip = google_compute_address.ipv4.address
    }
  }

  tags = google_compute_firewall.allow_web.target_tags

  service_account {
    scopes = ["storage-ro"]
  }

  metadata = {
    user-data = file("cloud-init.conf")
  }
}
