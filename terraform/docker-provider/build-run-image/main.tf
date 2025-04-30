provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# Create Docker Image from Dockerfile
resource "docker_image" "my_image" {
  name         = var.image_name
  build {
    context    = "${path.module}"
    dockerfile = "${path.module}/Dockerfile"
  }
    triggers = {
    dockerfile_hash = filemd5("${path.module}/Dockerfile")
  }
}

# Create Nginx Container with the built image
resource "docker_container" "web" {
  image = docker_image.my_image.name
  name  = var.container_name
  ports {
    internal = 80
    external = 80
  }
}