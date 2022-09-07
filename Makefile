DOMAIN=lark.dog

GCP_PROJECT_ID=lark-dog
GCP_REGION=us-west1
GCP_ZONE=$(GCP_REGION)-b
GCP_INSTANCE_NAME=lark-dog
GCP_REPO_SERVER=$(GCP_REGION)-docker.pkg.dev
GCP_ARTIFACT_REPO_ID=docker
GCP_REPO_PATH=$(GCP_REPO_SERVER)/$(GCP_PROJECT_ID)/$(GCP_ARTIFACT_REPO_ID)


define get-secret
$(shell gcloud secrets versions access latest --secret=$(1) --project=$(GCP_PROJECT_ID))
endef

define get-ipv4
$(shell curl -s http://whatismyip.akamai.com/)
endef

terraform-init:
	cd terraform && \
		terraform init

TF_ACTION?=plan
terraform-action:
	@cd terraform && \
		terraform $(TF_ACTION) \
		-var="gcp_project_id=$(GCP_PROJECT_ID)" \
		-var="gcp_region=$(GCP_REGION)" \
		-var="gcp_zone=$(GCP_ZONE)" \
		-var="gcp_instance_name=$(GCP_INSTANCE_NAME)" \
		-var="gcp_artifact_repo_id=$(GCP_ARTIFACT_REPO_ID)" \
		-var="namecheap_username=$(call get-secret,namecheap_username)" \
		-var="namecheap_token=$(call get-secret,namecheap_token)" \
		-var="namecheap_ip=$(call get-ipv4)" \
		-var="namecheap_domain=$(DOMAIN)"

###

SSH_STRING=ben@$(GCP_INSTANCE_NAME)

ssh:
	gcloud compute ssh $(SSH_STRING) \
		--project=$(GCP_PROJECT_ID) \
		--zone=$(GCP_ZONE)

ssh-cmd:
	@gcloud compute ssh $(SSH_STRING) \
		--project=$(GCP_PROJECT_ID) \
		--zone=$(GCP_ZONE) \
		--command="$(CMD)"

###

build:
	rm -rf build
	git clone --branch release --depth 1 git@github.com:photoprism/photoprism.git build
	git apply --directory=build photoprism/webdav.patch
	$(MAKE) -C build docker-local

REMOTE_PHOTOPRISM_TAG=$(GCP_REPO_PATH)/photoprism:latest
push:
	docker tag photoprism/photoprism:local $(REMOTE_PHOTOPRISM_TAG)
	docker push $(REMOTE_PHOTOPRISM_TAG)

###

# this only needs to be run one time on a new instance
# TODO: see if this can be migrated to cloud-init.conf
# sudo -u ben gcloud --quiet auth configure-docker $(GCP_REPO_SERVER)
config-server:
	$(MAKE) ssh-cmd CMD='gcloud --quiet auth configure-docker $(GCP_REPO_SERVER)'

update-config:
	gcloud compute scp docker-compose.yml $(GCP_INSTANCE_NAME):~/$(GCP_PROJECT_ID) \
		--project=$(GCP_PROJECT_ID) \
		--zone=$(GCP_ZONE)
	gcloud compute scp swag/lark-dog.conf $(GCP_INSTANCE_NAME):~/data/swag/nginx/site-confs \
		--project=$(GCP_PROJECT_ID) \
		--zone=$(GCP_ZONE)
	gcloud compute scp photoprism/settings.yml $(GCP_INSTANCE_NAME):~/data/photoprism/storage/config \
		--project=$(GCP_PROJECT_ID) \
		--zone=$(GCP_ZONE)

deploy: update-config docker-pull docker-up docker-prune

docker-pull:
	$(MAKE) ssh-cmd CMD='\
		cd $(GCP_PROJECT_ID) && \
		DOMAIN=$(DOMAIN) \
		GCP_REPO_PATH=$(GCP_REPO_PATH) \
		sudo -E docker-compose pull'

docker-up:
	@$(MAKE) ssh-cmd CMD='\
		cd $(GCP_PROJECT_ID) && \
		DOMAIN=$(DOMAIN) \
		GCP_REPO_PATH=$(GCP_REPO_PATH) \
		PHOTOPRISM_ADMIN_PASSWORD=$(call get-secret,photoprism_admin_password) \
		sudo -E docker-compose up -d'

docker-down:
	$(MAKE) ssh-cmd CMD='\
		cd $(GCP_PROJECT_ID) && \
		DOMAIN=$(DOMAIN) \
		GCP_REPO_PATH=$(GCP_REPO_PATH) \
		sudo -E docker-compose down'

docker-prune:
	$(MAKE) ssh-cmd CMD='sudo docker system prune -a -f'

photoprism-index:
	$(MAKE) ssh-cmd CMD='\
		sudo docker exec -d photoprism photoprism index'
