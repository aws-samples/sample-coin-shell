
deploy-cdk2-bootstrap-cf-stack:
	cdk bootstrap "aws://$(AWS_ACCOUNT_ID)/$(AWS_DEFAULT_REGION)"

destroy-cdk2-bootstrap-cf-stack:
	aws cloudformation delete-stack \
	--stack-name CDKToolkit \
	--region $(AWS_DEFAULT_REGION)
	aws cloudformation wait stack-delete-complete \
	--stack-name CDKToolkit \
	--region $(AWS_DEFAULT_REGION)

deploy-COIN_IAC_FIRST_MODULE_PLACEHOLDER:
	@echo "Deploying COIN_IAC_FIRST_MODULE_PLACEHOLDER module"
	@(\
		. ./set-env-vars.sh; \
	 	cd iac/roots/COIN_IAC_FIRST_MODULE_PLACEHOLDER; \
		npm install; \
		cdk deploy --require-approval never \
	)
	@echo "Finished deploying COIN_IAC_FIRST_MODULE_PLACEHOLDER module"

destroy-COIN_IAC_FIRST_MODULE_PLACEHOLDER:
	@echo "Destroying COIN_IAC_FIRST_MODULE_PLACEHOLDER module"
	@(\
	  . ./set-env-vars.sh; \
	  cd iac/roots/COIN_IAC_FIRST_MODULE_PLACEHOLDER; \
	  npm install; \
	  cdk destroy --force \
	)
	@echo "Finished destroying COIN_IAC_FIRST_MODULE_PLACEHOLDER module"

# Deploy all targets in the correct order
deploy-all: deploy-COIN_IAC_FIRST_MODULE_PLACEHOLDER

# Destroy all targets in the correct order
destroy-all: destroy-COIN_IAC_FIRST_MODULE_PLACEHOLDER
