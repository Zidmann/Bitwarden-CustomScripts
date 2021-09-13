variable "gcp_project_id" {
  type = string
}

variable "gcp_region" {
  type = string
}

variable "client_list" {
  type = list(object({
    name = string,
    location = string
  }))
}

