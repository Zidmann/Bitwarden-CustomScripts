resource "google_storage_bucket" "bucket_arrival" {
  for_each = { for client in var.client_list : client.name => client }

  name     = "${var.gcp_project_id}-${each.value.name}-in"
  location = "${each.value.location}"
}

resource "google_storage_bucket_iam_member" "bucket_arrival" {
  for_each = { for client in var.client_list : client.name => client }

  bucket = "${var.gcp_project_id}-${each.value.name}-in"
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:bitwarden-sa-${each.value.name}@${data.google_project.current_project.project_id}.iam.gserviceaccount.com"
}

resource "google_storage_bucket" "bucket_vault" {
  for_each = { for client in var.client_list : client.name => client }

  name     = "${var.gcp_project_id}-${each.value.name}-vault"
  location = "${each.value.location}"
}

resource "google_pubsub_topic" "pubsub_arrival" {
  name = "pubsub-arrival"
}

data "google_storage_project_service_account" "gcs_service_account" {
}

resource "google_pubsub_topic_iam_binding" "object_notification" {
  topic   = google_pubsub_topic.pubsub_arrival.id
  role    = "roles/pubsub.publisher"
  members = ["serviceAccount:${data.google_storage_project_service_account.gcs_service_account.email_address}"]
}

resource "google_storage_notification" "object_finalize" {
  for_each = { for client in var.client_list : client.name => client }
  
  bucket         = "${var.gcp_project_id}-${each.value.name}-in"
  payload_format = "JSON_API_V1"
  topic          = google_pubsub_topic.pubsub_arrival.id
  event_types    = ["OBJECT_FINALIZE"]
  depends_on = [
    google_pubsub_topic_iam_binding.object_notification,
    google_storage_bucket.bucket_arrival 
  ]
}

