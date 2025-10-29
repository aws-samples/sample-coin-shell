SHELL := /usr/bin/env bash -euo pipefail -c
SPACE := $(null) $(null)
ENV_MKFILE_PATH := $(subst $(SPACE),\ ,$(abspath $(lastword $(MAKEFILE_LIST))))
ENV_PATH := $(subst $(SPACE),\ ,$(shell bash -c "dirname $(ENV_MKFILE_PATH)")/)
APP_ROOT_PATH := $(subst $(shell bash -c "basename $(ENV_PATH)")/,,$(ENV_PATH))
IGNORE := $(shell bash -c "$(ENV_PATH)utility-functions.sh coin_hooks $(MAKECMDGOALS)")
include $(ENV_PATH)make-env

# List all Make targets in alphabetical order
.PHONY: list
list:
	@LC_ALL=C $(MAKE) -pRrq -f $(firstword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/(^|\n)# Files(\n|$$)/,/(^|\n)# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

# Wizard to create a new or update an existing application environment
# Takes an optional "f" parameter if you want to pass an environment
# JSON file in that has all the settings. Passing in a JSON file puts
# the wizard in "headless" mode, where it won't ask any questions 
# usage: 
#   make create-environment
#   OR
#   make create-environment f=<pathToEnvironmentJsonFile>
create-environment:
	@$(ENV_PATH)create-app-environment.sh "$(f)"

# Simple create-environment shortcut
ce:
	@$(MAKE) create-environment f="$(f)"

# Wizard to delete an application environment
delete-environment:
	@$(ENV_PATH)delete-app-environment.sh

# Simple delete-environment shortcut
de: delete-environment

# Presents choice of which local environment to set as the current one
switch-current-environment:
	@$(ENV_PATH)utility-functions.sh switch_local_environment

# Simple switch-current-environment shortcut
sce: switch-current-environment

# Print the current local environment
get-current-environment: 
	@$(ENV_PATH)utility-functions.sh get_current_env

# Simple get-current-environment shortcut
gce: get-current-environment

# Print the current local environments
list-local-environments: 
	@$(ENV_PATH)utility-functions.sh get_local_environment_names

# Simple list-local-environments shortcut
lle: list-local-environments

# Print the current remote environments
list-remote-environments: 
	@$(ENV_PATH)utility-functions.sh get_remote_environment_names

# Simple list-remote-environments shortcut
lre: list-remote-environments

# Print all environment setting name-value pairs for easy confirmation
# of whether your environment is configured correctly
print-current-environment:
	@$(ENV_PATH)utility-functions.sh print_current_environment

# Simple print-current-environment shortcut
pce: print-current-environment

# Print a success message if the current environment settings are valid
# or log an error and exit if they are not valid
validate-current-environment:
    @$(ENV_PATH)utility-functions.sh validate_current_environment
 
# Simple validate-current-environment shortcut
vce: validate-current-environment

# Get current COIN environment variable exports to paste into your shell
export-current-environment:  ## Get current COIN environment variable exports to paste into your shell (alias: ece)
	@$(ENV_PATH)utility-functions.sh echo_export_local_app_env_vars

# Simple export-current-environment shortcut
ece: export-current-environment

# Resolve placeholders in a file and print the result to the console
# usage: make print-resolved-template-file f=<filePath>
print-resolved-template-file:
	@echo ""
	@echo "Note: set \"DYNAMIC_RESOLUTION\" environment variable to \"y\" to enable dynamic resolution"
	@echo ""
	@$(ENV_PATH)utility-functions.sh print_resolved_placeholders "$(f)"

# Simple print-resolved-template-file shortcut
prt:
	@echo ""
	@echo "Note: set \"DYNAMIC_RESOLUTION\" environment variable to \"y\" to enable dynamic resolution"
	@echo ""
	@$(ENV_PATH)utility-functions.sh print_resolved_placeholders "$(f)"

# Prints the names of all application code files that contain environment variable
# lookups for langauges such as Python, JavaScript, and Java
# Takes an optional "d" parameter if you want to specifiy the starting directory
# in which to search for files that contain placeholders
# usage: 
#   make list-code-template-files
#   OR
#   make list-code-template-files d=<pathToDirectory>
list-code-template-files:
	@$(ENV_PATH)utility-functions.sh list_code_template_files "$(d)"

# Simple list-code-template-files shortcut
lctf: 
	@$(MAKE) list-code-template-files

# Prints the names of all application files that contain environment placeholders.
# Takes an optional "d" parameter if you want to specifiy the starting directory
# in which to search for files that contain placeholders
# usage: 
#   make list-template-files
#   OR
#   make list-template-files d=<pathToDirectory>
list-template-files:
	@$(ENV_PATH)utility-functions.sh get_template_files "$(d)"

# Simple list-template-files shortcut
ltf: 
	@$(MAKE) list-template-files d="$(d)"

# Validates all application templates to ensure that all placeholders
# in all templates can be successfully resolved
validate-template-files:
	@$(ENV_PATH)utility-functions.sh resolve_template_files "dryRun"

# Simple validate-template-files shortcut
vtf: validate-template-files

# Resolves placeholders in all application template files and
# overwrites the files with the resolved content
# WARNING - will leave template files in a changed state
# Takes an optional "d" parameter if you want to specifiy the starting directory
# in which to search for files that contain placeholders
# usage: 
#   make resolve-template-files
#   OR
#   make resolve-template-files d=<pathToDirectory>
resolve-template-files:
	@$(ENV_PATH)utility-functions.sh resolve_template_files "" "$(d)"

# Simple resolve-template-files shortcut
rtf: $(MAKE) resolve-template-files

# Resolves placeholders in all application template files and
# overwrites the files with the resolved content
# A backup of each template is taken before the resolution process
# to allow for undoing the resolve step later
# WARNING - will leave template files in a changed state
# Takes an optional "d" parameter if you want to specifiy the starting directory
# in which to search for files that contain placeholders
# usage: 
#   make backup-resolve-template-files
#   OR
#   make backup-resolve-template-files d=<pathToDirectory>
backup-resolve-template-files:
	@$(ENV_PATH)utility-functions.sh resolve_template_files "backup" "$(d)"

# Simple backup-resolve-template-files shortcut
brtf: $(MAKE) backup-resolve-template-files

# Restores template file backups. This serves as an "undo" for the
# files that were changed by "resolve-template-files"
# Takes an optional "d" parameter if you want to specifiy the starting directory
# in which to search for files that contain placeholders
# usage: 
#   make restore-backup-files
#   OR
#   make restore-backup-files d=<pathToDirectory>
restore-backup-files:
	@$(ENV_PATH)utility-functions.sh restore_template_files "$(d)"

# Simple restore-backup-files shortcut
rbf: 
	$(MAKE) restore-backup-files

# extract-deliverable wizard that will extract application files that we want to share into a separate directory
# Takes an optional "b" parameter if you want to specifiy the branch to clone
# usage: 
#   make extract-deliverable
#   OR
#   make extract-deliverable b=<myBranchName>
extract-deliverable:
	@$(ENV_PATH)extract-deliverable.sh "$(b)"

# Simple extract-deliverable shortcut
exd: extract-deliverable

# Presents choice of remote environments to import and set as the current one
pull-env-vars:
	@$(ENV_PATH)utility-functions.sh pull_env_vars

# Save off local environment variable settings to a remote store e.g. SSM or GitLab.
# This is useful to make it so that your team members or a CICD pipeline can reference
# environment variable values
# Takes an optional "gitRepoToken" parameter if you want to specifiy the git repository token
# usage: 
#   make push-env-vars
#   OR
#   make push-env-vars gitRepoToken=<myToken>
push-env-vars:
	@$(ENV_PATH)utility-functions.sh push_env_vars "$(gitRepoToken)"

# Prints a table of CloudTrail logs for IAM permission denied events
# over a date range. Useful for debugging IAM role permissions errors.
list-auth-errors:
	@$(ENV_PATH)utility-functions.sh print_auth_errors

# Simple list-auth-errors shortcut
lae: list-auth-errors

# Execute a utility-function on the current environment
# If you do not supply the "f" argument, the utility function names will be printed out
# usage: make util f=<functionName>
util:
	@echo "Current environment is \"$(ENV_NAME)\""
	$(ENV_PATH)utility-functions.sh "$(f)"

# Create a new root Infrastructure as Code module based on the environment/iac-module-template
create_iac_root_module:
	@$(ENV_PATH)create-iac-module.sh

# Simple create_iac_root_module shortcut
cim: create_iac_root_module

# Print who you are logged in as for the AWS CLI - this is influenced by use of environment/.cli-profiles.json
get-caller-identity:
	@$(ENV_PATH)utility-functions.sh get_caller_identity

# Simple get-caller-identity shortcut
gci: get-caller-identity

# Log in to the AWS CLI with SSO using the profile for the current environment
aws-sso-login:
	@$(ENV_PATH)utility-functions.sh aws_sso_login

# Simple aws-sso-login shortcut
asl: aws-sso-login

# Print the configurations for upgrading the application to the latest standards
print-upgrade-configs:
	$(ENV_PATH)utility-functions.sh get_coin_upgrade_configs

# Simple print-upgrade-configs shortcut
puc: print-upgrade-configs

# Upgrade this application to use the latest COIN files
upgrade-coin:
	$(ENV_PATH)utility-functions.sh upgrade_coin 

# Simple upgrade-coin shortcut
uc: upgrade-coin

# Upgrade (in destructive mode) this application to use the latest COIN files.
# In destructive mode, the upgrade will include files COIN may have changed but that
# application developers may have also changed. Developers will need to perform a 
# diff on the upgrade changes and undo any changes made during the upgrade that they
# do not want
upgrade-coin-destructive:
	$(ENV_PATH)utility-functions.sh upgrade_coin "destructive"

# Simple upgrade-coin-destructive shortcut
ucd: upgrade-coin-destructive
