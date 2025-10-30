
# cicd: Resolves all environment variables in template files, executes "terraform apply" 
# for the cicd module, then restores template files to their original content
deploy-cicd: ## Deploy the cicd module
	$(ENV_PATH)utility-functions.sh exec_tf_for_env cicd

# cicd: Resolves all environment variables in template files, executes "terraform destroy"
# for the cicd module, then restores template files to their original content
destroy-cicd: ## Destroy the cicd module
	TF_MODE=destroy $(ENV_PATH)utility-functions.sh exec_tf_for_env cicd
