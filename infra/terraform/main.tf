locals {
  project_root    = abspath("${path.module}/../..")
  kubeconfig_path = abspath("${path.module}/.kubeconfig")
  api_repository  = split(":", var.api_image)[0]
  api_tag         = length(split(":", var.api_image)) > 1 ? split(":", var.api_image)[1] : "local"
  web_repository  = split(":", var.web_image)[0]
  web_tag         = length(split(":", var.web_image)) > 1 ? split(":", var.web_image)[1] : "local"
  image_sources = concat(
    sort(fileset(local.project_root, "app/api/**")),
    sort(fileset(local.project_root, "app/web/**")),
    sort(fileset(local.project_root, "app/docker/**"))
  )
  image_source_hash = sha256(join("", [for file in local.image_sources : filesha256("${local.project_root}/${file}")]))
}

resource "kind_cluster" "mural" {
  name            = var.cluster_name
  wait_for_ready  = true
  kubeconfig_path = local.kubeconfig_path

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"
      kubeadm_config_patches = [<<-YAML
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
      YAML
      ]
      extra_port_mappings {
        container_port = 80
        host_port      = 80
        # The kind node runs inside the Docker-in-Docker toolbox. Binding to
        # all toolbox interfaces lets the outer Compose port mapping reach it.
        listen_address = "0.0.0.0"
        protocol       = "TCP"
      }
      extra_port_mappings {
        container_port = 443
        host_port      = 443
        listen_address = "0.0.0.0"
        protocol       = "TCP"
      }
    }
  }
}

resource "terraform_data" "image_build" {
  triggers_replace = [local.image_source_hash, var.api_image, var.web_image]

  provisioner "local-exec" {
    working_dir = local.project_root
    command     = <<-EOT
      docker build -f app/docker/api.Dockerfile -t '${var.api_image}' .
      docker build -f app/docker/web.Dockerfile -t '${var.web_image}' .
    EOT
  }
}

resource "terraform_data" "image_load" {
  triggers_replace = [terraform_data.image_build.id, kind_cluster.mural.id]

  provisioner "local-exec" {
    working_dir = local.project_root
    command     = <<-EOT
      docker image inspect '${var.api_image}' >/dev/null 2>&1 || docker build -f app/docker/api.Dockerfile -t '${var.api_image}' .
      docker image inspect '${var.web_image}' >/dev/null 2>&1 || docker build -f app/docker/web.Dockerfile -t '${var.web_image}' .
      kind load docker-image '${var.api_image}' '${var.web_image}' --name '${var.cluster_name}'
    EOT
  }

  depends_on = [kind_cluster.mural, terraform_data.image_build]
}

resource "random_password" "postgres" {
  length  = 32
  special = false
}

resource "kubernetes_namespace_v1" "mural" {
  metadata { name = var.namespace }

  depends_on = [kind_cluster.mural]
}

resource "helm_release" "traefik" {
  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  version          = var.traefik_chart_version
  namespace        = "traefik-system"
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [yamlencode({
    deployment   = { kind = "DaemonSet" }
    service      = { enabled = false }
    nodeSelector = { "ingress-ready" = "true" }
    tolerations = [{
      key      = "node-role.kubernetes.io/control-plane"
      operator = "Exists"
      effect   = "NoSchedule"
    }]
    ports = {
      web       = { hostPort = 80 }
      websecure = { hostPort = 443 }
    }
  })]

  depends_on = [kind_cluster.mural]
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.metrics_server_chart_version
  namespace  = "kube-system"
  wait       = true
  timeout    = 600

  # kind uses a kubelet serving certificate that is not signed for every node
  # address used by Metrics Server. This relaxation is local-cluster only.
  values = [yamlencode({
    args = ["--kubelet-insecure-tls"]
  })]

  depends_on = [kind_cluster.mural]
}

resource "helm_release" "mural" {
  name      = "mural"
  chart     = abspath("${path.module}/../helm/mural")
  namespace = kubernetes_namespace_v1.mural.metadata[0].name
  wait      = false
  timeout   = 600

  values = [yamlencode({
    api = { image = { repository = local.api_repository, tag = local.api_tag, pullPolicy = "IfNotPresent" } }
    web = { image = { repository = local.web_repository, tag = local.web_tag, pullPolicy = "IfNotPresent" } }
    postgres = { password = random_password.postgres.result }
    ingress  = { host = var.host, className = "traefik", enabled = true }
  })]

  depends_on = [helm_release.traefik, helm_release.metrics_server, terraform_data.image_load]
}

