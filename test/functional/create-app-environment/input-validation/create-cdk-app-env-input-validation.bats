#!/usr/bin/env bats

# Create a new CDK app
setup_file () {
    load '../../../test-helper/common-setup'
    _common_setup

    appParentDir="/tmp/"
    gitProjectName="bats-cdk-local-deploy-nothing"
    generatedAppDir="${appParentDir}${gitProjectName}"
    createAppInputFileName="/tmp/create-cdk-app-headless-input.json"
    firstIacModuleName="example"
    
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$createAppInputFileName"
    {
        "appParentDir": "$appParentDir",
        "cicd": "gitlab",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n",
        "useCicd": "y",
        "hasSecondaryRegion": "y",
        "AWS_SECONDARY_REGION": "us-west-2",
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
    # cat $createAppInputFileName >&3

    run create_cdk_app "$createAppInputFileName"
    
    assert_output --partial "Congratulations! Your application has been created at ${generatedAppDir}"
    assert_output --partial "A CDK v2 module has been created for you under your project's /iac/roots/${firstIacModuleName} directory"
    assert_exists "$generatedAppDir"

    # Add an application-specific variable to ensure that input validation will require a value for it
    echo -e "\n# Does something custom\nMY_CUSTOM_VAR" >> "$generatedAppDir/environment/app-env-var-names.txt"
}

teardown_file () {
    rm -f "$createAppInputFileName"
    rm -rf "$generatedAppDir"
}

setup () {
    load '../../../test-helper/common-setup'
    _common_setup

    source "$COIN_ROOT_DIR/environment/aws-regions.sh"

    appParentDir="/tmp/"
    gitProjectName="bats-cdk-local-deploy-nothing"
    generatedAppDir="${appParentDir}${gitProjectName}"
    generatedAppEnvDir="${generatedAppDir}/environment"
    generateEnvScriptPath="${generatedAppEnvDir}/create-app-environment.sh"
    createAppEnvInputFileName="/tmp/create-cdk-app-env-headless-input.json"
    createAppEnvLogFile="$generatedAppEnvDir/.log.txt"
}

teardown () {
    :
}

create_cdk_app () {
    create-app.sh "$1" 2>&1
}

# Kicks off the environment creation wizard and does not do any output filtering
create_app_env() {
    "$generateEnvScriptPath" "$1" 2>&1
}

# Returns the input validation error message only
# Example:
#   ERROR: "ENV_NAME" value is invalid: "aReallyLongInvalidValue".
get_input_validation_error_message() {
    # The sed pattern below gets rid of ANSI color codes in the output. These hidden characters will cause
    # assertions on the output to fail
    "$generateEnvScriptPath" "$1" 2>&1 | grep "ERROR:" | sed -e 's/\x1b\[[0-9;]*m//g'
}

# Returns the input validation error message on one line and the reason the validation failed on the next line
# Example:
#   ERROR: "ENV_NAME" value is invalid: "aReallyLongInvalidValue".
#   Must not include whitespace and length (23) must be between 1 and 10.
get_input_validation_full_error_message() {
    # The sed pattern below gets rid of ANSI color codes in the output. These hidden characters will cause
    # assertions on the output to fail
    "$generateEnvScriptPath" "$1" 2>&1 | grep -A 1 "ERROR:" | sed -e 's/\x1b\[[0-9;]*m//g'
}

# bats file_tags=type:functional, suite:create-app-environment, generate:app-env, category:input-validation

@test "detect create app environment structurally invalid json" {
    echo '{ should contain double-quoted key-value pairs }' > "$createAppEnvInputFileName"

    run get_input_validation_error_message "$createAppEnvInputFileName"
    assert_output 'ERROR: Headless input contains structurally invalid JSON'
}

@test "detects AWS_ACCOUNT_ID is missing" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$createAppEnvInputFileName"
    {
        "fakeKey": "fakeValue"
    }
EOF

    # use for debugging:
    # echo "createAppEnvInputFileName is $createAppEnvInputFileName" >&3
    # cat $createAppEnvInputFileName >&3
    # echo -e "\n\n\n" >&3

    run get_input_validation_full_error_message "$createAppEnvInputFileName"

    # use for debugging:
    # echo -e "\n\n\n" >&3
    # cat "$createAppEnvLogFile" >&3
    
    assert_line --index 0 'ERROR: invalid "AWS_ACCOUNT_ID" value: "". Must be a 12-digit number.'
    
    # use for debugging:
    # echo -e "\n\n\n" >&3
    # cat "$createAppEnvLogFile" >&3
}

