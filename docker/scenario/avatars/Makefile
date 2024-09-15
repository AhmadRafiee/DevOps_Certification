KUBE_CONTEXT ?= $(shell kubectl config current-context)
DD_KUBERNETES = $(shell kubectl config get-contexts docker-desktop -o=name 2>/dev/null)

.PHONY: tilt compose kubernetes down

help:
	@echo "make tilt       -- deploy demo with Tilt & Kubernetes"
	@echo "make compose    -- deploy demo with Compose & Docker"
	@echo "make kubernetes -- deploy demo with Kubernetes"

tilt:
	tilt up

compose:
	docker compose watch

kubernetes:
ifeq ($(DD_KUBERNETES),)
	$(error Docker Desktop Kubernetes integration is not enabled)
endif
	@echo "Building images..."
	docker --context=desktop-linux buildx bake --load
	@echo "Deploying resources..."
	kubectl --context=docker-desktop --namespace=avatars apply \
		-f ./deploy/docker-desktop.yaml \
		-f ./deploy/api.yaml \
		-f ./deploy/web.yaml

down:
	docker compose down --timeout=0 --volumes --remove-orphans
	tilt down
ifneq ($(DD_KUBERNETES),)
	kubectl --context=docker-desktop delete namespace avatars --ignore-not-found=true
endif
