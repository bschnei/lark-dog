DOMAIN=lark.dog

GCP_PROJECT_ID=lark-dog
GCP_REGION=us-west1
GCP_ZONE=$(GCP_REGION)-b
GCP_INSTANCE_NAME=web-server
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
		-var="namecheap_ip=$(call get-ipv4)"

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

LOCAL_SWAG_TAG=swag:latest
REMOTE_SWAG_TAG=$(GCP_REPO_PATH)/$(LOCAL_SWAG_TAG)
REMOTE_PHOTOPRISM_TAG=$(GCP_REPO_PATH)/photoprism:latest

build: build-swag build-photoprism

build-swag:
	docker build -t $(LOCAL_SWAG_TAG) ./swag

build-photoprism:
	rm -rf build
	git clone --branch release --depth 1 git@github.com:photoprism/photoprism.git build
	git apply --directory=build photoprism/webdav.patch
	$(MAKE) -C build docker-local

push: push-swag push-photoprism

push-swag:
	docker tag $(LOCAL_SWAG_TAG) $(REMOTE_SWAG_TAG)
	docker push $(REMOTE_SWAG_TAG)

push-photoprism:
	docker tag photoprism/photoprism:local $(REMOTE_PHOTOPRISM_TAG)
	docker push $(REMOTE_PHOTOPRISM_TAG)

###

# this only needs to be run one time on a new instance
config:
	$(MAKE) ssh-cmd CMD='gcloud --quiet auth configure-docker $(GCP_REPO_SERVER)'
	-$(MAKE) ssh-cmd CMD='mkdir import'
	-$(MAKE) ssh-cmd CMD='mkdir -p ~/storage/config'
	gcloud compute scp photoprism/settings.yml $(GCP_INSTANCE_NAME):~/storage/config \
		--project=$(GCP_PROJECT_ID) \
		--zone=$(GCP_ZONE)

docker-down:
	$(MAKE) ssh-cmd CMD='\
		DOMAIN=$(DOMAIN) \
		GCP_PROJECT_ID=$(GCP_PROJECT_ID) \
		docker-compose down'

deploy:
	gcloud compute scp docker-compose.yml $(GCP_INSTANCE_NAME):~ \
		--project=$(GCP_PROJECT_ID) \
		--zone=$(GCP_ZONE)
	$(MAKE) ssh-cmd CMD='\
		DOMAIN=$(DOMAIN) \
		GCP_REPO_PATH=$(GCP_REPO_PATH) \
		docker-compose pull'
	@$(MAKE) ssh-cmd CMD='\
		DOMAIN=$(DOMAIN) \
		GCP_REPO_PATH=$(GCP_REPO_PATH) \
		PHOTOPRISM_ADMIN_PASSWORD=$(call get-secret,photoprism_admin_password) \
		MARIADB_ROOT_PASSWORD=$(call get-secret,mariadb_root_password) \
		MARIADB_PASSWORD=$(call get-secret,mariadb_password) \
		docker-compose up -d'
	$(MAKE) ssh-cmd CMD='docker system prune -a -f'
