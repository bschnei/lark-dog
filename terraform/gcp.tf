provider "google" {

  # defaults to apply to resources
  project     = var.gcp_project_id
  region      = var.gcp_region
  zone        = var.gcp_zone
  credentials = file("terraform-sa-key.json")

}

# repo for docker images
resource "google_artifact_registry_repository" "docker" {
  repository_id = var.gcp_artifact_repo_id
  format        = "DOCKER"

  lifecycle {
    ignore_changes = [
      # google did something stupid here
      # ignore changes they made to this attribute on their side
      maven_config,
    ]
  }

}

# static ipv4 address
resource "google_compute_address" "ipv4" {
  name = "${var.gcp_instance_name}-ip"
}

# NETWORK
data "google_compute_network" "default" {
  name = "default"
}

# SLEEP SCHEDULE
resource "google_compute_resource_policy" "sleep_nightly" {
  name = "sleep-nightly"

  instance_schedule_policy {
    time_zone = "America/Los_Angeles"

    vm_start_schedule {
      schedule = "0 8 * * *"
    }

    vm_stop_schedule {
      schedule = "0 22 * * *"
    }
  }
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

# persistent storage
resource "google_compute_disk" "data" {
  name = "data"
  size = 10
  type = "pd-standard"
}

# web server instance
resource "google_compute_instance" "web_server" {

  boot_disk {
    initialize_params {
      type  = "pd-balanced"
      size  = 15
      image = "ubuntu-minimal-2204-lts"
    }
  }

  attached_disk {
    device_name = google_compute_disk.data.name
    source      = google_compute_disk.data.self_link
  }

  machine_type = "e2-micro"
  name         = var.gcp_instance_name

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

  resource_policies = [google_compute_resource_policy.sleep_nightly.self_link]

}
