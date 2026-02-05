SHELL := /bin/bash
.PHONY: help install-all install-k3d create-cluster recreate-cluster install-packer install-packer-local install-ansible build-image import-image deploy kubectl-deploy port-forward clean all

# Variables
PACKER_FILE ?= packer.pkr.hcl
IMAGE_NAME ?= my-nginx-custom:latest
K3D_CLUSTER ?= lab

# Désactive les appels distants de télémétrie HashiCorp qui font parfois échouer Packer en CI/Local
export CHECKPOINT_DISABLE=1

help:
	@echo "Usage: make <target>"
	@echo "Targets:"
	@echo "  install-all        Install k3d, packer and ansible (requires sudo)"
	@echo "  create-cluster     Create k3d cluster ($(K3D_CLUSTER))"
	@echo "  build-image        Build Docker image with packer ($(PACKER_FILE))"
	@echo "  import-image       Import built image into k3d"
	@echo "  deploy             Apply k8s manifests"
	@echo "  clean              Remove temporary artifacts"


all: clean install-k3d install-packer install-ansible create-cluster build-image import-image deploy port-forward
run : clean create-cluster build-image import-image deploy port-forward

install-k3d:
	@echo "Installing k3d..."
	curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

clean:
	@echo "Cleaning up..."
	k3d cluster delete $(K3D_CLUSTER)

create-cluster:
	@echo "Creating k3d cluster '$(K3D_CLUSTER)'..."
	k3d cluster get $(K3D_CLUSTER) >/dev/null 2>&1 || \
	k3d cluster create $(K3D_CLUSTER) --servers 1 --agents 2
	kubectl cluster-info

install-ansible:
	@echo "Installing Ansible and python kubernetes library..."
	sudo apt-get update -y || true
	sudo apt-get install -y packer ansible python3-pip
	python3 -m pip install --user kubernetes
	ansible-galaxy collection install community.kubernetes

install-packer:
	@echo "Installing packer via HashiCorp APT repository..."
	sudo apt-get update -y && sudo apt-get install -y gnupg software-properties-common wget
	wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
	echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $$(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
	sudo apt-get update -y && sudo apt-get install -y packer
	packer version

build-image:
	@if [ ! -f "$(PACKER_FILE)" ]; then echo "❌ Error: $(PACKER_FILE) not found"; exit 1; fi
	@echo "Validating Packer template..."
	packer init $(PACKER_FILE)
	@echo "Initializing Packer plugins..."
	packer validate $(PACKER_FILE)
	@echo "Building image with Packer..."
	packer build -force $(PACKER_FILE)

import-image:
	@echo "Importing image $(IMAGE_NAME) into k3d..."
	k3d image import $(IMAGE_NAME) -c $(K3D_CLUSTER)

deploy:
	@echo "🤖 Déploiement Ansible..."
	ansible-playbook deploy.yml

# port-forward:
# 	@echo "Port-forwarding service on http://localhost:8080"
# 	@echo "Press Ctrl+C to stop."
# 	kubectl port-forward svc/nginx-service 8080:80
