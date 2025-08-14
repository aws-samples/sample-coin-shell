#!/usr/bin/env bash

# This script is a wizard that will generate a new root infrastructure as code module for you
# It is not intended to be used to create lower-level reusable modules.

scriptDir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$scriptDir/utility-functions.sh" "source create_iac_module" 1> /dev/null

display "\nWelcome to the Create New Root IaC Module Wizard!\n"

validate_bash_version
detect_and_set_iac_type

# Exports (as environment variables) all values defined in the supplied .json
# file so that this wizard can run in headless mode.
# param1: a working path (absolute or relative) to the JSON file 
#         containing wizard answers
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

    [[ ! "$newIacModuleName" =~ ^[^[:space:]]{1,80}$ ]] && \
    displayIssue "\"newIacModuleName\" value is invalid: \"$newIacModuleName\"." "error" && \
    displayIssue "Must not include whitespace and length (${#newIacModuleName}) must be between 1 and 80." && \
    exit 1

    if [[ "$newIacModuleNestedPath" != "${noStartingSlashProjectIacRootModulePath}"* ]]; then
        displayIssue "\"newIacModuleNestedPath\" value is invalid: \"$newIacModuleNestedPath\"." "error"
        displayIssue "Must start with \"${noStartingSlashProjectIacRootModulePath}\"."
        exit 1
    fi

    if [[ "$newIacModuleNestedPath" == "${noStartingSlashProjectIacRootModulePath}" ]]; then
        newIacModuleNestedPath=""
    
    elif [[ "$newIacModuleNestedPath" == */ ]]; then
        # Do not add trailing slash if user-entered value ended in a slash
        newIacModuleNestedPath="${newIacModuleNestedPath#"${noStartingSlashProjectIacRootModulePath}"}"
    else
        # Add trailing slash if user-entered value did not end in a slash
        newIacModuleNestedPath="${newIacModuleNestedPath#"${noStartingSlashProjectIacRootModulePath}"}/"
    fi

    if [[ -z "$newIacModuleNestedPath" ]]; then
        if [[ -d "${projectIacRootModuleDir}/${newIacModuleName}" ]]; then
            displayIssue "There is already an existing module directory at \"${noStartingSlashProjectIacRootModulePath}${newIacModuleName}\"." "error"
            exit 1
        fi
    elif [[ -d "${projectIacRootModuleDir}/${newIacModuleNestedPath}${newIacModuleName}" ]]; then
        displayIssue "There is already an existing module directory at \"${noStartingSlashProjectIacRootModulePath}${newIacModuleNestedPath}${newIacModuleName}\"." "error"
        exit 1
    fi
}

