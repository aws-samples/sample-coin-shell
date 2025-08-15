# Create App Wizard Test Cases

The create app wizard is defined here: `create-app.sh`

## Automatic Updates

* Should check to see if the Create COIN App repository contains the latest commits
* If so, print out the confirmation
* If not, ask the user to update

## AWS Account Validation

Once a user enters an AWS account ID and region, check to see if the AWS CLI session matches that information. If not, print an error message and exit.
If the AWS account ID entered was all 0's, that is treated as a placeholder and no validation is performed.

## Option To Set Default Question Answers Based On The Last Run of the Wizard

* Should ask "Would you like to load default selections from previous run?"
  * If yes, load default answers from `.choice-cache.json`
  * If no, use system defaults for default answers

## Input Validation

  * Should print out an explanation of why an entry was invalid and ask the user to input a new value

## Choice Caching

Should cache user choices in `.choice-cache.json`. These values should be set:

  * defaultProjectParentDir
  * defaultGitProjectGroup
  * defaultGitProjectName
  * defaultGitRepoDomain
  * defaultGitRepoProvider
  * defaultAppName
  * defaultEnableOncePerAccount
  * defaultEnvName
  * defaultCreatedBy
  * defaultAwsAccountNum
  * defaultRegion
  * defaultSecondaryRegion
  * defaultIaC
  * defaultUseCicd
  * defaultCicd
  * defaultDeployRole
  * defaultDeployRemoteEnvVars
  * defaultRemoteEnvVarLoc
  * defaultDeployTfBackend
  * defaultDeployCdk2Backend
  * defaultHasSecondaryRegion

## Questions Asked

* Application name (directory where code will be saved and the Git repository name)
* Environment name
* AWS Account number
* AWS default region
* What local directory should the application be generated in
  * Validate the directory exists and is not a subdirectory of the Create COIN App directory
  * Warn and confirm if application directory already exists
* Which IaC technology to use (Terraform, CDK, CloudFormation)
* Do you want to create a new Git repository?
  * If yes, GitLab or another?
  * If GitLab
    * Ask the group name
    * Ask the GitLab service domain
* Map environment to an AWS CLI profile
* Do you want to create a CICD pipline
  * If yes, which CICD technology (e.g. GitLab)
* Ask where to store environment values remotely (GitLab, SSM, Do Not Store)
  * If storing remotely, ask the name of the environment creator/owner
* Ask if environment utility scripts should be included in the generated app

## Deployment Questions Asked

* If Terraform, do you want to deploy the Terraform back end
* If CDK, do you want to deploy the CDK bootstrap stack
* If CICD, do you want to deploy the CICD module* If GitLab CICD, do you want to push your environment settings to GitLab

## Deployment Actions

### CDK Bootstrap

If the user elected to use CDK as the IaC technology, and the user chose "y" to deploy the CDK bootstrap stack:
* Should deploy the CDK bootstrap stack to the AWS account and default region set in the user's application environment
* If user elected to use a secondary region
  * Deploy the CDK bootstrap stack to the secondary region as well

### Terraform Back End

If the user elected to deploy the Terraform back end
  * Should deploy Terraform back end stack for the first IaC module to the application environment's AWS account and region

### Pushing Environment Settings to GitLab

If the user elected to push environment settings to GitLab
* Should take all environment settings (including environment constants) and deploy them to GitLab as CICD environment variables
  * Variables should be scoped to the environment name entered by the user
  * If variables are maskable, they should be masked

## Headless Mode

The headless mode input template is located at `create-app-answers-template.json5`

* Should execute wizard without asking any interactive questions
* Should set user choices based on the supplied JSON file set by the first argument to the `create-app.sh` script
* If input file supplied contains missing or invalid values
  * Should log an explanatory error and exit
* Should not create a new app if this environment variable has been set: `export COIN_CREATE_APP_DRY_RUN="y"`

## Create New Repo

If the user wants to create a new Git repository, the repository should
be created
  * On GitLab (if user chose GitLab)

The name of the repository and the setting for the origin in .git/config should use the application's directory name (as opposed to the value for the APP_NAME variable, although these could be set to the same value)

If Git Defender is installed, it should be set up automatically

If the Git repository already exists:
  * If it has a main branch already
    * Pull down the main branch before creating any application files. This will allow COIN to avoid merge conflicts.
    * Add COIN files and commit to main
  * If the repo has no main branch
    * Add COIN files, which should cause a main branch to be created automatically on the origin

## Files Created

### Root Directory Files

* .gitignore
* .gitleaksignore
* README.md (customized by user choices)
  * If file already exists, do not overwrite it
* Makefile
* Makefile-4-customer
* If user elected to have a CICD pipeline using GitLab
  * .gitlab-ci.yml
    * Customized based on user entries
  * .gitlab-ci-sast.yml

## build-script Directory

* Should contain all build-script folder files

### environment Directory

* Should create `environment/environment-constants.json` that sets
  * APP_NAME

* Should create `environment/.choice-cache.json` that holds user's entries applicable to the Create Application Environment Wizard

* Should create custom `environment.app-env-var-names.txt` file based on user choices
  * Should alway have these properties defined
    * APP_NAME
    * AWS_ACCOUNT_ID
    * AWS_DEFAULT_REGION
    * ENV_NAME
    * REMOTE_ENV_VAR_LOC
  * If user elected to store environment variables in a remote store
    * CREATED_BY
  * If the user indicated that a secondary AWS region is needed
    * AWS_PRIMARY_REGION
    * AWS_SECONDARY_REGION
  * If user chose Terraform for IaC
    * TF_S3_BACKEND_NAME
  * If user wanted a CICD pipeline
    * AWS_CREDS_TARGET_ROLE