@test "detects REMOTE_ENV_VAR_LOC is missing" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$createAppEnvInputFileName"
    {
        "AWS_ACCOUNT_ID": "000000000000"
    }
EOF

    # use for debugging:
    # echo "createAppEnvInputFileName is $createAppEnvInputFileName" >&3
    # cat $createAppEnvInputFileName >&3
    # echo -e "\n\n\n" >&3

    run get_input_validation_full_error_message "$createAppEnvInputFileName"

    # use for debugging:
    # echo -e "\n\n\n" >&3
    # cat "$createAppEnvLogFile" >&3
    
    assert_line --index 0 'ERROR: invalid "REMOTE_ENV_VAR_LOC" value: "". Must be "ssm" or "gitlab" or "na".'

    # use for debugging:
    # echo -e "\n\n\n" >&3
    # cat "$createAppEnvLogFile" >&3
}

@test "detects ENV_NAME is missing" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$createAppEnvInputFileName"
    {
        "AWS_ACCOUNT_ID": "000000000000",
        "REMOTE_ENV_VAR_LOC": "na"
    }
EOF

    # use for debugging:
    # echo "createAppEnvInputFileName is $createAppEnvInputFileName" >&3
    # cat $createAppEnvInputFileName >&3
    # echo -e "\n\n\n" >&3

    run get_input_validation_full_error_message "$createAppEnvInputFileName"

    # use for debugging:
    # echo -e "\n\n\n" >&3
    # cat "$createAppEnvLogFile" >&3
    
    assert_line --index 0 'ERROR: "ENV_NAME" value is invalid: "".'
    assert_line --index 1 "Must not include whitespace and length (0) must be between 1 and 6."

    # use for debugging:
    # echo -e "\n\n\n" >&3
    # cat "$createAppEnvLogFile" >&3
}

@test "detects AWS_DEFAULT_REGION is missing" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$createAppEnvInputFileName"
    {
        "AWS_ACCOUNT_ID": "000000000000",
        "REMOTE_ENV_VAR_LOC": "na",
        "ENV_NAME": "new"
    }
EOF

    # use for debugging:
    # echo "createAppEnvInputFileName is $createAppEnvInputFileName" >&3
    # cat $createAppEnvInputFileName >&3
    # echo -e "\n\n\n" >&3

    run get_input_validation_full_error_message "$createAppEnvInputFileName"

    # use for debugging:
    # echo -e "\n\n\n" >&3
    # cat "$createAppEnvLogFile" >&3
    
    assert_line --index 0 "ERROR: \"AWS_DEFAULT_REGION\" value is invalid: \"\"."
    assert_line --index 1 "Must be one of the following values: $awsJoinedRegionCodes"

    # use for debugging:
    # echo -e "\n\n\n" >&3
    # cat "$createAppEnvLogFile" >&3
}

@test "detects AWS_DEFAULT_REGION is invalid" {
    region="fake-region"
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$createAppEnvInputFileName"
    {
        "AWS_ACCOUNT_ID": "000000000000",
        "REMOTE_ENV_VAR_LOC": "na",
        "ENV_NAME": "new",
        "AWS_DEFAULT_REGION": "$region"
    }
EOF

    # use for debugging:
    # echo "createAppEnvInputFileName is $createAppEnvInputFileName" >&3
    # cat $createAppEnvInputFileName >&3
    # echo -e "\n\n\n" >&3

    run get_input_validation_full_error_message "$createAppEnvInputFileName"

    # use for debugging:
    # echo -e "\n\n\n" >&3
    # cat "$createAppEnvLogFile" >&3
    
    assert_line --index 0 "ERROR: \"AWS_DEFAULT_REGION\" value is invalid: \"$region\"."
    assert_line --index 1 "Must be one of the following values: $awsJoinedRegionCodes"

    # use for debugging:
    # echo -e "\n\n\n" >&3
    # cat "$createAppEnvLogFile" >&3
}

