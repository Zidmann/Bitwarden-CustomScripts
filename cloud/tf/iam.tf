resource "google_service_account" "sa_buckets" {
  for_each = { for client in var.client_list : client.name => client }

  account_id   = "bitwarden-sa-${each.value.name}"
  display_name = "Service account for the client named ${each.value.name}"
}
