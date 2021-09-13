provider "google" {
  project     = var.gcp_project_id
  credentials = file("sa.json")
  region      = var.gcp_region
}

data "google_project" "current_project" {
}