@test "detects AWS_SECONDARY_REGION is missing" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$createAppEnvInputFileName"
    {
        "AWS_ACCOUNT_ID": "000000000000",
        "REMOTE_ENV_VAR_LOC": "na",
        "ENV_NAME": "new",
        "AWS_DEFAULT_REGION": "us-east-1"

    }
EOF

    # use for debugging:
    # echo "createAppEnvInputFileName is $createAppEnvInputFileName" >&3
    # cat $createAppEnvInputFileName >&3
    # echo -e "\n\n\n" >&3

    run get_input_validation_full_error_message "$createAppEnvInputFileName"

    # use for debugging:
    # echo -e "\n\n\n" >&3
    # cat "$createAppEnvLogFile" >&3
    
    assert_line --index 0 "ERROR: \"AWS_SECONDARY_REGION\" value is invalid: \"\"."
    assert_line --index 1 "Must be one of the following values: $awsJoinedRegionCodes"

    # use for debugging:
    # echo -e "\n\n\n" >&3
    # cat "$createAppEnvLogFile" >&3
}

@test "detects MY_CUSTOM_VAR is missing" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$createAppEnvInputFileName"
    {
        "AWS_ACCOUNT_ID": "000000000000",
        "REMOTE_ENV_VAR_LOC": "na",
        "ENV_NAME": "new",
        "AWS_DEFAULT_REGION": "us-east-1",
        "AWS_SECONDARY_REGION": "us-west-2"
    }
EOF

    # use for debugging:
    # echo "createAppEnvInputFileName is $createAppEnvInputFileName" >&3
    # cat $createAppEnvInputFileName >&3
    # echo -e "\n\n\n" >&3

    run get_input_validation_full_error_message "$createAppEnvInputFileName"

    # use for debugging:
    # echo -e "\n\n\n" >&3
    # cat "$createAppEnvLogFile" >&3
    
    assert_line --index 0 "ERROR: \"MY_CUSTOM_VAR\" value is invalid: \"\"."
    assert_line --index 1 --partial "Documentation: Does something custom"

    # use for debugging:
    # echo -e "\n\n\n" >&3
    # cat "$createAppEnvLogFile" >&3
}

@test "valid input" {
    envName="new"

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$createAppEnvInputFileName"
    {
        "AWS_ACCOUNT_ID": "000000000000",
        "REMOTE_ENV_VAR_LOC": "na",
        "ENV_NAME": "$envName",
        "AWS_DEFAULT_REGION": "us-east-1",
        "AWS_SECONDARY_REGION": "us-west-2",
        "MY_CUSTOM_VAR": "someValue"
    }
EOF

    # use for debugging:
    # echo "createAppEnvInputFileName is $createAppEnvInputFileName" >&3
    # cat $createAppEnvInputFileName >&3
    # echo -e "\n\n\n" >&3

    export COIN_CREATE_APP_ENV_DRY_RUN="y"
    run create_app_env "$createAppEnvInputFileName"

    # use for debugging:
    # echo -e "\n\n\n" >&3
    # cat "$createAppEnvLogFile" >&3

    assert_success
    assert_output --partial "COIN_CREATE_APP_ENV_DRY_RUN is ON. Exiting without creating app environment."
    assert_not_exists "${generatedAppEnvDir}/.environment-${envName}.json"

    # use for debugging:
    # echo -e "\n\n\n" >&3
    # cat "$createAppEnvLogFile" >&3
}