* Should create `environment/README.md` with documentation on Create COIN App

* Should create developer guide documentation that is specific to the IaC type chosen
  * For Terraform, it should create `environment/docs/DEV_GUIDE_TERRAFORM.md`
  * For CDK, it should create `environment/docs/DEV_GUIDE_CDK.md`

* Should copy scripts:
  * Should create `environment/aws-regions.sh` that holds the valid choices for AWS regions

  * Should create `environment/bash-5-utils.sh` that implements common functionality that requires Bash 5 or above

  * Should create `environment/constants.sh` that holds framework configuration values

  * Should create `environment/create-app-env-questions.sh` that holds the questions that can be asked when creating a new environment

  * Should create `environment/create-app-environment.sh` that implements the Create App Environment Wizard

  * Should create `environment/create-iac-module.sh` that implements the Create New Root IaC Module Wizard

  * Should create `environment/delete-app-environment.sh` that implements the Delete Application Environment Wizard

  * Should create `environment/dynamic-lookups.sh` that defines configurations that should be dynamically looked up

  * Should create `environment/extract-deliverable.sh` that implements the Extract Deliverable Wizard

  * Should create `environment/generate-deployment-instructions.sh` that implements a wizard to generate deployment instructions

  * Should create `environment/gitlab.sh` that implements GitLab-related functionality

  * Should create `environment/utility-functions.sh` that implements common functionality without depending on Bash 5

* Should create `environment/coin-app-version` file set to the Git hash of the Create COIN App repository that was used to generate the application

* Should create a `environment/.current-environment` file with its value set to the environment name that the user chose

* Should create a `environment/.environment-<envName>.json` file with all of the environment settings defined (excluding those set in `environment/environment-constants.json`)

* If a `environment/.environment-<envName>.json` file already exists from a prior Create App Wizard run, it should be backed up to `environment/.environment-<envName>-copy.json` instead of being overwritten.

* Should copy the environment `Makefile` to the `environment` directory

* Should customize `environment/Makefile`
  * Include Terraform utilities if IaC of generated app is Terraform
    * If the user elected for only one AWS region
      * targets should be copied from `environment/local-command-runner/make/terraform/bootstrap/single-region/Makefile`
    * Else If the user elected for only a secondary AWS region
      * targets should be copied from `environment/local-command-runner/make/terraform/bootstrap/cross-region-replication/Makefile`
  * Include CDK utilities if IaC of generated app is CDK
  * Include deploy-cicd and destroy-cicd targets if user wanted a CICD pipeline

### iac Directory

* Should contain a first IaC module under `iac/roots/<user-entered-name>`
  * Example module should match the chosen IaC (Terraform, CDK, CloudFormation)
* If user chose to create a CICD pipeline
  * Should contain cicd module under `iac/roots/cicd`
  * CICD module should match the chosen IaC (Terraform, CDK, CloudFormation)
* If the user chose Terraform for the IaC technology
  * If the user elected for only one AWS region
    * Should copy `iac/terraform/bootstrap/single-region` directory contents into the project's `iac/bootstrap` directory
  * If the user elected for a secondary AWS region
    * Should copy `iac/terraform/bootstrap/cross-region-replication` directory contents into the project's `iac/bootstrap` directory


### New IaC Root Module Template

* Should create `environment/iac-module-template` that is a generic new IaC module template that is specific to the application's IaC type (e.g. Terraform, CDK, CF)

### Code Scans

* Should produce an application that has no "critical" or "warning" level issues reported by code scanning
  tools such as gitleaks, semgrep, checkov, cfn nag, or cdk nag

### Upgrading Existing Apps

If the Create App Wizard is run against an existing app, the wizard should run in "upgrade mode" and not overwrite changes to these application files:

  * README.md
  * environment/.current-environment
  * environment/.cli-profiles
  * environment/make-env
  * environment/dynamic-lookups.sh
  * environment/app-env-var-names.txt
  * environment/.environment-*.json
  * Makefile
  * Makefile-4-customer
  * IaC modules

### Mapping AWS CLI Profiles to COIN Environments

* When creating a new app interactively
  * Should not ask the user about AWS CLI profiles if (s)he set the AWS account ID as all 0's
  * When you want to create a new profile automatically
    * Profile does not exist
      * Adds new profile entry in `~/.aws/config` file
      * Creates `environment/.cli-profiles.json`
    * Profile exists
      * Skips creating entry in `~/.aws/config` file and logs this
      * Creates `environment/.cli-profiles.json`
  * When you want to associate an existing profile
    * Does not update `~/.aws/config` file
    * Creates `environment/.cli-profiles.json` with user-entered value
  * When you want to skip profile mapping to COIN environments
    * Does not update `~/.aws/config` file
    * Does not create `environment/.cli-profiles.json`
* When creating a new app in headless mode
  * Same test scenarios as interactive mode
* When upgrading an existing app
  * Headless from COIN home as the current directory
    * When a value is set for `coinAwsCliProfileName`
      * should create `environment/.cli-profiles.json` if it does not exist
        * should not touch this file if it already exists
      * should add a new profile entry in `~/.aws/config` file if it is not already there
    * When no (or blank) value is set for `coinAwsCliProfileName`
      * Skip creating `environment/.cli-profiles.json`
      * Skip creating entry in `~/.aws/config` file
  * Headless from App home as the current directory
    * Skip creating `environment/.cli-profiles.json`
    * Skip creating entry in `~/.aws/config` file

### Custom Extensions

* Should call custom extension functions defined in `extensions.sh`
  * `ask_custom_create_app_questions`
  * `ask_custom_create_app_questions_headless_input_validation` 
  * `take_custom_create_app_actions`
  * `take_custom_create_app_deployment_actions`
