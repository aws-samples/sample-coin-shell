# Environment Utilities Test Cases

## Listing environment/Makefile commands

If the user just types "make", then a list of all of the Makefile targets should be displayed. Note - this functionality is implemented in the `environment/Makefile` itself.

## backup-resolve-template-files or brtf

* The directory to be searched should default to the project root directory
* The directory to be searched can be set by supplying an argument d=\<path\>
* Should detect all files with placeholders in the specified directory
* Should ignore files and folders listed in `COIN_EXCLUDE_TEMPLATE_SEARCH` config
* Should create a .bak file to store a copy of each original template file
* Should resolve placeholders in the original template files
* Should work the same if the Makefile shortcut "brtf" is used instead of "backup-resolve-template-files"  

## create-environment or ce

See `test-cases/wizard-create-app-env.md`

## delete-environment or de

See `test-cases/wizard-delete-app-env.md`

## deploy-cdk2-bootstrap-cf-stack

Should deploy the CDK bootstrap stack to the current environent's AWS account.

## deploy-cicd

* Resolve template files while backing up original template files, execute deployment of CICD module, restore original template files
* If the application uses CDK, execute CDK deploy
* If the application uses Terraform, execute Terraform apply
* If the application uses CloudFormation, execute stack deployment

## export-current-environment or ece

* For Mac, should copy all current environment exports to the clipboard
* For other OS, should print all current environment exports to the console

## export_local_app_env_vars

This is a special case because it is run from the shell terminal and not by running Make targets.

Should set the current application environment settings as environment variables in the shell terminal when the following command is run from a Bash shell:

`source $projectDir/environment/utility-functions.sh export_local_app_env_vars`

## extract-deliverable or exd

See `test-cases/wizard-extract-deliverable.md`

## get-current-environment or gce

Should print the name of the environment that is set in `environment/.current-environment`

If the `environment/.current-environment` file does not exist, log a succinct description about the issue and how to resolve it

## list-auth-errors or lae

Should call AWS CloudTrail and query for access errors for the current day and display the results.

## list-local-environments or lle

* Should list the local environment names, which are derrived from the .environment-\<name>.json files present.
* Should exclude any .environment file where the file name contains the word "sensitive".
* Should exclude any .environment file where the file name contains the words "lookup-cache".

## list-remote-environments

Should list the remote environment names (e.g. GitLab, SSM). 

If the remote variables are stored in GitLab, the user should be promted for the personal access token before continuing. If the user does not enter a value, display an error stating that it is required.

## list-code-template-files or lctf
* The directory to be searched should default to the project root directory
* The directory to be searched can be set by supplying an argument d=\<path\>
* Should RECURSIVELY detect all files containing the environment variable lookup pattern and print them out
  * Patterns
    * JavaScript and TypeScript: "process.env."
    * Java: "System.getEnv("
    * Python "os.getenv("

## list-template-files or ltf
* The directory to be searched should default to the project root directory
* The directory to be searched can be set by supplying an argument d=\<path\>
* Should RECURSIVELY detect all files containing the "###var###" pattern and print them out

## print-current-environment or pce

Should print out the environment JSON with all values resolved, whether they be defined in dynamic lookups, environment configurations, or environment constants.

## print-resolved-template-file or prt

* Should resolve print the file with all of the placeholders resolved.
* If no file name is supplied, show a descriptive error to the user
* If dynamic resolution is turned off ("DYNAMIC_RESOLUTION" environment variable != "y")
  * any dynamic configurations should be resolved as blank strings

## print-upgrade-configs or puc

* Should print valid JSON that contains all of the correct settings that allow the
application to be upgraded by running the Create Application Wizard in headless upgrade mode.

## upgrade-coin or uc

* Should check to see if you have the COIN_HOME environment variable set properly
  * If not, log an error and exit
  * If so,
    * First, confirm that the user wants to upgrade COIN 
    * Next, run the COIN upgrade process by generating the JSON file to run the upgrade in headless mode and call the `create-app.sh` script under the COIN_HOME directory to upgrade the app.

## pull-env-vars

* Should ask whether the remote environment is stored in SSM or GitLab
* If GitLab, should prompt the user for a personal access token
* Should show a list of remote environments
* Should download values stored in SSM or GitLab into a new or existing `.environment-<envName>.json` file
* Verify that the `.environment-<envName>.json` file contents have values for the requested environment name, and not the values from the current environment at the time that the pull was initiated
* If the current environment != the pulled environment, ask if the user wants to switch the current environment to match the pulled environment
  * If yes, the `environment/.current-environment` file should be updated to the pulled environment name
  * If no, the `environment/.current-environment` file should be left unchanged 

## push-env-vars

* If the current environment has REMOTE_ENV_VAR_LOC set to "gitlab"
  * Should create a GitLab environment using the current environment name
  * Should post current environment variables to GitLab
    * variables should be scoped to the current environment name
* If the current environment has REMOTE_ENV_VAR_LOC set to "ssm"
  * Should create an SSM Parameter Store entry for each environment setting
  * SSM param names should be `/<APP_NAME>/remoteVars/ssm/<SETTING_NAME>`
* If the current environment has REMOTE_ENV_VAR_LOC set to "na"
  * Should print a message to the terminal that the environment is local only

## resolve-template-files or rtf

* Should detect all template files and resolve all placeholders in them
* Should print which files have been altered
* Should ignore files and folders listed in `COIN_EXCLUDE_TEMPLATE_SEARCH` config

## restore-backup-files or rbf

This action reverses the changes made by `backup-resolve-template-files`

* Should restore template files so that they have their original content with placeholders
* Should delete the .bak file that served as a backup of the original content
* Should allow a directory to be supplied as a parameter that allows the scope of the restoration to be limited to that directory

## switch-current-environment or sce

* Should present the user with a choice of current local environments (based on the presence of `environment/.environment-<env>.json` files)
* Should update the `environment/.current-environment` file with the environment name that the user chose

## util

* Should call a function in `environment/.utility-functions.sh` based on the parameter passed to the util function

Example: make util f=switch_local_environment

## validate-current-environment or vce

* Should exit with an error and print a detailed message if configurations for the current environment are invalid
* Should print a success message if configurations for the current environment are valid

## validate-template-files or vtf

* Should perform template resolution without leaving template files in a changed state
* Should detect and log bad configuration state as detailed in `test-cases/env-resolution.md`


 
