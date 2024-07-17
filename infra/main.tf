resource "google_compute_network" "network" {
  name                    = "cicd-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "cicd-subnet"
  ip_cidr_range = "192.168.0.0/24"
  region        = var.region
  network       = google_compute_network.network.id

  depends_on = [google_compute_network.network]
}

resource "google_compute_global_address" "private_ip" {
  name          = "cicd-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = "16"
  network       = google_compute_network.network.id

  depends_on = [google_compute_network.network]
}

resource "google_service_networking_connection" "connection" {
  network                 = google_compute_network.network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip.name]
  deletion_policy         = "ABANDON"

  depends_on = [google_compute_global_address.private_ip]
}

resource "google_sql_database_instance" "db_instance" {
  name             = "cicd-db-instance"
  database_version = "POSTGRES_13"
  region           = var.region

  settings {
    tier = "db-f1-micro"
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.network.id
    }
  }

  deletion_protection = false
  depends_on          = [google_service_networking_connection.connection]
}

resource "google_sql_database" "db" {
  name     = "cicd-db"
  instance = google_sql_database_instance.db_instance.name

  depends_on = [google_sql_database_instance.db_instance]
}

resource "google_sql_user" "db_user" {
  name     = "cicd-db-user"
  instance = google_sql_database_instance.db_instance.name
  password = var.db_password

  depends_on = [google_sql_database_instance.db_instance]
}

resource "google_artifact_registry_repository" "repository" {
  repository_id = "cicd-repository"
  format        = "DOCKER"
  location      = var.region
}

resource "google_vpc_access_connector" "connector" {
  name          = "cicd-vpc-connector"
  ip_cidr_range = "192.168.1.0/28"
  network       = google_compute_network.network.name

  depends_on = [google_compute_network.network]
}

resource "google_secret_manager_secret" "sm" {
  secret_id = "cicd-github-token"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "smv" {
  secret      = google_secret_manager_secret.sm.id
  secret_data = var.github_token

  depends_on = [google_secret_manager_secret.sm]
}

data "google_iam_policy" "secretAccessor" {
  binding {
    role    = "roles/secretmanager.secretAccessor"
    members = ["serviceAccount:service-${var.project_id}@gcp-sa-cloudbuild.iam.gserviceaccount.com"]
  }
}

resource "google_secret_manager_secret_iam_policy" "policy" {
  secret_id   = google_secret_manager_secret.sm.secret_id
  policy_data = data.google_iam_policy.secretAccessor.policy_data

  depends_on = [google_secret_manager_secret_version.smv]
}

resource "google_cloudbuildv2_connection" "connection" {
  location = var.region
  name     = "cicd-connection"

  github_config {
    app_installation_id = var.installation_id
    authorizer_credential {
      oauth_token_secret_version = google_secret_manager_secret_version.smv.id
    }
  }

  depends_on = [google_secret_manager_secret_iam_policy.policy]
}

resource "google_project_iam_member" "attach_permissions" {
  for_each = toset([
    "roles/run.admin",
    "roles/logging.logWriter",
    "roles/iam.serviceAccountUser",
    "roles/secretmanager.secretAccessor",
  ])
  role    = each.key
  project = var.project
  member  = "serviceAccount:${var.project_id}@cloudbuild.gserviceaccount.com"
}

resource "google_cloudbuild_trigger" "trigger" {
  name = "cicd-trigger"

  github {
    owner = var.github_owner
    name  = var.github_repository
    push {
      branch = "^main$"
    }
  }

  filename   = "cloudbuild.yml"
  depends_on = [google_cloudbuildv2_connection.connection]
}

resource "google_cloud_run_service" "service" {
  name     = "cicd-service"
  location = var.region

  template {
    spec {
      containers {
        image = "${var.region}-docker.pkg.dev/${var.project}/${google_artifact_registry_repository.repository.repository_id}/cicd-application:latest"

        env {
          name  = "DB_HOST"
          value = google_sql_database_instance.db_instance.private_ip_address
        }
        env {
          name  = "DB_USER"
          value = google_sql_user.db_user.name
        }
        env {
          name  = "DB_NAME"
          value = google_sql_database.db.name
        }
        env {
          name  = "DB_PORT"
          value = "5432"
        }
        env {
          name  = "DB_PASSWORD"
          value = var.db_password
        }
      }
    }

    metadata {
      annotations = {
        "run.googleapis.com/vpc-access-egress"    = "all-traffic"
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.connector.name
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    google_artifact_registry_repository.repository,
    google_sql_database.db,
    google_vpc_access_connector.connector,
  ]
}