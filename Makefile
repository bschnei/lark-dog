DOMAIN=lark.dog

GCP_PROJECT_ID=lark-dog
GCP_ZONE=us-central1-a
GCP_INSTANCE_NAME=web-server

run-local:
	docker-compose -f docker-compose.local.yml up

###

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
		-var="gcp_instance_name=$(GCP_INSTANCE_NAME)" \
		-var="namecheap_username=$(call get-secret,namecheap_username)" \
		-var="namecheap_token=$(call get-secret,namecheap_token)" \
		-var="namecheap_ip=$(call get-ipv4)"

###

SSH_STRING=ben@$(GCP_INSTANCE_NAME)

sleep:
	gcloud compute instances stop $(GCP_INSTANCE_NAME) \
		--project=$(GCP_PROJECT_ID) \
		--zone=$(GCP_ZONE)

ssh:
	gcloud compute ssh $(SSH_STRING) \
		--project=$(GCP_PROJECT_ID) \
		--zone=$(GCP_ZONE)

ssh-cmd:
	@gcloud compute ssh $(SSH_STRING) \
		--project=$(GCP_PROJECT_ID) \
		--zone=$(GCP_ZONE) \
		--command="$(CMD)"

wake:
	gcloud compute instances start $(GCP_INSTANCE_NAME) \
		--project=$(GCP_PROJECT_ID) \
		--zone=$(GCP_ZONE)

LOCAL_SWAG_TAG=swag:latest
REMOTE_SWAG_TAG=gcr.io/$(GCP_PROJECT_ID)/$(LOCAL_SWAG_TAG)

build:
	docker build -t $(LOCAL_SWAG_TAG) ./swag

push:
	docker tag $(LOCAL_SWAG_TAG) $(REMOTE_SWAG_TAG)
	docker push $(REMOTE_SWAG_TAG)

# this only needs to be run one time on a new instance
config:
#	$(MAKE) ssh-cmd CMD='curl -sSO https://dl.google.com/cloudagents/add-monitoring-agent-repo.sh && sudo bash add-monitoring-agent-repo.sh --also-install && sudo service stackdriver-agent start'
	$(MAKE) ssh-cmd CMD='gcloud --quiet auth configure-docker'
	-$(MAKE) ssh-cmd CMD='mkdir import'
	-$(MAKE) ssh-cmd CMD='mkdir -p ~/storage/config'
	gcloud compute scp settings.yml $(GCP_INSTANCE_NAME):~/storage/config \
		--project=$(GCP_PROJECT_ID) \
		--zone=$(GCP_ZONE)

deploy:
	gcloud compute scp docker-compose.yml $(GCP_INSTANCE_NAME):~ \
		--project=$(GCP_PROJECT_ID) \
		--zone=$(GCP_ZONE)
	$(MAKE) ssh-cmd CMD='\
		DOMAIN=$(DOMAIN) \
		GCP_PROJECT_ID=$(GCP_PROJECT_ID) \
		docker-compose pull'
	@$(MAKE) ssh-cmd CMD='\
		DOMAIN=$(DOMAIN) \
		GCP_PROJECT_ID=$(GCP_PROJECT_ID) \
		PHOTOPRISM_ADMIN_PASSWORD=$(call get-secret,photoprism_admin_password) \
		MARIADB_ROOT_PASSWORD=$(call get-secret,mariadb_root_password) \
		MARIADB_PASSWORD=$(call get-secret,mariadb_password) \
		docker-compose up -d'
	$(MAKE) ssh-cmd CMD='docker system prune -a -f'
