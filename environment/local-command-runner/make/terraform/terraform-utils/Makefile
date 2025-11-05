# Resolves all environment variables in template files, executes any terraform command that you 
# supply, then restores template files to their original content
# Note: to see a list of root Terraform module names, run 'make list-tf-modules'
# usage:
# 	make tf m=<my-module-name> c="<my Terraform command>"
# example:
# 	make tf m=my-module-name c="terraform init"
tf:  ## Run arbitrary Terraform command against the current environment
	$(ENV_PATH)utility-functions.sh exec_tf_command_for_env $(m) "$(c)"

# Print out the names of all of this project's root Terraform modules
list-tf-modules:  ## Print Terraform root module names
	$(ENV_PATH)utility-functions.sh print_root_terraform_modules

# Runs checkov scan against a root Terraform module
# Note: to see a list of root Terraform module names, run 'make list-tf-modules'
# usage:
# 	make tf m=<my-module-name>
# example:
# 	make tf m=my-module-name
checkov:  ## Run checkov scan against a root Terraform module
	$(ENV_PATH)utility-functions.sh exec_checkov $(m)

# Runs checkov scan against all root Terraform modules
checkov-all:  ## Run checkov scan against all root Terraform modules
	$(ENV_PATH)utility-functions.sh exec_checkov_all