update_make_for_cdk () {

    echo -e "# Resolves all environment variables and executes \"cdk diff\"" >> "$projectDir/Makefile"
    echo -e "# for the $newIacModuleRelPath module" >> "$projectDir/Makefile"
    echo -e "# Takes an optional "args" parameter if you want to add additional arguments to pass to CDK" >> "$projectDir/Makefile"
    echo -e "# usage: " >> "$projectDir/Makefile"
    echo -e "#   make diff-$newIacModuleMakeTargetName" >> "$projectDir/Makefile"
    echo -e "#   OR" >> "$projectDir/Makefile"
    echo -e "#   make diff-$newIacModuleMakeTargetName args=\"myStackId --exclusively\"" >> "$projectDir/Makefile"
    echo -e "diff-$newIacModuleMakeTargetName:" >> "$projectDir/Makefile"
    echo -e "\tCDK_MODE=diff \$(ENV_PATH)utility-functions.sh exec_cdk_for_env $newIacModuleRelPath \"\$(args)\"\n" >> "$projectDir/Makefile"

    echo -e "# Resolves all environment variables and executes \"cdk deploy\"" >> "$projectDir/Makefile"
    echo -e "# for the $newIacModuleRelPath module" >> "$projectDir/Makefile"
    echo -e "# Takes an optional "args" parameter if you want to add additional arguments to pass to CDK" >> "$projectDir/Makefile"
    echo -e "# usage: " >> "$projectDir/Makefile"
    echo -e "#   make deploy-$newIacModuleMakeTargetName" >> "$projectDir/Makefile"
    echo -e "#   OR" >> "$projectDir/Makefile"
    echo -e "#   make deploy-$newIacModuleMakeTargetName args=\"myStackId --exclusively\"" >> "$projectDir/Makefile"
    echo -e "deploy-$newIacModuleMakeTargetName:" >> "$projectDir/Makefile"
    echo -e "\t\$(ENV_PATH)utility-functions.sh exec_cdk_for_env $newIacModuleRelPath \"\$(args)\"\n" >> "$projectDir/Makefile"

    if [[ ! -z "$AWS_SECONDARY_REGION" ]]; then
        echo -e "# Same as deploy-$newIacModuleMakeTargetName but targets the secondary region instead of the primary region" >> "$projectDir/Makefile"
        echo -e "# Takes an optional "args" parameter if you want to add additional arguments to pass to CDK" >> "$projectDir/Makefile"
        echo -e "# usage: " >> "$projectDir/Makefile"
        echo -e "#   make deploy-$newIacModuleMakeTargetName-secondary-region" >> "$projectDir/Makefile"
        echo -e "#   OR" >> "$projectDir/Makefile"
        echo -e "#   make deploy-$newIacModuleMakeTargetName-secondary-region args=\"myStackId --exclusively\"" >> "$projectDir/Makefile"
        echo -e "deploy-$newIacModuleMakeTargetName-secondary-region:" >> "$projectDir/Makefile"
        echo -e "\tCOIN_OVERRIDE_AWS_DEFAULT_REGION=\$(AWS_SECONDARY_REGION) \$(ENV_PATH)utility-functions.sh exec_cdk_for_env $newIacModuleRelPath \"\$(args)\"\n" >> "$projectDir/Makefile"
    fi
    
    echo -e "# Resolves all environment variables and executes \"cdk destroy\"" >> "$projectDir/Makefile"
    echo -e "# for the $newIacModuleRelPath module" >> "$projectDir/Makefile"
    echo -e "# Takes an optional "args" parameter if you want to add additional arguments to pass to CDK" >> "$projectDir/Makefile"
    echo -e "# usage: " >> "$projectDir/Makefile"
    echo -e "#   make destroy-$newIacModuleMakeTargetName" >> "$projectDir/Makefile"
    echo -e "#   OR" >> "$projectDir/Makefile"
    echo -e "#   make destroy-$newIacModuleMakeTargetName args=\"myStackId --exclusively\"" >> "$projectDir/Makefile"
    echo -e "destroy-$newIacModuleMakeTargetName:" >> "$projectDir/Makefile"
    echo -e "\tCDK_MODE=destroy \$(ENV_PATH)utility-functions.sh exec_cdk_for_env $newIacModuleRelPath \"\$(args)\"" >> "$projectDir/Makefile"
}

update_customer_make_for_cdk () {
    echo -e "deploy-$newIacModuleMakeTargetName:" >> "$projectDir/Makefile-4-customer"
    echo -e "\t@echo \"Deploying $newIacModuleRelPath module\"" >> "$projectDir/Makefile-4-customer"
    echo -e "\t@(\\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t  . ./set-env-vars.sh; \\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t  cd $newIacModuleRootRelPath; \\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t  $coinPackageManager install; \\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t  cdk deploy --require-approval never \\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t)" >> "$projectDir/Makefile-4-customer"
    echo -e "\t@echo \"Finished deploying $newIacModuleRelPath module\"\n" >> "$projectDir/Makefile-4-customer"

    echo -e "destroy-$newIacModuleMakeTargetName:" >> "$projectDir/Makefile-4-customer"
    echo -e "\t@echo \"Destroying $newIacModuleName module\"" >> "$projectDir/Makefile-4-customer"
    echo -e "\t@(\\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t  . ./set-env-vars.sh; \\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t  cd $newIacModuleRootRelPath; \\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t  $coinPackageManager install; \\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t  cdk destroy --force \\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t)" >> "$projectDir/Makefile-4-customer"
    echo -e "\t@echo \"Finished destroying $newIacModuleName module\"\n" >> "$projectDir/Makefile-4-customer"
}

