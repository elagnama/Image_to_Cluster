packer {
  required_plugins {
    docker = {
      version = ">= 0.0.7"
      source  = "github.com/hashicorp/docker"
    }
  }
}

source "docker" "nginx" {
  image  = "nginx:alpine"
  commit = true
  changes = [
    "EXPOSE 80",
    # On réinitialise proprement la commande de lancement
    "ENTRYPOINT [\"nginx\"]",
    "CMD [\"-g\", \"daemon off;\"]"
  ]
}

build {
  sources = ["source.docker.nginx"]

  provisioner "file" {
    source      = "index.html"
    destination = "/tmp/index.html"
  }

  provisioner "shell" {
    inline = [
      "mkdir -p /usr/share/nginx/html",
      "mv /tmp/index.html /usr/share/nginx/html/index.html",
      "chmod 644 /usr/share/nginx/html/index.html"
    ]
  }

  post-processor "docker-tag" {
    repository = "my-nginx-custom"
    tags       = ["latest"]
  }
}