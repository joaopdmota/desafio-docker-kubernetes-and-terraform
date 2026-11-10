terraform {
  required_version = ">= 1.6.0"

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.11.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

provider "kind" {}

provider "kubernetes" {
  host                   = kind_cluster.mural.endpoint
  client_certificate     = kind_cluster.mural.client_certificate
  client_key             = kind_cluster.mural.client_key
  cluster_ca_certificate = kind_cluster.mural.cluster_ca_certificate
}

provider "helm" {
  kubernetes = {
    host                   = kind_cluster.mural.endpoint
    client_certificate     = kind_cluster.mural.client_certificate
    client_key             = kind_cluster.mural.client_key
    cluster_ca_certificate = kind_cluster.mural.cluster_ca_certificate
  }
}