update_make_for_terraform () {

    echo -e "# Resolves all environment variables in template files, executes \"terraform plan\"" >> "$projectDir/Makefile"
    echo -e "# for the $newIacModuleRelPath module, then restores template files to their original content" >> "$projectDir/Makefile"
    echo -e "# Takes an optional "args" parameter if you want to add additional arguments to pass to terraform" >> "$projectDir/Makefile"
    echo -e "# usage: " >> "$projectDir/Makefile"
    echo -e "# \tplan-$newIacModuleMakeTargetName" >> "$projectDir/Makefile" 
    echo -e "# \tOR" >> "$projectDir/Makefile"
    echo -e "# \tmake plan-$newIacModuleMakeTargetName args=\"-out tf.plan\"" >> "$projectDir/Makefile"
    echo -e "plan-$newIacModuleMakeTargetName:" >> "$projectDir/Makefile"
    echo -e "\tTF_MODE=plan \$(ENV_PATH)utility-functions.sh exec_tf_for_env $newIacModuleRelPath \"\$(args)\"\n" >> "$projectDir/Makefile"

    echo -e "# Resolves all environment variables in template files, executes \"terraform apply\"" >> "$projectDir/Makefile"
    echo -e "# for the $newIacModuleRelPath module, then restores template files to their original content" >> "$projectDir/Makefile"
    echo -e "# Takes an optional "args" parameter if you want to add additional arguments to pass to terraform" >> "$projectDir/Makefile"
    echo -e "# usage: " >> "$projectDir/Makefile"
    echo -e "# \tdeploy-$newIacModuleMakeTargetName" >> "$projectDir/Makefile" 
    echo -e "# \tOR" >> "$projectDir/Makefile"
    echo -e "# \tmake deploy-$newIacModuleMakeTargetName args=\"-target module.example\"" >> "$projectDir/Makefile"
    echo -e "deploy-$newIacModuleMakeTargetName:" >> "$projectDir/Makefile"
    echo -e "\t\$(ENV_PATH)utility-functions.sh exec_tf_for_env $newIacModuleRelPath \"\$(args)\"\n" >> "$projectDir/Makefile"

    echo -e "# Resolves all environment variables in template files, executes \"terraform destroy\"" >> "$projectDir/Makefile"
    echo -e "# for the $newIacModuleRelPath module, then restores template files to their original content" >> "$projectDir/Makefile"
    echo -e "# Takes an optional "args" parameter if you want to add additional arguments to pass to terraform" >> "$projectDir/Makefile"
    echo -e "# usage: " >> "$projectDir/Makefile"
    echo -e "# \tdestroy-$newIacModuleMakeTargetName" >> "$projectDir/Makefile" 
    echo -e "# \tOR" >> "$projectDir/Makefile"
    echo -e "# \tmake destroy-$newIacModuleMakeTargetName args=\"-target module.example\"" >> "$projectDir/Makefile"
    echo -e "destroy-$newIacModuleMakeTargetName:" >> "$projectDir/Makefile"
    echo -e "\tTF_MODE=destroy \$(ENV_PATH)utility-functions.sh exec_tf_for_env $newIacModuleRelPath \"\$(args)\"" >> "$projectDir/Makefile"
}

update_customer_make_for_terraform () {
    echo -e "deploy-$newIacModuleMakeTargetName:" >> "$projectDir/Makefile-4-customer"
    echo -e "\t@echo \"Deploying $newIacModuleRelPath module\"" >> "$projectDir/Makefile-4-customer"
    echo -e "\t@(\\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t  cd $newIacModuleRootRelPath; \\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t  terraform init; \\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t  terraform apply -auto-approve; \\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t)" >> "$projectDir/Makefile-4-customer"
    echo -e "\t@echo \"Finished deploying $newIacModuleRelPath module\"\n" >> "$projectDir/Makefile-4-customer"

    echo -e "destroy-$newIacModuleMakeTargetName:" >> "$projectDir/Makefile-4-customer"
    echo -e "\t@echo \"Destroying $newIacModuleRelPath module\"" >> "$projectDir/Makefile-4-customer"
    echo -e "\t@(\\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t  cd $newIacModuleRootRelPath; \\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t  terraform init; \\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t  terraform destroy -auto-approve; \\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t)" >> "$projectDir/Makefile-4-customer"
    echo -e "\t@echo \"Finished destroying $newIacModuleRelPath module\"\n" >> "$projectDir/Makefile-4-customer"
}

