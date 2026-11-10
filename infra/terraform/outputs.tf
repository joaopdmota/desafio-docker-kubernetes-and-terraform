output "application_url" {
  description = "Open this URL after apply completes."
  value       = "http://${var.host}"
}

output "kubeconfig_path" {
  description = "Kubeconfig generated for the kind cluster."
  value       = local.kubeconfig_path
}

output "verification_commands" {
  value = <<-EOT
    curl --fail http://${var.host}/api/messages
    kubectl --kubeconfig ${local.kubeconfig_path} -n ${var.namespace} get pods,jobs,pvc,ingress
  EOT
}

