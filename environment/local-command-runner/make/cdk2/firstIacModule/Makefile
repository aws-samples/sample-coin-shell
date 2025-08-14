
# Resolves all environment variables and executes "cdk diff" 
# for the COIN_IAC_FIRST_MODULE_PLACEHOLDER module
# Takes an optional "args" parameter if you want to add additional arguments to pass to CDK
# usage: 
#   make diff-COIN_IAC_FIRST_MODULE_PLACEHOLDER
#   OR
#   make diff-COIN_IAC_FIRST_MODULE_PLACEHOLDER args="myStackId --exclusively"
diff-COIN_IAC_FIRST_MODULE_PLACEHOLDER:
	CDK_MODE=diff $(ENV_PATH)utility-functions.sh exec_cdk_for_env COIN_IAC_FIRST_MODULE_PLACEHOLDER "$(args)"

# Resolves all environment variables and executes "cdk deploy" 
# for the COIN_IAC_FIRST_MODULE_PLACEHOLDER module
# Takes an optional "args" parameter if you want to add additional arguments to pass to CDK
# usage: 
#   make deploy-COIN_IAC_FIRST_MODULE_PLACEHOLDER
#   OR
#   make deploy-COIN_IAC_FIRST_MODULE_PLACEHOLDER args="myStackId --exclusively"
deploy-COIN_IAC_FIRST_MODULE_PLACEHOLDER:
	$(ENV_PATH)utility-functions.sh exec_cdk_for_env COIN_IAC_FIRST_MODULE_PLACEHOLDER "$(args)"

# Same as deploy-COIN_IAC_FIRST_MODULE_PLACEHOLDER but targets the secondary region instead of the primary region
# Takes an optional "args" parameter if you want to add additional arguments to pass to CDK
# usage: 
#   make deploy-COIN_IAC_FIRST_MODULE_PLACEHOLDER-secondary-region
#   OR
#   make deploy-COIN_IAC_FIRST_MODULE_PLACEHOLDER-secondary-region args="myStackId --exclusively"
deploy-COIN_IAC_FIRST_MODULE_PLACEHOLDER-secondary-region:
	COIN_OVERRIDE_AWS_DEFAULT_REGION=$(AWS_SECONDARY_REGION) $(ENV_PATH)utility-functions.sh exec_cdk_for_env COIN_IAC_FIRST_MODULE_PLACEHOLDER "$(args)"

# Resolves all environment variables and executes "cdk destroy"
# for the COIN_IAC_FIRST_MODULE_PLACEHOLDER module
# Takes an optional "args" parameter if you want to add additional arguments to pass to CDK
# usage: 
#   make destroy-COIN_IAC_FIRST_MODULE_PLACEHOLDER
#   OR
#   make destroy-COIN_IAC_FIRST_MODULE_PLACEHOLDER args="myStackId --exclusively"
destroy-COIN_IAC_FIRST_MODULE_PLACEHOLDER:
	CDK_MODE=destroy $(ENV_PATH)utility-functions.sh exec_cdk_for_env COIN_IAC_FIRST_MODULE_PLACEHOLDER "$(args)"

# Deploy all targets in the correct order
deploy-all: deploy-COIN_IAC_FIRST_MODULE_PLACEHOLDER

# Destroy all targets in the correct order
destroy-all: destroy-COIN_IAC_FIRST_MODULE_PLACEHOLDER
