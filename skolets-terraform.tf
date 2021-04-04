provider "google" {
  project = "skolets-terraform"
  zone    = "us-central1-c"
}

resource "google_compute_network" "nat-skolets" {
  name = "nat-skolets"
  mtu  = 1500
  auto_create_subnetworks = false
  project = "skolets-terraform"
  routing_mode = "REGIONAL"
}



resource "google_compute_subnetwork" "skolets-subnet" {
  name          = "skolets-subnet"
  ip_cidr_range = "10.0.1.0/29"
  region        = "us-central1"
  network       = google_compute_network.nat-skolets.id
}



resource "google_compute_firewall" "allow-skolets" {
  name    = "allow-skolets"
  network = google_compute_network.nat-skolets.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["1-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["1-65535"]
  }

  source_ranges = ["10.0.1.0/29"]
  priority = 65534
}



resource "google_compute_firewall" "allow-ssh-iap" {
  name    = "allow-ssh-iap"
  network = google_compute_network.nat-skolets.name
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["10.10.0.0/16"]
  target_tags = ["allow-ssh"]
}



resource "google_compute_instance" "vm-instance-skolets" {
  name         = "skolets-instance"
  machine_type = "f1-micro"
  zone         = "us-central1-c"

  tags = ["no-ip", "allow-ssh"]

  boot_disk {
    initialize_params {
      image = "https://www.googleapis.com/compute/v1/projects/centos-cloud/global/images/centos-7-v20210217"
    }
  }

  network_interface {
    subnetwork = "skolets-subnet"
  }
}



resource "google_compute_instance" "nat-gateway" {
  name         = "nat-gateway"
  machine_type = "f1-micro"
  zone         = "us-central1-c"

  can_ip_forward  = true

  tags = ["nat", "allow-ssh"]

  boot_disk {
    initialize_params {
      image = "https://www.googleapis.com/compute/v1/projects/centos-cloud/global/images/centos-7-v20210217"
    }
  }

  network_interface {
    subnetwork = "skolets-subnet"
    access_config {

    }
  }

  metadata = {
  	startup-script = "#! /bin/bash sudo sh -c \"echo 1 > /proc/sys/net/ipv4/ip_forward\" sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE"
  }
}

resource "google_compute_route" "no-ip-internet-route" {
  name        = "no-ip-internet-route"
  dest_range  = "0.0.0.0/0"
  network     = google_compute_network.nat-skolets.name
  
  next_hop_instance = "nat-gateway"
  next_hop_instance_zone = "us-central1-c"

  tags = ["no-ip"]

  priority = 800
}