import {
  to = mittwald_server.server
  id = var.server_id
}

data "mittwald_article" "server" {
  filter = {
    tags = ["vserver", "balance-optimized"]
    attributes = {
      "ram"  = "4"
      "vcpu" = "2"
    }
  }
}

resource mittwald_server "server" {
    customer_id = var.customer_id
    description = "Code for Bielefeld"
    article_id = data.mittwald_article.server.id
    diskspace_gb = 100
}

resource "mittwald_project" "baumbie" {
  server_id   = var.server_id
  description = "BaumBie"

  # A project's default ingress (and with it, the `default_ips` attribute) is
  # provisioned asynchronously. This usually takes just a few seconds -- the
  # timeouts below are upper bounds, not waiting times -- but if provisioning
  # regularly takes longer than the defaults, you can adjust them here.
  timeouts {
    create = "10m"
    read   = "2m"
  }
}

output "project_ips" {
  value = mittwald_project.baumbie.default_ips
}

output "hostname" {
  value = mittwald_virtualhost.supabase.hostname
}