update_make_for_cloudformation () {

    echo -e "# Resolves all environment variables in template files, executes \"cloudformation deploy \"" >> "$projectDir/Makefile"
    echo -e "# for the $newIacModuleRelPath module, then restores template files to their original content" >> "$projectDir/Makefile"
    echo -e "deploy-$newIacModuleMakeTargetName:" >> "$projectDir/Makefile"
    echo -e "\t\$(ENV_PATH)utility-functions.sh exec_cf_for_env $newIacModuleRelPath\n" >> "$projectDir/Makefile"

    echo -e "# Resolves all environment variables in template files, executes \"cloudformation delete-stack\"" >> "$projectDir/Makefile"
    echo -e "# for the $newIacModuleRelPath module, then restores template files to their original content" >> "$projectDir/Makefile"
    echo -e "destroy-$newIacModuleMakeTargetName:" >> "$projectDir/Makefile"
    echo -e "\t\$(ENV_PATH)utility-functions.sh destroy_root_cf_stack_by_name $newIacModuleRelPath" >> "$projectDir/Makefile"
}

update_customer_make_for_cloudformation () {
    echo -e "deploy-$newIacModuleMakeTargetName:" >> "$projectDir/Makefile-4-customer"
    echo -e "\t@echo \"Deploying $newIacModuleRelPath module\"" >> "$projectDir/Makefile-4-customer"
    echo -e "\t@(\\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t  cd $newIacModuleRootRelPath; \\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t  aws cloudformation deploy \\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t  --template-file cf.yml \\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t  --parameter-overrides file://parameters.json \\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t  --stack-name \$(APP_NAME)-\$(ENV_NAME)-$newIacModuleMakeTargetName \\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t  --region \$(AWS_DEFAULT_REGION) \\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t  --capabilities CAPABILITY_NAMED_IAM \\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t  --tags App=\$(APP_NAME) Env=\$(ENV_NAME); \\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t)" >> "$projectDir/Makefile-4-customer"
    echo -e "\t@echo \"Finished deploying $newIacModuleRelPath module\"\n" >> "$projectDir/Makefile-4-customer"

    echo -e "destroy-$newIacModuleMakeTargetName:" >> "$projectDir/Makefile-4-customer"
    echo -e "\t@echo \"Destroying $newIacModuleRelPath module\"" >> "$projectDir/Makefile-4-customer"
    echo -e "\t@(\\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t  cd $newIacModuleRootRelPath; \\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t  aws cloudformation delete-stack \\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t  --stack-name \$(APP_NAME)-\$(ENV_NAME)-$newIacModuleMakeTargetName \\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t  --region \$(AWS_DEFAULT_REGION) \\" >> "$projectDir/Makefile-4-customer"
    echo -e "\t)" >> "$projectDir/Makefile-4-customer"
    echo -e "\t@echo \"Finished destroying $newIacModuleRelPath module\"\n" >> "$projectDir/Makefile-4-customer"
}

log_make_file_changes () {
    display "The Makefile at \"$projectDir/Makefile\" has been updated with deploy and destroy targets for your new module.\n"

    if [[ "$iac" == "cdk2" ]]; then
        display "To perform a CDK diff of your new module, execute the following:"
        displayInColor "\tmake diff-$newIacModuleMakeTargetName\n" "$CYAN"
        display "To perform a CDK deployment of your new module, execute the following:"
        displayInColor "\tmake deploy-$newIacModuleMakeTargetName\n" "$CYAN"
        display "To perform a CDK destroy on your new module, execute the following:"
        displayInColor "\tmake destroy-$newIacModuleMakeTargetName\n" "$CYAN"
    elif [[ "$iac" == "terraform" ]]; then
        display "To perform a Terraform plan of your new module, execute the following:"
        displayInColor "\tmake plan-$newIacModuleMakeTargetName\n" "$CYAN"
        display "To perform a Terraform apply on your new module, execute the following:"
        displayInColor "\tmake deploy-$newIacModuleMakeTargetName\n" "$CYAN"
        display "To perform a Terraform destroy of your new module, execute the following:"
        displayInColor "\tmake destroy-$newIacModuleMakeTargetName\n" "$CYAN"
    elif [[ "$iac" == "cf" ]]; then
        display "To perform a CloudFormation deploy on your new module, execute the following:"
        displayInColor "\tmake deploy-$newIacModuleMakeTargetName\n" "$CYAN"
        display "To perform a CloudFormation delete-stack on your new module, execute the following:"
        displayInColor "\tmake destroy-$newIacModuleMakeTargetName\n" "$CYAN"
    fi

}

noStartingSlashProjectIacRootModulePath="${projectIacRootModulePath#"/"}/" # remove leading / from projectIacRootModulePath, add trailing /

