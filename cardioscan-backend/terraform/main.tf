terraform {
  required_providers {
    neon = {
      source  = "kislerdm/neon"
      version = "~> 0.6"
    }
  }
}

provider "neon" {
  api_key = var.neon_api_key
}

resource "neon_project" "cardioscan" {
  name      = "cardioscan"
  region_id = var.neon_region
}

resource "neon_role" "app_user" {
  project_id = neon_project.cardioscan.id
  branch_id  = neon_project.cardioscan.default_branch_id
  name       = "cardioscan_app"
}

resource "neon_database" "cardioscan" {
  project_id = neon_project.cardioscan.id
  branch_id  = neon_project.cardioscan.default_branch_id
  name       = "cardioscan"
  owner_name = neon_role.app_user.name
}

output "database_url" {
  value     = "postgresql://${neon_role.app_user.name}:${neon_role.app_user.password}@${neon_project.cardioscan.database_host}/${neon_database.cardioscan.name}?sslmode=require"
  sensitive = true
}
