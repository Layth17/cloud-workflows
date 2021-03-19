# --- Variables ----------------------------------------------------------------

locals {
  project = "griffith-lab"
  project-id = 190642530876  # TODO: pull from provider?
  region = "us-central1"
  zone = "us-central1-c"
  # should match webservice.port in cromwell.conf
  cromwell_port = 8000

  ssh_allowed = "cromwell-ssh-allowed"
}

# ------------------------------------------------------------------------------

terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "3.5.0"
    }
  }
}

provider "google" {
  // if this file gets expanded to other labs, these should be tfvars
  credentials = file("terraform-service-account.json")

  project = local.project
  region  = local.region
  zone    = local.zone
}

module "network" {
  source = "./network"
  cromwell_port = local.cromwell_port
  ssh_tag = local.ssh_allowed
}

module "server" {
  source = "./server"
  project    = local.project
  # network
  nat_ip     = network.static_ip
  subnetwork = network.subnetwork
  # files
  conf_file      = file("cromwell.conf")
  service_file   = file("cromwell.service")
  startup_script = file("server_startup.py")

  tags = ["http-server", "https-server", local.ssh_allowed]
}

module "compute" {
  source = "./compute"
  server_service_account = module.server.service_account
}

module "bucket" {
  source = "./bucket"
  project = local.project
  writer_service_accounts = [
    module.compute.service_account,
    module.server.service_account
  ]
}
