provider "google" {

  # default project and region to apply to resources
  project = var.gcp_project_id
  region  = "us-central1"

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

# base system image
# note: GCP monitoring agent not availble yet for ubuntu-2104
# see: https://cloud.google.com/monitoring/agent/monitoring#supported_operating_systems
data "google_compute_image" "boot_image" {
  family  = "ubuntu-minimal-2010"
  project = "ubuntu-os-cloud"
}

# persistent storage for photo data
resource "google_compute_disk" "photos" {
  name = "photos"
  size = 10
  type = "pd-standard"
  zone = "us-central1-a"
}

# web server instance
resource "google_compute_instance" "web_server" {

  boot_disk {
    initialize_params {
      type  = "pd-balanced"
      image = data.google_compute_image.boot_image.self_link
    }
  }

  attached_disk {
    device_name = google_compute_disk.photos.name
    source      = google_compute_disk.photos.self_link
  }

  # e2-small seems to have more compute than needed but a good
  # amount of memory
  machine_type = "e2-small"

  # this is a static hostname within the VPC
  # changing it requires a complete rebuild of the instance!
  name = var.gcp_instance_name

  zone = "us-central1-a"

  # required. specifies the VPC
  network_interface {
    network = data.google_compute_network.default.name

    access_config {
      nat_ip = google_compute_address.ipv4.address
    }
  }

  tags = google_compute_firewall.allow_web.target_tags

  service_account {
    scopes = ["monitoring-write", "storage-ro"]
  }

  metadata = {
    startup-script = file("startup.sh")
    user-data      = file("cloud-init.conf")
  }

  resource_policies = [google_compute_resource_policy.sleep_nightly.self_link]

}
