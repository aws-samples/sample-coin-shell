#!/usr/bin/env bash

# This script dynamically generates documentation on 
#   1. how to set input variables
#   2. what input variables mean
#   3. where input variable placeholders are located
#   4. how to run Infrastructure as Code scripts to deploy the prototype

scriptDir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$scriptDir/utility-functions.sh" "source generate_deployment_instructions_wizard" 1> /dev/null
detect_and_set_iac_type

display "\nWelcome to the Generate Deployment Instructions Wizard!"

validate_bash_version

appRootDir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && cd .. &> /dev/null && pwd )"
appName=${appRootDir##*/}
appRootParentDir="$( cd -- "$( dirname -- "${appRootDir}" )" &> /dev/null && pwd )"
appRootParentDir=${appRootParentDir}/

if [[ "$iac" == "terraform" ]]; then
    iacDeployToolName="Terraform"
elif [[ "$iac" == "cdk2" ]]; then
    iacDeployToolName="CDK"
else
    iacDeployToolName="CloudFormation"
fi

# Exports (as environment variables) all values defined in the supplied .json
# file so that this wizard can run in headless mode.
# param1: a working path (absolute or relative) to the JSON file 
#         containing wizard answers
# Example input:
# {
#     "isUseCoinForDeployment": "y",
#     "includeMakefile": "n",
#     "instructionsFileName": "DEPLOYMENT.md"
# }
export_wizard_answers () {
    
    if ! command -v jq --version &> /dev/null
    then
        displayIssue "jq could not be found. Please install jq, then run this script again." "error"
        exit 1
    fi

    if [[ ! -f "$1" ]]; then
        displayIssue "Failed to get headless mode values from JSON file." "error"
        displayIssue "File \"$1\" does not exist."
        exit 1
    fi

    if jq empty "$1" 2>/dev/null; then
        log "Headless input contains structurally valid JSON"
    else
        displayIssue "Headless input contains structurally invalid JSON" "error"
        exit 1
    fi

    eval "export $(jq -r 'to_entries | map("\(.key)=\(.value)") | @sh' "$1")"
}

validate_headless_mode_input () {

    validate_yes_or_no "isUseCoinForDeployment" "$isUseCoinForDeployment"

    if [[ "$isUseCoinForDeployment" == "n" ]]; then
        validate_yes_or_no "includeMakefile" "$includeMakefile"
    fi

    [[ ! "$instructionsFileName" =~ ^[^[:space:]]{4,100}$ ]] && \
    displayIssue "\"instructionsFileName\" value is invalid: \"$instructionsFileName\"." "error" && \
    displayIssue "Must not include whitespace and length (${#instructionsFileName}) must be between 4 and 100." && \
    exit 1
}

if [[ ! -z "$1" ]]; then
    export HEADLESS="y"

    display "Running in headless mode."

    log "\nHeadless file input:"
    log "$(cat "$1")"

    export_wizard_answers "$1"
    validate_headless_mode_input
else

    yes_or_no isUseCoinForDeployment "\nWill Create COIN App scripts be used to perform the deployment" "y"

    includeMakefile=n
    if [[ "$isUseCoinForDeployment" == "n" ]]; then

        if [ -f "${appRootDir}/Makefile-4-customer" ]; then
            display ""
            defaultIncludeMakefile="y"
            yes_or_no includeMakefile "Do you want to set the Makefile-4-customer file to be the project's primary Makefile in the extracted deliverable" "$defaultIncludeMakefile"
        fi
    fi

    if [[ "$iac" != "terraform" ]] && [[ "$iac" != "cdk2" ]]; then
        displayIssue "This wizard currently only supports generating deployment instructions for Terraform and CDK projects.\n" "error"
        exit 0
    fi

    defaultInstructionsFileName="DEPLOYMENT.md"
    length_range instructionsFileName "\nWhat is the name of the file that the deployment instructions should be written to?" \
        "$defaultInstructionsFileName" "4" "100"
fi

echo -e "# ${appName} Deployment Documentation\n" > "${appRootDir}/${instructionsFileName}"
echo -e "## Purpose\n" >> "${appRootDir}/${instructionsFileName}"
echo -e "This page documents how to execute the $iacDeployToolName to deploy the prototype solution to an AWS account." >> "${appRootDir}/${instructionsFileName}"

echo -e "\n## Prerequisites\n" >> "${appRootDir}/${instructionsFileName}"
if [[ "$iac" == "terraform" ]]; then
    echo -e "  * Install [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) (a recent version is recommended, such as 1.8 or greater)" >> "${appRootDir}/${instructionsFileName}"
elif [[ "$iac" == "cdk2" ]]; then
    echo -e "  * Install $coinPackageManager package manager" >> "${appRootDir}/${instructionsFileName}"
    # Note - no need to have CDK install link here since it should be installed as part of package.json
fi

if [[ "$includeMakefile" == "y" ]]; then
   echo -e "  * Install [Make](https://www.gnu.org/software/make/)" >> "${appRootDir}/${instructionsFileName}"
fi

echo -e "  * Install the [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)" >> "${appRootDir}/${instructionsFileName}"
echo -e "  * The ability to log into an AWS account with sufficient permissions to deploy the solution" >> "${appRootDir}/${instructionsFileName}"

if [[ "$isUseCoinForDeployment" == "y" ]]; then
    echo -e "  * [Git CLI](https://git-scm.com/downloads)" >> "${appRootDir}/${instructionsFileName}"
    echo -e "  * [make](https://www.gnu.org/software/make/)" >> "${appRootDir}/${instructionsFileName}"
    echo -e "  * [jq](https://stedolan.github.io/jq/)" >> "${appRootDir}/${instructionsFileName}"

    echo -e "  *  Bash shell with version 5.0 or greater." >> "${appRootDir}/${instructionsFileName}"
    echo -e "  *  Mac users " >> "${appRootDir}/${instructionsFileName}"
    echo -e "      * Mac comes with an old version of Bash" >> "${appRootDir}/${instructionsFileName}"
    echo -e "      * Use \`homebrew\` to install new version" >> "${appRootDir}/${instructionsFileName}"
    echo -e "      * \`which bash\` should point to \`/opt/homebrew/bin/bash\`" >> "${appRootDir}/${instructionsFileName}"
    echo -e "      * If you use VSCode and you want to use bash as your default Terminal shell, you must update its terminal shell to use the one from homebrew." >> "${appRootDir}/${instructionsFileName}"
    echo -e "          * Go into VSCode settings and search for "terminal"" >> "${appRootDir}/${instructionsFileName}"
    echo -e "          * Find the setting named "Terminal\>Integrated\>Env:Osx" and set its value to bash" >> "${appRootDir}/${instructionsFileName}"
    echo -e "  *  Amazon Linux 2 Users" >> "${appRootDir}/${instructionsFileName}" >> "${appRootDir}/${instructionsFileName}"
    echo -e "      * Execute the below statements to upgrade to Bash 5" >> "${appRootDir}/${instructionsFileName}"
    echo -e "      * After executing these statements, you can switch to the Bash shell by typing: \`exec bash\`. Note that \`zsh\` is the default shell for AL2.\n" >> "${appRootDir}/${instructionsFileName}"

    echo -e "        \`\`\`" >> "${appRootDir}/${instructionsFileName}"
    echo -e "        cd ~" >> "${appRootDir}/${instructionsFileName}"
    echo -e "        wget http://ftp.gnu.org/gnu/bash/bash-5.2.tar.gz" >> "${appRootDir}/${instructionsFileName}"
    echo -e "        tar xf bash-5.2.tar.gz" >> "${appRootDir}/${instructionsFileName}"
    echo -e "        cd bash-5.2" >> "${appRootDir}/${instructionsFileName}"
    echo -e "        ./configure" >> "${appRootDir}/${instructionsFileName}"
    echo -e "        make" >> "${appRootDir}/${instructionsFileName}"
    echo -e "        sudo make install" >> "${appRootDir}/${instructionsFileName}"
    echo -e "        sh" >> "${appRootDir}/${instructionsFileName}"
    echo -e "        bash -version" >> "${appRootDir}/${instructionsFileName}"
    echo -e "        \`\`\`" >> "${appRootDir}/${instructionsFileName}"
fi

echo -e "\n## Configuring $iacDeployToolName input variables\n" >> "${appRootDir}/${instructionsFileName}"
echo -e "The prototype's $iacDeployToolName code needs to know certain things that must to be set by you and cannot be hardcoded. For example, many of the resources that $iacDeployToolName will create need to know the AWS account and region to create them in." >> "${appRootDir}/${instructionsFileName}"

if [[ "$iac" == "terraform" ]]; then
    
    echo -e "\nExample of Terraform usage of input variables:\n" >> "${appRootDir}/${instructionsFileName}"
    echo -e "\`\`\`" >> "${appRootDir}/${instructionsFileName}"

    echo -e "resource \"aws_iam_role\" \"my_logging_role\" {" >> "${appRootDir}/${instructionsFileName}"
    echo -e "  name               = \"\${var.appName}-\${var.envName}-\${var.region}-my-logging-role\"" >> "${appRootDir}/${instructionsFileName}"
    echo -e "  ..." >> "${appRootDir}/${instructionsFileName}"
    echo -e "}" >> "${appRootDir}/${instructionsFileName}"
    echo -e "\`\`\`" >> "${appRootDir}/${instructionsFileName}"
    echo -e "\nIn the above example, input variables are referred to within \"\${}\" demarcations." >> "${appRootDir}/${instructionsFileName}"

    echo -e "\nNote: this prototype configures Terraform input variable values in a \`terraform.tfvars\` file." >> "${appRootDir}/${instructionsFileName}"

elif [[ "$iac" == "cdk2" ]]; then
    echo -e "\nInput variables are supplied to CDK as environment variables. See instructions below on how to set environment variable values." >> "${appRootDir}/${instructionsFileName}"
fi

# BEGIN GENERATING COIN APPROACH DOCUMENTATION --------------------------------------
if [[ "$isUseCoinForDeployment" == "y" ]]; then

    echo -e "\n## Approach\n" >> "${appRootDir}/${instructionsFileName}"

    echo -e "Included with this prototype are shell scripts which enable you to configure different sets of configuration values to be used by the Infrastructure as Code. For example, you may want to have configurations that differ per environment (e.g. DEV, TEST, PROD) or you may want developers to be able to set their own configurations so that they can deploy the IaC to different places or with different values." >> "${appRootDir}/${instructionsFileName}"

    echo -e "\nHere's how it works:" >> "${appRootDir}/${instructionsFileName}"
    echo -e "  1. The names of configuration variables are defined in the \`environment/app-env-var-names.txt\` file." >> "${appRootDir}/${instructionsFileName}"
    echo -e "      * You can add more configuration values to this file as needed" >> "${appRootDir}/${instructionsFileName}"
    echo -e "  2. Configuration values are set into a JSON file under the \`environment\` directory" >> "${appRootDir}/${instructionsFileName}"
    echo -e "      * see \`environment/.environment-default.json\` for an example" >> "${appRootDir}/${instructionsFileName}"
    echo -e "      * this file should have a value set for all of the input variables listed in a below section in this document" >> "${appRootDir}/${instructionsFileName}"
    echo -e "  3. You can have multiple JSON configuration files that contain different values." >> "${appRootDir}/${instructionsFileName}"
    echo -e "      * only one file can be applied at a given time." >> "${appRootDir}/${instructionsFileName}"
    echo -e "      * the JSON file name should contain the configuration name. Example: \`.environment-<config-name>.json\`" >> "${appRootDir}/${instructionsFileName}"
    echo -e "      * you can set the current configuration file by putting the configuration name into the \`environment/.current-environment\` file or by running a command line app using this command: \`make sce\` (where \"sce\" is short for \"set current environment\")" >> "${appRootDir}/${instructionsFileName}"
    echo -e "      * you can create a new configuration set JSON file by copying an existing JSON file and changing the file name and whatever values you want to change. As an alternative, we've provided a \"new configuration set\" wizard. The wizard can be started by typing \`make ce\` (ce is short for \"create environment\") into a terminal. The wizard will ask you what value you want to set for each variable." >> "${appRootDir}/${instructionsFileName}"
    
    if [[ "$iac" == "terraform" ]]; then
        echo -e "  3. Instead of hardcoding configuration values into IaC, we use placeholders. These are easy to spot because they are surrounded with pound signs. Example: \`###MY_CONFIG_1###\`" >> "${appRootDir}/${instructionsFileName}"
    elif [[ "$iac" == "cdk2" ]]; then
        echo -e "  3. Instead of hardcoding configuration values into IaC, we reference environment variables." >> "${appRootDir}/${instructionsFileName}"
    fi
    
    echo -e "  4. Running IaC commands are done by using the targets configured in the Makefile" >> "${appRootDir}/${instructionsFileName}"
    
    if [[ "$iac" == "terraform" ]]; then
        echo -e "      * When you run a Make target, scripts will automatically execute that will resolve the placeholders mentioned in step 1 with the corresponding value that is set in step 2. This resolution step is performed before IaC commands are run. After the IaC commands finish running, the variable resolutions are undone automatically so that the placeholders are once again present in the IaC code." >> "${appRootDir}/${instructionsFileName}"
    elif [[ "$iac" == "cdk2" ]]; then
        echo -e "      * When you run a Make target, scripts will automatically execute that will set environment variable values for the configurations mentioned in step 1 with the corresponding value that is set in step 2. This step is performed before IaC commands are run." >> "${appRootDir}/${instructionsFileName}"
    fi
    
    echo -e "\nFor more in-depth details on this approach. see [environment/README.md](environment/README.md)" >> "${appRootDir}/${instructionsFileName}"

fi
# END GENERATING COIN APPROACH DOCUMENTATION -----------------------------------------

# BEGIN GENERATING ENVIRONMENT VARIABLE DOCUMENTATION -------------------------------

echo -e "\n## Input variable names used in the prototype and their meanings\n" >> "${appRootDir}/${instructionsFileName}"
echo -e "\`\`\`" >> "${appRootDir}/${instructionsFileName}"

tmpEnvVarDocsFilePath="${appRootDir}/tmp_env_var_docs.txt"

# Getting variable documentation. Remove variables that we use internally that customers won't use and remove all blank lines
grep -vE "(Git|GIT|GitLab|GITLAB|gitlab|CICD|cicd|AWS_CREDS_TARGET_ROLE|REMOTE_ENV_VAR_LOC|CREATED_BY|remote system access|disable remote storage|person who created)" "${appRootDir}${projectEnvPath}/app-env-var-names.txt" | grep . > "${tmpEnvVarDocsFilePath}"

# Remove initial comments at the top of the app-env-var-names.txt file
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' 1,2d "${tmpEnvVarDocsFilePath}"
else
    sed -i 1,2d "${tmpEnvVarDocsFilePath}"
fi

# Add a blank line after each non-comment line (those that do not start with #)
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "/^#/ ! s/$/& \n/g" "${tmpEnvVarDocsFilePath}"
else
    sed -i "/^#/ ! s/$/& \n/g" "${tmpEnvVarDocsFilePath}"
fi

cat "${tmpEnvVarDocsFilePath}"  >> "${appRootDir}/${instructionsFileName}"
echo -e "\`\`\`" >> "${appRootDir}/${instructionsFileName}"
rm "${tmpEnvVarDocsFilePath}"

# END GENERATING ENVIRONMENT VARIABLE DOCUMENTATION -------------------------------

# BEGIN INSTRUCTIONS FOR SETTING CONFIGURATION VARIABLES WITHOUT COIN ------------------------
if [[ "$isUseCoinForDeployment" == "n" ]]; then

    if [[ "$includeMakefile" == "y" ]]; then
        echo -e "\n## Configuring and deploying the solution for the first time\n" >> "${appRootDir}/${instructionsFileName}"
        iacStepNumber=3

        echo -e "Ensure that you have installed the prerequisites documented above before proceeding.\n" >> "${appRootDir}/${instructionsFileName}"

        echo -e "Also, ensure that you are logged in using the AWS CLI to the account you wish to deploy" >> "${appRootDir}/${instructionsFileName}"
        echo -e "to and that your role has sufficient priveleges to perform the deployment.\n" >> "${appRootDir}/${instructionsFileName}"

        echo "Steps:" >> "${appRootDir}/${instructionsFileName}"
        echo "1) open a terminal/command prompt to the directory where the prototype code is located" >> "${appRootDir}/${instructionsFileName}"
        echo "2) execute this command: \`make init\`" >> "${appRootDir}/${instructionsFileName}"
        echo "    * This command will run a wizard that will ask you to provide a value for all of " >> "${appRootDir}/${instructionsFileName}"
        echo "    the configuration settings documented above. It will perform a search/replace on " >> "${appRootDir}/${instructionsFileName}"
        echo "    the project files so that they use the values you provide." >> "${appRootDir}/${instructionsFileName}"

        if [[ "$iac" == "terraform" ]]; then
            echo "3) execute this command: \`make deploy-tf-backend-cf-stack\`" >> "${appRootDir}/${instructionsFileName}"
            echo "    * This command will set up an S3 bucket to store your project's Terraform state." >> "${appRootDir}/${instructionsFileName}"

            # Write out step per IaC module
            while IFS= read -d $'\0' -r terraformModuleDir ; do
                terraformModuleDir="${terraformModuleDir%*/}"   # remove the trailing "/"
                terraformModuleDir="${terraformModuleDir##*/}"  # print everything after the final "/"
                iacStepNumber=$((iacStepNumber + 1))
                if [[ "$terraformModuleDir" != "cicd" ]]; then
                    echo "${iacStepNumber}) execute this command: \`make deploy-${terraformModuleDir}\`" >> "${appRootDir}/${instructionsFileName}"
                fi
            done < <(find "${appRootDir}$projectIacRootModulePath" -mindepth 1 -maxdepth 1 -type d -print0)

        elif [[ "$iac" == "cdk2" ]]; then
            echo "3) execute this command: \`make deploy-cdk2-bootstrap-cf-stack\`" >> "${appRootDir}/${instructionsFileName}"
            echo "    * This command will set up the AWS account for use with CDK in your chosen region." >> "${appRootDir}/${instructionsFileName}"
            echo "    If your account has already been set up for CDK, you can skip this step, but it is" >> "${appRootDir}/${instructionsFileName}"
            echo "    also harmless to run this step even if CDK has already been set up." >> "${appRootDir}/${instructionsFileName}"

            # Write out step per IaC module
            while IFS= read -d $'\0' -r cdkModuleDir ; do 
                cdkModuleDir="${cdkModuleDir%*/}"   # remove the trailing "/"
                cdkModuleDir="${cdkModuleDir##*/}"  # print everything after the final "/"
                iacStepNumber=$((iacStepNumber + 1))
                if [[ "$cdkModuleDir" != "cicd" ]]; then
                    echo "${iacStepNumber}) execute this command: \`make deploy-${cdkModuleDir}\`" >> "${appRootDir}/${instructionsFileName}"
                fi
            done < <(find "${appRootDir}$projectIacRootModulePath" -mindepth 1 -maxdepth 1 -type d -print0)
        fi

    else
        echo -e "\n## Setting the variable values\n" >> "${appRootDir}/${instructionsFileName}"

        if [[ "$iac" == "terraform" ]]; then
            echo -e "The prototype code contains placeholders for all of the above variables. The placeholders are made easy to see by being surrounded with \"###\". For example, some files contain ###AWS_ACCOUNT_ID###. Before running the prototype's Terraform, you will need to replace all of the placeholders with real values. This can be done by using a search and replace tool for each of the above variables." >> "${appRootDir}/${instructionsFileName}" 

            echo -e "\nFor reference, here are the files in the project that contain placeholders that must be resolved by you manually:\n" >> "${appRootDir}/${instructionsFileName}"

            coinTemplateFilePaths="$(get_template_files)"

            echo -e "\`\`\`" >> "${appRootDir}/${instructionsFileName}"
            # Exclude the deployment documentation file being generated from the list
            echo -e "$coinTemplateFilePaths" | grep -vE "(${instructionsFileName}|Makefile|.md)" >> "${appRootDir}/${instructionsFileName}"
            echo -e "\`\`\`" >> "${appRootDir}/${instructionsFileName}"

        elif [[ "$iac" == "cdk2" ]]; then
            echo -e "Update the environment variable values set in the \`set-env-vars.sh\` script. Next, copy the contents of the script and paste them into your shell. This has the effect of setting all of the environment variables that the prototype CDK code relies on.\n" >> "${appRootDir}/${instructionsFileName}"
            echo -e "Note: Windows users will need to update the script to use Windows-supported syntax." >> "${appRootDir}/${instructionsFileName}"
        fi
    fi

fi
# END INSTRUCTIONS FOR SETTING CONFIGURATION VARIABLES WITHOUT COIN ------------------------

# BEGIN TERRAFORM STATE SECTION -------------------------------------------------
if [[ "$iac" == "terraform" ]] && [[ "$includeMakefile" == "n" ]]; then

    echo -e "\n## Preparing to run the Terraform\n" >> "${appRootDir}/${instructionsFileName}"
    echo -e "Terraform needs to store its state somewhere. It uses this to track the differences between what has already been deployed and what the configurations look like in \`.tf\` files (you can put the state file anywhere). The prototype development team chose to store the Terraform state in an S3 bucket. Each \`backend.tf\` file is configured to use S3 but you can change that if you like. If you use S3 to store the Terraform state, you'll need to create the S3 bucket before you run any Terraform." >> "${appRootDir}/${instructionsFileName}"

    if [[ "$isUseCoinForDeployment" == "y" ]]; then
        echo -e "To create the S3 bucket, run the following command: \`make deploy-tf-backend-cf-stack\`" >> "${appRootDir}/${instructionsFileName}"

    else

        if [[ " ${ENV_KEYS[*]} " =~ " AWS_SECONDARY_REGION " ]]; then
            echo -e "\n__Info__" >> "${appRootDir}/${instructionsFileName}"
            echo -e "  * You'll need to run all of these commands, which end up calling aws cloudformation deploy 3 separate times with slightly different parameters." >> "${appRootDir}/${instructionsFileName}"
            echo -e "  * Running the steps in this way will set up an S3 bucket in each region for the Terraform state and each bucket will automatically replicate changes to the other region so that you can still execute Terraform even if there is an S3 outage in one of your chosen regions." >> "${appRootDir}/${instructionsFileName}"
        fi

        echo -e "To create the S3 bucket, log in using the AWS CLI and execute the following commands after updating the placeholders marked with \"\<angle-brackets>\" (will need to change if running on a Windows machine):\n" >> "${appRootDir}/${instructionsFileName}"
        echo -e "\`\`\`" >> "${appRootDir}/${instructionsFileName}"

        echo -e "export TF_S3_BACKEND_NAME=<your-bucket-name>" >> "${appRootDir}/${instructionsFileName}"
        echo -e "export APP_NAME=<your-app-name>" >> "${appRootDir}/${instructionsFileName}"
        echo -e "export ENV_NAME=<your-env-name>" >> "${appRootDir}/${instructionsFileName}"

        if [[ " ${ENV_KEYS[*]} " =~ " AWS_SECONDARY_REGION " ]]; then
            echo -e "export AWS_PRIMARY_REGION=<your-primary-region>" >> "${appRootDir}/${instructionsFileName}"
            echo -e "export AWS_SECONDARY_REGION=<your-secondary-region>" >> "${appRootDir}/${instructionsFileName}"
        else
            echo -e "export AWS_DEFAULT_REGION=<your-primary-region>" >> "${appRootDir}/${instructionsFileName}"
        fi
        
        echo -e "\ncd iac/bootstrap" >> "${appRootDir}/${instructionsFileName}"
        
        echo -e "\naws cloudformation deploy \\" >> "${appRootDir}/${instructionsFileName}"
        echo -e "--template-file tf-backend-cf-stack.yml \\" >> "${appRootDir}/${instructionsFileName}"
        echo -e "--parameter-overrides file://parameters.json \\" >> "${appRootDir}/${instructionsFileName}"
        echo -e "--stack-name \$TF_S3_BACKEND_NAME \\" >> "${appRootDir}/${instructionsFileName}"
        echo -e "--capabilities CAPABILITY_NAMED_IAM \\" >> "${appRootDir}/${instructionsFileName}"
        echo -e "--no-fail-on-empty-changeset \\" >> "${appRootDir}/${instructionsFileName}"
        echo -e "--tags App=\$APP_NAME Env=\$ENV_NAME \\" >> "${appRootDir}/${instructionsFileName}"

        if [[ " ${ENV_KEYS[*]} " =~ " AWS_SECONDARY_REGION " ]]; then
            echo -e "--region \$AWS_PRIMARY_REGION" >> "${appRootDir}/${instructionsFileName}"
        else
            echo -e "--region \$AWS_DEFAULT_REGION" >> "${appRootDir}/${instructionsFileName}"
        fi
        
        if [[ " ${ENV_KEYS[*]} " =~ " AWS_SECONDARY_REGION " ]]; then

            echo -e "\naws cloudformation deploy \\" >> "${appRootDir}/${instructionsFileName}"
            echo -e "--template-file tf-backend-cf-stack.yml \\" >> "${appRootDir}/${instructionsFileName}"
            echo -e "--parameter-overrides file://parameters-secondary.json \\" >> "${appRootDir}/${instructionsFileName}"
            echo -e "--stack-name \$TF_S3_BACKEND_NAME \\" >> "${appRootDir}/${instructionsFileName}"
            echo -e "--capabilities CAPABILITY_NAMED_IAM \\" >> "${appRootDir}/${instructionsFileName}"
            echo -e "--no-fail-on-empty-changeset \\" >> "${appRootDir}/${instructionsFileName}"
            echo -e "--tags App=\$APP_NAME Env=\$ENV_NAME \\" >> "${appRootDir}/${instructionsFileName}"
            echo -e "--region \$AWS_SECONDARY_REGION" >> "${appRootDir}/${instructionsFileName}"

            echo -e "\naws cloudformation deploy \\" >> "${appRootDir}/${instructionsFileName}"
            echo -e "--template-file tf-backend-cf-stack.yml \\" >> "${appRootDir}/${instructionsFileName}"
            echo -e "--parameter-overrides file://parameters-crr.json \\" >> "${appRootDir}/${instructionsFileName}"
            echo -e "--stack-name \$TF_S3_BACKEND_NAME \\" >> "${appRootDir}/${instructionsFileName}"
            echo -e "--capabilities CAPABILITY_NAMED_IAM \\" >> "${appRootDir}/${instructionsFileName}"
            echo -e "--no-fail-on-empty-changeset \\" >> "${appRootDir}/${instructionsFileName}"
            echo -e "--tags App=\$APP_NAME Env=\$ENV_NAME \\" >> "${appRootDir}/${instructionsFileName}"
            echo -e "--region \$AWS_PRIMARY_REGION" >> "${appRootDir}/${instructionsFileName}"
        fi
        
        echo -e "\`\`\`" >> "${appRootDir}/${instructionsFileName}"

    fi

fi

# END TERRAFORM STATE SECTION -------------------------------------------------

# BEGIN RUNNING IAC SECTION -------------------------------------------------

if [[ "$isUseCoinForDeployment" == "y" ]]; then

    echo -e "\n## Running the $iacDeployToolName\n" >> "${appRootDir}/${instructionsFileName}"
    echo -e "To deploy the project, run the following command: \`make deploy-all\`" >> "${appRootDir}/${instructionsFileName}"
    echo -e "To deploy an individual $iacDeployToolName module, look at the deploy-all target to find the Make target name for that module." >> "${appRootDir}/${instructionsFileName}"

elif [[ "$includeMakefile" == "n" ]]; then
    echo -e "\n## Running the $iacDeployToolName\n" >> "${appRootDir}/${instructionsFileName}"
    echo -e "The $iacDeployToolName modules need to be run in a specific order the first time they are executed. Before running the below commands, log in using the AWS CLI to the AWS account you intend to deploy to." >> "${appRootDir}/${instructionsFileName}"

    if [[ "$iac" == "terraform" ]]; then

        echo -e "\`\`\`" >> "${appRootDir}/${instructionsFileName}"

        while IFS= read -d $'\0' -r terraformModuleDir ; do 
            terraformModuleDir="${terraformModuleDir%*/}"   # remove the trailing "/"
            terraformModuleDir="${terraformModuleDir##*/}"  # print everything after the final "/"

            if [[ "$terraformModuleDir" != "cicd" ]]; then
                echo -e "\ncd iac/roots/${terraformModuleDir}" >> "${appRootDir}/${instructionsFileName}"
                echo -e "terraform init" >> "${appRootDir}/${instructionsFileName}"
                echo -e "terraform plan -out=tfplan" >> "${appRootDir}/${instructionsFileName}"
                echo -e "terraform apply tfplan" >> "${appRootDir}/${instructionsFileName}"
            fi

        done < <(find "${appRootDir}$projectIacRootModulePath" -mindepth 1 -maxdepth 1 -type d -print0)

        echo -e "\`\`\`" >> "${appRootDir}/${instructionsFileName}"

    elif [[ "$iac" == "cdk2" ]]; then

        echo -e "\`\`\`" >> "${appRootDir}/${instructionsFileName}"

        while IFS= read -d $'\0' -r cdkModuleDir ; do 
            cdkModuleDir="${cdkModuleDir%*/}"   # remove the trailing "/"
            cdkModuleDir="${cdkModuleDir##*/}"  # print everything after the final "/"

            if [[ "$cdkModuleDir" != "cicd" ]]; then
                echo -e "\ncd iac/roots/${cdkModuleDir}" >> "${appRootDir}/${instructionsFileName}"
                echo -e "$coinPackageManager install" >> "${appRootDir}/${instructionsFileName}"
                echo -e "./node_modules/aws-cdk/bin/cdk deploy" >> "${appRootDir}/${instructionsFileName}"
            fi

        done < <(find "${appRootDir}$projectIacRootModulePath" -mindepth 1 -maxdepth 1 -type d -print0)

        echo -e "\`\`\`" >> "${appRootDir}/${instructionsFileName}"

    fi

fi

# END RUNNING IAC SECTION -------------------------------------------------

display "\n${GREEN}Congratulations! The deployment instructions have been written to \"${appRootDir}/${instructionsFileName}\"!${NC}\n"
