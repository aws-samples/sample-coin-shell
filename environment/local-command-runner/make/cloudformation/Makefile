

deploy-COIN_IAC_FIRST_MODULE_PLACEHOLDER: ## CF deploy on the COIN_IAC_FIRST_MODULE_PLACEHOLDER module
	@$(ENV_PATH)utility-functions.sh exec_cf_for_env COIN_IAC_FIRST_MODULE_PLACEHOLDER

destroy-COIN_IAC_FIRST_MODULE_PLACEHOLDER: ## CF destroy on the COIN_IAC_FIRST_MODULE_PLACEHOLDER module
	@$(ENV_PATH)utility-functions.sh destroy_root_cf_stack_by_name COIN_IAC_FIRST_MODULE_PLACEHOLDER

# Deploy all targets in the correct order
deploy-all: deploy-COIN_IAC_FIRST_MODULE_PLACEHOLDER ## Deploy all targets in the correct order

# Destroy all targets in the correct order
destroy-all: destroy-COIN_IAC_FIRST_MODULE_PLACEHOLDER ## Destroy all targets in the correct order
