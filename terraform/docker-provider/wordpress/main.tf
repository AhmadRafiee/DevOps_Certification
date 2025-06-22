provider "docker" {
  host = "unix:///var/run/docker.sock"
}

resource "docker_network" "network" {
  name = var.network_name
}

resource "docker_volume" "db_volume" {
  name = var.db_volume
}

resource "docker_volume" "wp_volume" {
  name = var.wp_volume
}

resource "docker_container" "mysql" {
  image = var.db_image
  name  = var.db_container_name
  hostname = var.db_hostname
  env = [
    "MYSQL_ROOT_PASSWORD=var.db_rootpaas",
    "MYSQL_DATABASE=var.db_database",
    "MYSQL_USER=var.db_username",
    "MYSQL_PASSWORD=var.db_password"
  ]
  networks_advanced {
    name = docker_network.network.name
  }
  volumes {
    volume_name = docker_volume.db_volume.name
    container_path = var.db_mount_path
  }
}

resource "docker_container" "wordpress" {
  image = var.wp_image
  name  = var.wp_container_name
  hostname = var.wp_hostname
  depends_on = [docker_container.mysql]

  env = [
    "WORDPRESS_DB_HOST=var.db_container_name:3306",
    "WORDPRESS_DB_USER=var.db_username",
    "WORDPRESS_DB_PASSWORD=var.db_password",
    "WORDPRESS_DB_NAME=var.db_database"
  ]

  networks_advanced {
    name = docker_network.network.name
  }

  ports {
    internal = 80
    external = 8080
  }
  volumes {
    volume_name = docker_volume.wp_volume.name
    container_path = var.wp_mount_path
  }
}