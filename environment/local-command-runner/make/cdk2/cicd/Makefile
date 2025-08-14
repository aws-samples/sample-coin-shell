
# cicd: Resolves all environment variables in template files, executes "cdk deploy" 
# for the cicd module, then restores template files to their original content
deploy-cicd:
	$(ENV_PATH)utility-functions.sh exec_cdk_for_env cicd

# cicd: Resolves all environment variables in template files, executes "cdk destroy"
# for the cicd module, then restores template files to their original content
destroy-cicd:
	CDK_MODE=destroy $(ENV_PATH)utility-functions.sh exec_cdk_for_env cicd
