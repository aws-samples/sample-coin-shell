#!/usr/bin/env bats

setup_file () {
    :
    # echo '# Hello there from setup_file' >&3
}

setup () {
    load '../../test-helper/common-setup'
    _common_setup

    appParentDir="/tmp/"
    gitProjectName="bats-tf"
    generatedAppDir="${appParentDir}${gitProjectName}"
    generatedAppEnvDir="${generatedAppDir}/environment"
    generatedAppEnvLogFile="${generatedAppEnvDir}/.log.txt"
    iacDir="${generatedAppDir}/iac"
    iacRootsDir="${iacDir}/roots"
    inputFileName="${appParentDir}create-tf-app-headless-input.json"
    firstIacModuleName="example"
    envName="dev"
    appName="battf"
    accountId="000000000000"
    defaultRegion="us-east-1"
    remoteLoc="na"
    createdBy="Anthony Watson"
    tfBackend="$appName-$envName-tf-back-end"

    mkdir -p "$generatedAppDir/test-templates"

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
        "AWS_ACCOUNT_ID": "$accountId",
        "iac": "terraform",
        "REMOTE_ENV_VAR_LOC": "$remoteLoc",
        "APP_NAME": "$appName",
        "AWS_DEFAULT_REGION": "$defaultRegion",
        "CREATED_BY": "$createdBy",
        "ENV_NAME": "$envName",
        "firstIacModuleName": "$firstIacModuleName",
        "gitProjectName": "$gitProjectName",
        "TF_S3_BACKEND_NAME": "$tfBackend"
    }
EOF
}

teardown () {
    rm -f "$inputFileName"
    rm -rf "$generatedAppDir"
}

create_terraform_app () {
    create-app.sh "$1" 2>&1
}

execute_prt () {
    # The sed pattern below gets rid of ANSI color codes in the output. These hidden characters will cause
    # assertions on the output to fail
    make prt f="$1" 2>&1 | grep -A 2 "ERROR:" | sed -e 's/\x1b\[[0-9;]*m//g'
}

execute_pce () {
    # The sed pattern below gets rid of ANSI color codes in the output. These hidden characters will cause
    # assertions on the output to fail
    make pce 2>&1 | sed -e 's/\x1b\[[0-9;]*m//g'
}

# bats file_tags=type:functional, suite:placeholder-resolution, iac:terraform

@test "standard placeholder resolution" {
    
    run create_terraform_app "$inputFileName"
    
    assert_output --partial "Congratulations! Your application has been created at ${generatedAppDir}"
    assert_exists "$generatedAppDir"

    cd "$generatedAppDir"

    # Run the print-current-environment utility to see the keys and values for the environment. Verify the values are correct.
    run execute_pce
    # echo -e "\n$output\n" >&3
    assert_output --partial "\"APP_NAME\": \"$appName\""
    assert_output --partial "\"AWS_ACCOUNT_ID\": \"$accountId\""
    assert_output --partial "\"AWS_DEFAULT_REGION\": \"$defaultRegion\""
    assert_output --partial "\"CREATED_BY\": \"$createdBy\""
    assert_output --partial "\"ENV_NAME\": \"$envName\""
    assert_output --partial "\"REMOTE_ENV_VAR_LOC\": \"$remoteLoc\""
    assert_output --partial "\"TF_S3_BACKEND_NAME\": \"$tfBackend\""

    # Test that configuration values can be overridden with the COIN_OVERRIDE feature
    export COIN_OVERRIDE_AWS_DEFAULT_REGION="ap-south-1"
    run execute_pce
    assert_output --partial "\"AWS_DEFAULT_REGION\": \"ap-south-1\""
    # Now, clear the override so that it won't affect other tests
    export COIN_OVERRIDE_AWS_DEFAULT_REGION=""

    # Test that standard placeholder resolution including "CUR_DIR_NAME" works for backend.tf
    run make prt f="$iacRootsDir/$firstIacModuleName/backend.tf"
    # echo "$output" >&3
    assert_output --partial "bucket         = \"$appName-$envName-tf-back-end-$accountId-$defaultRegion\""
    assert_output --partial "key            = \"$envName/$firstIacModuleName/terraform.tfstate\""
    
    # Test that users are notified if a placeholder is used that has no value
    echo "Hello ###MY_NEW_PLACEHOLDER###" > "$generatedAppDir/test-templates/unset-placeholder-test.txt"
    run execute_prt "$generatedAppDir/test-templates/unset-placeholder-test.txt"
    # echo "$output" >&3
    assert_line --index 0 "ERROR: $generatedAppDir/test-templates/unset-placeholder-test.txt contains unresolved placeholder: ###MY_NEW_PLACEHOLDER###"
    assert_line --index 1 "This could be because the placeholder expression has a typo or"
    assert_line --index 2 "because the placeholder is not defined in app-env-var-names.txt"

    # Add a new required property to app-env-var-names.txt and ensure that we are informed that its value must be set
    echo -e "\n# New required variable\nNEW_REQUIRED_VAR" >> "$generatedAppEnvDir/app-env-var-names.txt"
    run execute_prt "$iacRootsDir/$firstIacModuleName/backend.tf"
    # hiddenCharsOutput="$(printf %q "$output")"
    # echo "$hiddenCharsOutput" >&3
    assert_line --index 0 'ERROR: "NEW_REQUIRED_VAR" environment variable is not set in the '
    assert_line --index 1 "  \"$envName\" environment. Set it to a value or \"blank\" if there"
    assert_line --index 2 '  is no value or remove it from "app-env-var-names.txt" if it is not needed.'

    cd -
}

