# Extract Deliverable Wizard Test Cases

The extract deliverable wizard is defined here: `environment/extract-deliverable.sh`

* Should ask if the user wants to download a fresh copy of the application repository
  * If yes, perform a git clone of the application repository to a user-specified location
    * Should ask which branch to clone from and use the entered value
      * Should log error and exit immediately if branch name is invalid
  * If no, use the current application directory as-is and copy the files to a separate user-specified location
    * do not copy .git directory
    * do not copy node_modules directories
    * do not copy files ending in .bak
    * do not copy .terraform*

* Should ask if the user wants to include the CICD pipeline in the deliverable
  * If yes
    * Include these things in the deliverable
      * iac/roots/cicd
      * .gitlab-ci*
  * If no
    * Exclude these things from the deliverable
      * iac/roots/cicd
      * .gitlab-ci*
    * Remove lines containing these things from `environment/app-env-var-names.txt`
      * Git|GIT|GitLab|GITLAB|gitlab|CICD|cicd|AWS_CREDS_TARGET_ROLE
    * Remove lines containing these things from `environment/Makefile`
      * cicd|push-mirror|extract-deliverable

* Should ask if the user wants to include the COIN environment scripts in the deliverable
  * If yes
    * Copy `environment` directory to the generated app
    * Create a `environment/.current-environment` file, set to blank
    * Create a `environment/.environment-default.json` file with all blank values
    * Do not copy any exising `environent/.environment-<envName>.json files`
    * Do not include `environment/.log.txt`

  * If no
    * If Terraform is used as the IaC tool for the project
      * should resolve the `CUR_DIR_NAME` placeholder automatically in `backend.tf` files during the export process.
        * should be able to resolve nested directories such as `iac/roots/nested/subdir/mymodule`