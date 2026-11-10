.PHONY: up down plan status tools-build tools-up tools-down docker-init docker-up docker-plan docker-status docker-load docker-down docker-shell

TF := terraform -chdir=infra/terraform

up:
	$(TF) init
	$(TF) apply

plan:
	$(TF) plan

status:
	kubectl --kubeconfig infra/terraform/.kubeconfig -n mural get pods,jobs,pvc,ingress

down:
	$(TF) destroy

# Builds the toolbox explicitly after Dockerfile/tool version changes.
tools-build:
	docker compose -f docker-compose.tools.yml build

# Ensures the toolbox is running. Compose builds it automatically if the image
# does not exist, but does not rebuild/recreate it during every Terraform plan.
tools-up:
	docker compose -f docker-compose.tools.yml up -d --wait

tools-down:
	docker compose -f docker-compose.tools.yml down

docker-init: tools-up
	docker compose -f docker-compose.tools.yml exec infra terraform -chdir=infra/terraform init

docker-up: docker-init
	docker compose -f docker-compose.tools.yml exec infra terraform -chdir=infra/terraform apply

docker-plan: docker-init
	docker compose -f docker-compose.tools.yml exec infra terraform -chdir=infra/terraform plan

docker-status: tools-up
	docker compose -f docker-compose.tools.yml exec infra kubectl --kubeconfig infra/terraform/.kubeconfig -n mural get pods,jobs,pvc,ingress,hpa

docker-load: tools-up
	docker compose -f docker-compose.tools.yml exec infra sh infra/load-test/run.sh

docker-down: docker-init
	docker compose -f docker-compose.tools.yml exec infra terraform -chdir=infra/terraform destroy

docker-shell: tools-up
	docker compose -f docker-compose.tools.yml exec infra bash

