variable "cluster_name" {
  description = "Name of the local kind cluster."
  type        = string
  default     = "mural"
}

variable "namespace" {
  description = "Namespace where the application is installed."
  type        = string
  default     = "mural"
}

variable "host" {
  description = "Ingress hostname; localtest.me resolves to 127.0.0.1."
  type        = string
  default     = "mural.localtest.me"
}

variable "api_image" {
  type    = string
  default = "mural-api:local"
}

variable "web_image" {
  type    = string
  default = "mural-web:local"
}

variable "traefik_chart_version" {
  description = "Pinned for reproducible installs."
  type        = string
  default     = "39.0.0"
}

variable "metrics_server_chart_version" {
  description = "Pinned official Metrics Server chart version."
  type        = string
  default     = "3.14.0"
}

