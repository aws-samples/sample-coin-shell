#!/usr/bin/env bats

setup_file () {
    load '../../../test-helper/common-setup'
    _common_setup

    appParentDir="/tmp/"
    gitProjectName="bats-cdk-local-deploy-nothing"
    generatedAppDir="${appParentDir}${gitProjectName}"
    inputFileName="/tmp/create-cdk-app-headless-input.json"
    firstIacModuleName="example"
    
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "$appParentDir",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n",
        "useCicd": "n",
        "hasSecondaryRegion": "n",
        "AWS_SECONDARY_REGION": "blank",
        "AWS_ACCOUNT_ID": "000000000000",
        "iac": "cdk2",
        "REMOTE_ENV_VAR_LOC": "na",
        "APP_NAME": "cbat",
        "AWS_DEFAULT_REGION": "us-east-1",
        "CREATED_BY": "Anthony Watson",
        "ENV_NAME": "dev",
        "firstIacModuleName": "$firstIacModuleName",
        "gitProjectName": "$gitProjectName",
        "TF_S3_BACKEND_NAME": "blank"
    }
EOF

    # use for debugging:
    # cat $inputFileName >&3

    run create_cdk_app "$inputFileName"
    
    assert_output --partial "Congratulations! Your application has been created at ${generatedAppDir}"
    assert_output --partial "A CDK v2 module has been created for you under your project's /iac/roots/${firstIacModuleName} directory"
    assert_exists "$generatedAppDir"
}

teardown_file () {
    rm -f "$inputFileName"
    rm -rf "$generatedAppDir"
}

setup () {
    load '../../../test-helper/common-setup'
    _common_setup

    appParentDir="/tmp/"
    gitProjectName="bats-cdk-local-deploy-nothing"
    generatedAppDir="${appParentDir}${gitProjectName}"
    generatedAppEnvDir="${generatedAppDir}/environment"
    generatedAppEnvLogFile="${generatedAppEnvDir}/.log.txt"
    iacDir="${generatedAppDir}/iac"
    iacRootsDir="${iacDir}/roots"
    createAppIacModuleLogFile="$generatedAppDir/environment/.log.txt"
    createAppIacModuleInputFileName="/tmp/create-cdk-app-iac-module-headless-input.json"
    generateIacModuleScriptPath="${generatedAppDir}/environment/create-iac-module.sh"
}

teardown () {
    :
}

create_cdk_app () {
    create-app.sh "$1" 2>&1
}

create_cdk_app_iac_module () {
    "$generateIacModuleScriptPath" "$1" 2>&1
}

# Returns the input validation error message on one line and the reason the validation failed on the next line
# Example:
#   ERROR: "ENV_NAME" value is invalid: "aReallyLongInvalidValue".
#   Must not include whitespace and length (23) must be between 1 and 10.
get_input_validation_full_error_message() {
    # The sed pattern below gets rid of ANSI color codes in the output. These hidden characters will cause
    # assertions on the output to fail
    "$generateIacModuleScriptPath" "$1" 2>&1 | grep -A 1 "ERROR:" | sed -e 's/\x1b\[[0-9;]*m//g'
}

# bats file_tags=type:functional, suite:create-app-environment, generate:iac-module

@test "detects newIacModuleName is missing" {
    newIacModuleNestedPath="iac/roots/nested1/nested2"

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$createAppIacModuleInputFileName"
    {
        "newIacModuleName": "",
        "newIacModuleNestedPath": "$newIacModuleNestedPath"
    }
EOF

    # cat "$createAppIacModuleInputFileName" >&3

    run get_input_validation_full_error_message "$createAppIacModuleInputFileName"

    assert_line --index 0 'ERROR: "newIacModuleName" value is invalid: "".'
    assert_line --index 1 'Must not include whitespace and length (0) must be between 1 and 80.'

    assert_not_exists "$generatedAppDir/$newIacModuleNestedPath/$newIacModuleName"
    
    # use for debugging:
    # echo -e "\n\n\n" >&3
    # cat "$createAppIacModuleLogFile" >&3
}


@test "detects newIacModuleNestedPath is missing" {
    newIacModuleName="new-module"

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$createAppIacModuleInputFileName"
    {
        "newIacModuleName": "$newIacModuleName",
        "newIacModuleNestedPath": ""
    }
EOF

    # cat "$createAppIacModuleInputFileName" >&3

    run get_input_validation_full_error_message "$createAppIacModuleInputFileName"

    assert_line --index 0 'ERROR: "newIacModuleNestedPath" value is invalid: "".'
    assert_line --index 1 'Must start with "iac/roots/".'

    assert_not_exists "$generatedAppDir/$newIacModuleNestedPath/$newIacModuleName"
    
    # use for debugging:
    # echo -e "\n\n\n" >&3
    # cat "$createAppIacModuleLogFile" >&3
}

@test "detects newIacModuleNestedPath is invalid" {
    newIacModuleName="new-module"
    newIacModuleNestedPath="invalidValue"

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$createAppIacModuleInputFileName"
    {
        "newIacModuleName": "$newIacModuleName",
        "newIacModuleNestedPath": "$newIacModuleNestedPath"
    }
EOF

    # cat "$createAppIacModuleInputFileName" >&3

    run get_input_validation_full_error_message "$createAppIacModuleInputFileName"

    assert_line --index 0 "ERROR: \"newIacModuleNestedPath\" value is invalid: \"$newIacModuleNestedPath\"."
    assert_line --index 1 'Must start with "iac/roots/".'

    assert_not_exists "$generatedAppDir/$newIacModuleNestedPath/$newIacModuleName"
    
    # use for debugging:
    # echo -e "\n\n\n" >&3
    # cat "$createAppIacModuleLogFile" >&3
}

@test "detects module already exists" {
    newIacModuleName="example"
    newIacModuleNestedPath="iac/roots/"

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$createAppIacModuleInputFileName"
    {
        "newIacModuleName": "$newIacModuleName",
        "newIacModuleNestedPath": "$newIacModuleNestedPath"
    }
EOF

    # cat "$createAppIacModuleInputFileName" >&3

    run get_input_validation_full_error_message "$createAppIacModuleInputFileName"

    assert_line --index 0 "ERROR: There is already an existing module directory at \"${newIacModuleNestedPath}${newIacModuleName}\"."
    
    # use for debugging:
    # echo -e "\n\n\n" >&3
    # cat "$createAppIacModuleLogFile" >&3
}