@test "sensitive placeholder resolution" {
    
    run create_terraform_app "$inputFileName"
    
    assert_output --partial "Congratulations! Your application has been created at ${generatedAppDir}"
    assert_exists "$generatedAppDir"

    cd "$generatedAppDir" 

    # Add a new required property to app-env-var-names.txt. We will use the sensitive value feature to set the value
    echo -e "\n# Test for sensitive value\nNEW_SENSITIVE_VAR" >> "$generatedAppEnvDir/app-env-var-names.txt"

    # Add the new variable to the dev environment JSON file and set its value to "sensitive"
    jq '. += {"NEW_SENSITIVE_VAR": "sensitive"}' "$generatedAppEnvDir/.environment-${envName}.json" > "$generatedAppEnvDir/tmp.json" && mv "$generatedAppEnvDir/tmp.json" "$generatedAppEnvDir/.environment-${envName}.json"

    # Create a new file to store sensitive values
    echo '{"NEW_SENSITIVE_VAR": "real sensitive value"}' > "$generatedAppEnvDir/.environment-${envName}-sensitive.json"

    # Run the print-current-environment utility to see the keys and values for the environment
    run execute_pce

    assert_output --partial '"NEW_SENSITIVE_VAR": "real sensitive value"'

    cd -
}

@test "constant placeholder resolution" {

    # The constant value feature allows users to configure values that are constant across all environments.
    # The constant values are set once. They don't need to be set per environment.
    
    run create_terraform_app "$inputFileName"
    
    assert_output --partial "Congratulations! Your application has been created at ${generatedAppDir}"
    assert_exists "$generatedAppDir"

    cd "$generatedAppDir" 

    # Add a new required property to app-env-var-names.txt. We will use the constant value feature to set the value
    echo -e "\n# Test for constant value\nNEW_CONSTANT_VAR" >> "$generatedAppEnvDir/app-env-var-names.txt"

    # Add the new variable to the environment constants JSON file
    jq '. += {"NEW_CONSTANT_VAR": "my constant value"}' "$generatedAppEnvDir/environment-constants.json" > "$generatedAppEnvDir/tmp.json" && mv "$generatedAppEnvDir/tmp.json" "$generatedAppEnvDir/environment-constants.json"

    # cat "$generatedAppEnvDir/environment-constants.json" >&3

    # Run the print-current-environment utility to see the keys and values for the environment
    run execute_pce

    assert_output --partial '"NEW_CONSTANT_VAR": "my constant value"'

    cd -
}


