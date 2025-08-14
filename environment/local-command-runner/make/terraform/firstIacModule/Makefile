

# Resolves all environment variables in template files, executes "terraform plan" 
# for the COIN_IAC_FIRST_MODULE_PLACEHOLDER module, then restores template files to their original content
# Takes an optional "args" parameter if you want to add additional arguments to pass to terraform
# usage: 
#   plan-COIN_IAC_FIRST_MODULE_PLACEHOLDER
#   OR
#   make plan-COIN_IAC_FIRST_MODULE_PLACEHOLDER args="-target module.mymodule"
plan-COIN_IAC_FIRST_MODULE_PLACEHOLDER:
	TF_MODE=plan $(ENV_PATH)utility-functions.sh exec_tf_for_env COIN_IAC_FIRST_MODULE_PLACEHOLDER "$(args)"

# Resolves all environment variables in template files, executes "terraform apply" 
# for the COIN_IAC_FIRST_MODULE_PLACEHOLDER module, then restores template files to their original content
# Takes an optional "args" parameter if you want to add additional arguments to pass to terraform
# usage: 
#   make deploy-COIN_IAC_FIRST_MODULE_PLACEHOLDER
#   OR
#   make deploy-COIN_IAC_FIRST_MODULE_PLACEHOLDER args="-target module.mymodule"
deploy-COIN_IAC_FIRST_MODULE_PLACEHOLDER:
	$(ENV_PATH)utility-functions.sh exec_tf_for_env COIN_IAC_FIRST_MODULE_PLACEHOLDER "$(args)"

# Resolves all environment variables in template files, executes "terraform destroy"
# for the COIN_IAC_FIRST_MODULE_PLACEHOLDER module, then restores template files to their original content
# Takes an optional "args" parameter if you want to add additional arguments to pass to terraform
# usage: 
#   make destroy-COIN_IAC_FIRST_MODULE_PLACEHOLDER
#   OR
#   make destroy-COIN_IAC_FIRST_MODULE_PLACEHOLDER args="-target module.mymodule"
destroy-COIN_IAC_FIRST_MODULE_PLACEHOLDER:
	TF_MODE=destroy $(ENV_PATH)utility-functions.sh exec_tf_for_env COIN_IAC_FIRST_MODULE_PLACEHOLDER "$(args)"

# Deploy all targets in the correct order
deploy-all: deploy-COIN_IAC_FIRST_MODULE_PLACEHOLDER

# Destroy all targets in the correct order
destroy-all: destroy-COIN_IAC_FIRST_MODULE_PLACEHOLDER
