DOMAIN=lark.dog

# specific upstream release tag to download, patch, and build
PHOTOPRISM_RELEASE_TAG=231128-f48ff16ef

GCP_PROJECT_ID=lark-dog
GCP_REGION=us-west1
GCP_ZONE=$(GCP_REGION)-b
GCP_INSTANCE_NAME=lark-dog
GCP_REPO_SERVER=$(GCP_REGION)-docker.pkg.dev
GCP_ARTIFACT_REPO_ID=docker
GCP_REPO_PATH=$(GCP_REPO_SERVER)/$(GCP_PROJECT_ID)/$(GCP_ARTIFACT_REPO_ID)
GCP_PHOTOPRISM_TAG=$(GCP_REPO_PATH)/photoprism:$(PHOTOPRISM_RELEASE_TAG)

define get-secret
$(shell gcloud secrets versions access latest --secret=$(1) --project=$(GCP_PROJECT_ID))
endef

define get-ipv4
$(shell curl -s http://whatismyip.akamai.com/)
endef

define get-photoprism-latest-release-tag
$(shell curl -sL https://api.github.com/repos/photoprism/photoprism/releases/latest | jq -r ".tag_name")
endef

terraform-init:
	cd terraform && \
		terraform init -upgrade

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

# notify if a newer release is available, download source and apply patch
# NOTE: building a photoprism docker image from pure source code instead of a git repo fails (20221105)
photoprism-source:
    ifneq ($(call get-photoprism-latest-release-tag), $(PHOTOPRISM_RELEASE_TAG))
		@echo "newer PhotoPrism release is available! ($(call get-photoprism-latest-release-tag))"
    endif
	@rm -rf photoprism/source
	git clone --depth 1 --branch $(PHOTOPRISM_RELEASE_TAG) git@github.com:photoprism/photoprism.git photoprism/source
	@patch -u photoprism/source/internal/config/config_features.go -i photoprism/webdav.patch

photoprism-image:
	$(MAKE) -C photoprism/source docker-local
	docker tag photoprism/photoprism:local $(GCP_PHOTOPRISM_TAG)

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

delete-server:
	gcloud compute instances delete $(GCP_INSTANCE_NAME) \
		--project=$(GCP_PROJECT_ID) \
		--zone=$(GCP_ZONE)

deploy: update-config docker-pull docker-up docker-prune

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

docker-pull:
	docker push $(GCP_PHOTOPRISM_TAG)
	$(MAKE) ssh-cmd CMD='\
		cd $(GCP_PROJECT_ID) && \
		DOMAIN=$(DOMAIN) \
		GCP_PHOTOPRISM_TAG=$(GCP_PHOTOPRISM_TAG) \
		sudo -E docker compose pull'

docker-up:
	@$(MAKE) ssh-cmd CMD='\
		cd $(GCP_PROJECT_ID) && \
		DOMAIN=$(DOMAIN) \
		GCP_PHOTOPRISM_TAG=$(GCP_PHOTOPRISM_TAG) \
		PHOTOPRISM_ADMIN_PASSWORD=$(call get-secret,photoprism_admin_password) \
		sudo -E docker compose up -d'

docker-down:
	$(MAKE) ssh-cmd CMD='\
		cd $(GCP_PROJECT_ID) && \
		DOMAIN=$(DOMAIN) \
		GCP_PHOTOPRISM_TAG=$(GCP_PHOTOPRISM_TAG) \
		sudo -E docker compose down'

docker-prune:
	$(MAKE) ssh-cmd CMD='sudo docker system prune -a -f'

photoprism-index:
	$(MAKE) ssh-cmd CMD='\
		sudo docker exec -d photoprism photoprism index'
