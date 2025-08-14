
# cicd: Resolves all environment variables in template files, executes "terraform apply" 
# for the cicd module, then restores template files to their original content
deploy-cicd:
	$(ENV_PATH)utility-functions.sh exec_tf_for_env cicd

# cicd: Resolves all environment variables in template files, executes "terraform destroy"
# for the cicd module, then restores template files to their original content
destroy-cicd:
	TF_MODE=destroy $(ENV_PATH)utility-functions.sh exec_tf_for_env cicd