if [[ ! -z "$1" ]]; then
    export HEADLESS="y"

    display "Running in headless mode."

    log "\nHeadless file input:"
    log "$(cat "$1")"

    export_wizard_answers "$1"
    validate_headless_mode_input

else

    if [[ "$iac" == "cdk2" ]]; then
        display "This wizard creates top-level application modules (e.g. those that contain \"new cdk.App()\"). If you want to create a lower-level reusable module instead, exit from this wizard and create it yourself under a directory such as \"${projectIacPath}/constructs\".\n"
    elif [[ "$iac" == "terraform" ]]; then
        display "This wizard creates top-level application modules (e.g. those that contain have their own Terraform state file). If you want to create a lower-level reusable module instead, exit from this wizard and create it yourself under a directory such as \"${projectIacPath}/templates\".\n"
    fi

    if [[ "$iac" == "cdk2" ]] || [[ "$iac" == "terraform" ]]; then
        continueCreating="y"
        yes_or_no continueCreating "Do you want to continue" "y"

        if [[ "$continueCreating" == "n" ]]; then 
            exit 0
        else
            display "" # add new blank line to the console output
        fi
    fi

    length_range newIacModuleName "What is the name of your Infrastructure as Code module (in all lower case with words separated by hyphens)?:" \
    "" "1" "80"

    isNewIacModuleNestedPathValid="n"

    while [[ "$isNewIacModuleNestedPathValid" == "n" ]];
    do
        # Allow users to create modules under nested directories such as "iac/roots/my/nested/module/dir"
        length_range newIacModuleNestedPath "Where should the \"${newIacModuleName}\" module be created in your project?:" \
        "$noStartingSlashProjectIacRootModulePath" "1" "100"

        if [[ "$newIacModuleNestedPath" != "${noStartingSlashProjectIacRootModulePath}"* ]]; then
            displayIssue "The value entered must start with \"${noStartingSlashProjectIacRootModulePath}\"." "error"
            continue
        fi

        if [[ "$newIacModuleNestedPath" == "${noStartingSlashProjectIacRootModulePath}" ]]; then
            newIacModuleNestedPath=""
        
        elif [[ "$newIacModuleNestedPath" == */ ]]; then
            # Do not add trailing slash if user-entered value ended in a slash
            newIacModuleNestedPath="${newIacModuleNestedPath#"${noStartingSlashProjectIacRootModulePath}"}"
        else
            # Add trailing slash if user-entered value did not end in a slash
            newIacModuleNestedPath="${newIacModuleNestedPath#"${noStartingSlashProjectIacRootModulePath}"}/"
        fi

        if [[ -z "$newIacModuleNestedPath" ]]; then
            if [[ -d "${projectIacRootModuleDir}/${newIacModuleName}" ]]; then
                displayIssue "There is already an existing module directory at \"${noStartingSlashProjectIacRootModulePath}${newIacModuleName}\"." "error"
                continue
            fi
        elif [[ -d "${projectIacRootModuleDir}/${newIacModuleNestedPath}${newIacModuleName}" ]]; then
            displayIssue "There is already an existing module directory at \"${noStartingSlashProjectIacRootModulePath}${newIacModuleNestedPath}${newIacModuleName}\"." "error"
            continue
        fi

        isNewIacModuleNestedPathValid="y"

    done

fi

newIacModuleAbsPath="${projectIacRootModuleDir}/${newIacModuleNestedPath}${newIacModuleName}"
newIacModuleRootRelPath="${noStartingSlashProjectIacRootModulePath}${newIacModuleNestedPath}${newIacModuleName}"
newIacModuleRelPath="${newIacModuleNestedPath}${newIacModuleName}"
newIacModuleMakeTargetName="${newIacModuleRelPath//\//-}"
log "\n newIacModuleAbsPath: ${newIacModuleAbsPath}"
log " newIacModuleRootRelPath: ${newIacModuleRootRelPath}"
log " newIacModuleRelPath: ${newIacModuleRelPath}"
log " newIacModuleMakeTargetName: ${newIacModuleMakeTargetName}"

newIacModuleNameUpper="$(spinalcase_to_camelcase "$newIacModuleName")"
log "\nCamel case of new IaC module is $newIacModuleNameUpper\n"

# We want to insert Make commands for the new module right above the deploy-all command,
# if it is present

