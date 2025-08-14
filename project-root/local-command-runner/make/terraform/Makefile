
deploy-COIN_IAC_FIRST_MODULE_PLACEHOLDER:
	@echo "Deploying COIN_IAC_FIRST_MODULE_PLACEHOLDER module"
	(cd iac/roots/COIN_IAC_FIRST_MODULE_PLACEHOLDER; \
		terraform init; \
		terraform apply -auto-approve;)
	@echo "Finished Deploying COIN_IAC_FIRST_MODULE_PLACEHOLDER module"

destroy-COIN_IAC_FIRST_MODULE_PLACEHOLDER:
	@echo "Destroying COIN_IAC_FIRST_MODULE_PLACEHOLDER module"
	(cd iac/roots/COIN_IAC_FIRST_MODULE_PLACEHOLDER; \
		terraform init; \
		terraform destroy -auto-approve;)
	@echo "Finished Destroying COIN_IAC_FIRST_MODULE_PLACEHOLDER module"

# Deploy all targets in the correct order
deploy-all: deploy-COIN_IAC_FIRST_MODULE_PLACEHOLDER

# Destroy all targets in the correct order
destroy-all: destroy-COIN_IAC_FIRST_MODULE_PLACEHOLDER
