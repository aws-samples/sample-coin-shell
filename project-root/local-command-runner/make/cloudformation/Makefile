
deploy-COIN_IAC_FIRST_MODULE_PLACEHOLDER:
	@echo "Deploying COIN_IAC_FIRST_MODULE_PLACEHOLDER module"
	(cd iac/roots/COIN_IAC_FIRST_MODULE_PLACEHOLDER; \
		aws cloudformation deploy \
		--template-file cf.yml \
		--parameter-overrides file://parameters.json \
		--stack-name $(APP_NAME)-$(ENV_NAME)-COIN_IAC_FIRST_MODULE_PLACEHOLDER \
		--region $(AWS_DEFAULT_REGION) \
		--capabilities CAPABILITY_NAMED_IAM \
		--tags App=$(APP_NAME) Env=$(ENV_NAME);)
	@echo "Finished Deploying COIN_IAC_FIRST_MODULE_PLACEHOLDER module"

destroy-COIN_IAC_FIRST_MODULE_PLACEHOLDER:
	@echo "Destroying COIN_IAC_FIRST_MODULE_PLACEHOLDER module"
	aws cloudformation delete-stack \
	--stack-name $(APP_NAME)-$(ENV_NAME)-COIN_IAC_FIRST_MODULE_PLACEHOLDER \
	--region $(AWS_DEFAULT_REGION)
	aws cloudformation wait stack-delete-complete \
	--stack-name $(APP_NAME)-$(ENV_NAME)-COIN_IAC_FIRST_MODULE_PLACEHOLDER \
	--region $(AWS_DEFAULT_REGION)
	@echo "Finished Destroying COIN_IAC_FIRST_MODULE_PLACEHOLDER module"

# Deploy all targets in the correct order
deploy-all: deploy-COIN_IAC_FIRST_MODULE_PLACEHOLDER

# Destroy all targets in the correct order
destroy-all: destroy-COIN_IAC_FIRST_MODULE_PLACEHOLDER