insertLineNo=$(grep -n "deploy-all:" "$projectDir/Makefile" | cut -d : -f 1)
if [[ -z "$insertLineNo" ]]; then
    insertLineNo=$(wc -l < "$projectDir/Makefile")
    insertLineNo=$((insertLineNo + 1)) 
else
    # Get line above comment line for deploy-all
    insertLineNo=$((insertLineNo - 2)) 
fi

# Send the deploy-all and destroy-all targets to a temporary file
tail -n "+${insertLineNo}" "$projectDir/Makefile" > "$projectDir/Makefile-end"

# effectively deletes everything starting with the deploy-all command
mv "$projectDir/Makefile" "$projectDir/Makefile-tmp"
head -n "$insertLineNo" "$projectDir/Makefile-tmp" > "$projectDir/Makefile"
rm "$projectDir/Makefile-tmp"

# Check if Makefile-4-customer is present so that we can add IaC module targets there too
if [[ -f "$projectDir/Makefile-4-customer" ]]; then
    forCustomerInsertLineNo=$(grep -n "deploy-all:" "$projectDir/Makefile-4-customer" | cut -d : -f 1)

    if [[ -z "$forCustomerInsertLineNo" ]]; then
        forCustomerInsertLineNo=$(wc -l < "$projectDir/Makefile-4-customer")
        forCustomerInsertLineNo=$((forCustomerInsertLineNo + 1)) 
    else
        # Get line above comment line for deploy-all
        forCustomerInsertLineNo=$((forCustomerInsertLineNo - 2)) 
    fi

    # Send the deploy-all and destroy-all targets to a temporary file
    tail -n "+${forCustomerInsertLineNo}" "$projectDir/Makefile-4-customer" > "$projectDir/Makefile-4-customer-end"

    # effectively deletes everything starting with the deploy-all command
    mv "$projectDir/Makefile-4-customer" "$projectDir/Makefile-4-customer-tmp"
    head -n "$forCustomerInsertLineNo" "$projectDir/Makefile-4-customer-tmp" > "$projectDir/Makefile-4-customer"
    rm "$projectDir/Makefile-4-customer-tmp"
fi

mkdir -p "$newIacModuleAbsPath"
cp -r "$projectEnvDir/iac-module-template/." "$newIacModuleAbsPath"

resolve_template_files_from_pattern "$newIacModuleAbsPath" "s|###COIN_IAC_MOD_CAMELCASE###|$newIacModuleNameUpper|;s|###COIN_IAC_MOD_SPINALCASE###|$newIacModuleName|;"

display "\n${GREEN}Congratulations! The \"$newIacModuleRelPath\" IaC module has been created!${NC}\n"

display "The module code is located at $newIacModuleAbsPath"

if [[ "$iac" == "cdk2" ]]; then
    update_make_for_cdk
    cat "$projectDir/Makefile-end" >> "$projectDir/Makefile"
    rm "$projectDir/Makefile-end"
    if [[ -f "$projectDir/Makefile-4-customer" ]]; then
        update_customer_make_for_cdk
        cat "$projectDir/Makefile-4-customer-end" >> "$projectDir/Makefile-4-customer"
        rm "$projectDir/Makefile-4-customer-end"
    fi
    log_make_file_changes
elif [[ "$iac" == "terraform" ]]; then
    update_make_for_terraform
    cat "$projectDir/Makefile-end" >> "$projectDir/Makefile"
    rm "$projectDir/Makefile-end"
    if [[ -f "$projectDir/Makefile-4-customer" ]]; then
        update_customer_make_for_terraform
        cat "$projectDir/Makefile-4-customer-end" >> "$projectDir/Makefile-4-customer"
        rm "$projectDir/Makefile-4-customer-end"
    fi
    log_make_file_changes
elif [[ "$iac" == "cf" ]]; then
    update_make_for_cloudformation
    cat "$projectDir/Makefile-end" >> "$projectDir/Makefile"
    rm "$projectDir/Makefile-end"
    if [[ -f "$projectDir/Makefile-4-customer" ]]; then
        update_customer_make_for_cloudformation
        cat "$projectDir/Makefile-4-customer-end" >> "$projectDir/Makefile-4-customer"
        rm "$projectDir/Makefile-4-customer-end"
    fi
    log_make_file_changes
else
    displayIssue "Failed to update Makefile at \"$projectDir/Makefile\" with deploy and destroy targets since IaC type could not be detected." "error"
fi
