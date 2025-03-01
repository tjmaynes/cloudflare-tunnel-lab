terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.1.0"
    }

    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }

    random = {
      source = "hashicorp/random"
    }
  }

  required_version = ">= 1.2"
}

variable "cloudflare_zone" {
  description = "Domain for cloudflare tunnel"
  type        = string
}

variable "cloudflare_account_id" {
  description = "value"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "value"
  type        = string
}

variable "cloudflare_api_token" {
  description = "API token for making changes to cloudflare tunnel"
  type        = string
}

variable "cloudflare_email_list" {
  description = "Accepted email access list"
  type        = list(string)
}

variable "cloudflare_zero_trust_team_name" {
  description = "Team name used for your cloudflare zero trust setup"
  type        = string
}

variable "cloudflare_tunnel_data_directory" {
  description = "Directory for storing cloudflared data files"
  type        = string
}

variable "lab_config_file" {
  description = "Lab config file location"
  type        = string
}

locals {
  raw_lab_config_file = jsondecode(file(var.lab_config_file))
  raw_tunnel_apps     = [for s in local.raw_lab_config_file["services"] : s if s["expose"] == true]
  tunnel_apps = [
    for app in local.raw_tunnel_apps : {
      hostname     = "${app["name"]}.${var.cloudflare_zone}"
      internal_url = "http://${app["name"]}:${app["expose_port"]}"
    }
  ]
  docker_containers = [
    for service in local.raw_lab_config_file["services"] : {
      name    = service["name"],
      image   = service["image"],
      restart = service["restart"],
      ports = [
        for port_set in service["ports"] : {
          external = split(":", port_set)[0],
          internal = split(":", port_set)[1],
        }
      ],
      volumes = [
        for volume_mount in service["volumes"] : {
          host_path      = split(":", volume_mount)[0]
          container_path = split(":", volume_mount)[1]
        }
      ]
      environment_variables = [for key, value in lookup(service, "environment", []) : "${key}=${value}"]
    }
  ]
  ingress_rules = [
    for app in local.tunnel_apps : {
      hostname = app.hostname
      service  = app.internal_url
      origin_request = {
        access = {
          required        = true
          team_name       = var.cloudflare_zero_trust_team_name
          connect_timeout = 3600
          aud_tag = [
            cloudflare_zero_trust_access_application.lab_apps[
              index(cloudflare_zero_trust_access_application.lab_apps.*.name, app.hostname)
            ].aud
          ]
        }
      }
    }
  ]
  http_policy_allowed_emails = [
    for allowed_email in var.cloudflare_email_list : {
      email = {
        email = allowed_email
      }
    }
  ]
  cf_tunnel_secret = jsonencode({
    "AccountTag" : var.cloudflare_account_id,
    "TunnelName" : cloudflare_zero_trust_tunnel_cloudflared.lab_tunnel.name,
    "TunnelID" : cloudflare_zero_trust_tunnel_cloudflared.lab_tunnel.id
    "TunnelSecret" : base64sha256(random_password.tunnel_secret.result),
  })
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "random" {}

# Generates a 64-character secret for the tunnel.
# Using `random_password` means the result is treated as sensitive and, thus,
# not displayed in console output. Refer to: https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password
resource "random_password" "tunnel_secret" {
  length = 64
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "lab_tunnel" {
  account_id    = var.cloudflare_account_id
  name          = "Terraform Lab tunnel"
  tunnel_secret = base64sha256(random_password.tunnel_secret.result)
}

# Creates the configuration for the tunnel.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "lab_tunnel" {
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.lab_tunnel.id
  account_id = var.cloudflare_account_id
  config = {
    ingress = concat(local.ingress_rules, [{
      service = "http_status:404"
    }])
  }
}

# Creates the CNAME record that routes http_app.${var.cloudflare_zone} to the tunnel.
resource "cloudflare_dns_record" "lab_apps" {
  count = length(local.tunnel_apps)

  zone_id = var.cloudflare_zone_id
  name    = local.tunnel_apps[count.index].hostname
  content = join(".", [cloudflare_zero_trust_tunnel_cloudflared.lab_tunnel.id, "cfargotunnel.com"])
  type    = "CNAME"
  proxied = true
  ttl     = 1

  depends_on = [
    cloudflare_zero_trust_tunnel_cloudflared_config.lab_tunnel
  ]
}

# Creates an Access policy for the application.
resource "cloudflare_zero_trust_access_policy" "ai_lab_http_policy" {
  account_id = var.cloudflare_account_id
  name       = "Cloudflare Tunnel Lab"
  decision   = "allow"
  include    = local.http_policy_allowed_emails
}

# Creates an Access application to control who can connect.
resource "cloudflare_zero_trust_access_application" "lab_apps" {
  count = length(local.tunnel_apps)

  type    = "self_hosted"
  zone_id = var.cloudflare_zone_id
  name    = local.tunnel_apps[count.index].hostname
  domain  = local.tunnel_apps[count.index].hostname
  policies = [{
    id          = cloudflare_zero_trust_access_policy.ai_lab_http_policy.id
    name        = cloudflare_zero_trust_access_policy.ai_lab_http_policy.name
    decision    = "allow"
    precendence = 1
  }]
  session_duration = "1h"

  depends_on = [
    cloudflare_zero_trust_access_policy.ai_lab_http_policy
  ]
}

resource "local_file" "app_config" {
  filename = "${var.cloudflare_tunnel_data_directory}/creds/credentials.json"
  content  = local.cf_tunnel_secret
}

resource "docker_image" "cloudflared" {
  name = "cloudflare/cloudflared:latest"
}

resource "docker_network" "cloudflared_network" {
  name = "cloudflared_network"
}

resource "docker_container" "cloudflared_container" {
  name    = "cloudflared_tunnel"
  image   = docker_image.cloudflared.image_id
  restart = "always"

  command = [
    "tunnel", "--credentials-file", "/etc/cloudflared/creds/credentials.json",
    "run", cloudflare_zero_trust_tunnel_cloudflared.lab_tunnel.name
  ]

  volumes {
    host_path      = var.cloudflare_tunnel_data_directory
    container_path = "/etc/cloudflared"
    read_only      = false
  }

  networks_advanced {
    name = docker_network.cloudflared_network.name
  }

  depends_on = [
    cloudflare_zero_trust_tunnel_cloudflared.lab_tunnel
  ]
}

resource "docker_container" "lab_containers" {
  count = length(local.docker_containers)

  image = local.docker_containers[count.index].image
  name  = local.docker_containers[count.index].name
  env   = local.docker_containers[count.index].environment_variables

  networks_advanced {
    name = docker_network.cloudflared_network.name
  }

  dynamic "ports" {
    for_each = local.docker_containers[count.index].ports
    content {
      internal = ports.value.internal
      external = ports.value.external
    }
  }

  dynamic "volumes" {
    for_each = local.docker_containers[count.index].volumes
    content {
      host_path      = volumes.value.host_path
      container_path = volumes.value.container_path
      read_only      = false
    }
  }
}