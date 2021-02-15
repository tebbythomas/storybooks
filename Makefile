PROJECT_ID=storybook-304512
ZONE=us-central1-a

run-local:
	docker-compose up 

###

create-tf-backend-bucket:
	gsutil mb -p $(PROJECT_ID) gs://$(PROJECT_ID)-terraform

###

define get-secret
$(shell gcloud secrets versions access latest --secret=$(1) --project=$(PROJECT_ID))
endef

###

ENV=staging

terraform-create-workspace:
	cd terraform && \
		terraform workspace new $(ENV)

terraform-init:
	cd terraform && \
		terraform workspace select $(ENV) && \
		terraform init

terraform-plan:
	cd terraform && \
		terraform workspace select $(ENV) && \
		terraform plan \
		-var-file="./environments/common.tfvars" \
		-var-file="./environments/$(ENV)/config.tfvars"

TF_ACTION?=plan
terraform-action:
	cd terraform && \
		terraform workspace select $(ENV) && \
		terraform $(TF_ACTION) \
		-var-file="./environments/common.tfvars" \
		-var-file="./environments/$(ENV)/config.tfvars" \
		-var="mongodbatlas_private_key=$(call get-secret,atlas_private_key)" \
		-var="atlas_user_password=$(call get-secret,atlas_user_password_$(ENV))" \
		-var="cloudflare_api_token=$(call get-secret,cloudflare_api_token)"

###

SSH_STRING=tebbyt@storybooks-vm-$(ENV)

GITHUB_SHA?=latest
LOCAL_TAG=storybooks-app:$(GITHUB_SHA)
REMOTE_TAG=gcr.io/$(PROJECT_ID)/$(LOCAL_TAG)

CONTAINER_NAME=storybooks-api
DB_NAME=storybooks

ssh:
	gcloud compute ssh $(SSH_STRING) \
		--project=$(PROJECT_ID) \
		--zone=$(ZONE)

ssh-cmd:
	@gcloud compute ssh $(SSH_STRING) \
		--project=$(PROJECT_ID) \
		--zone=$(ZONE) \
		--command="$(CMD)"

build:
	docker build -t $(LOCAL_TAG) .

push:
	docker tag $(LOCAL_TAG) $(REMOTE_TAG)
	docker push $(REMOTE_TAG)

deploy:
	$(MAKE) ssh-cmd CMD='docker-credential-gcr configure-docker'
	@echo "pulling new container image..."
	$(MAKE) ssh-cmd CMD='docker pull $(REMOTE_TAG)'
	@echo "removing old container..."
	-$(MAKE) ssh-cmd CMD='docker container stop $(CONTAINER_NAME)'
	-$(MAKE) ssh-cmd CMD='docker container rm $(CONTAINER_NAME)'
	@echo "starting new container..."
	@$(MAKE) ssh-cmd CMD='\
		docker run -d --name=$(CONTAINER_NAME) \
			--restart=unless-stopped \
			-p 80:3000 \
			-e PORT=3000 \
			-e \"MONGO_URI=mongodb+srv://storybooks-user-$(ENV):$(call get-secret,atlas_user_password_$(ENV))@storybooks-$(ENV).8ypda.mongodb.net/$(DB_NAME)?retryWrites=true&w=majority\" \
			-e GOOGLE_CLIENT_ID=481090005752-4b4jvcal7to6bivfgi1o8d4cnf1k8nr4.apps.googleusercontent.com \
			-e GOOGLE_CLIENT_SECRET=$(call get-secret,google_oauth_client_secret) \
			$(REMOTE_TAG) \
			'