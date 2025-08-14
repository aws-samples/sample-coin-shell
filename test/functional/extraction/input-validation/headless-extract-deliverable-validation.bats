#!/usr/bin/env bats

setup_file () {
    load '../../../test-helper/common-setup'
    _common_setup

    appParentDir="/tmp/"
    gitProjectName="bats-tf-local-deploy-nothing"
    generatedAppDir="${appParentDir}${gitProjectName}"
    inputFileName="/tmp/create-tf-app-headless-input.json"
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
        "iac": "terraform",
        "REMOTE_ENV_VAR_LOC": "na",
        "APP_NAME": "tbat",
        "AWS_DEFAULT_REGION": "us-east-1",
        "CREATED_BY": "Anthony Watson",
        "ENV_NAME": "dev",
        "firstIacModuleName": "$firstIacModuleName",
        "gitProjectName": "$gitProjectName",
        "TF_S3_BACKEND_NAME": "$appName-$envName-tf-back-end"
    }
EOF

    # use for debugging:
    # cat $inputFileName >&3

    run create_tf_app "$inputFileName"
    
    assert_output --partial "Congratulations! Your application has been created at ${generatedAppDir}"
    assert_output --partial "A Terraform module has been created for you under your project's /iac/roots/${firstIacModuleName} directory"
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
    gitProjectName="bats-tf-local-deploy-nothing"
    generatedAppDir="${appParentDir}${gitProjectName}"
    generatedAppEnvDir="${generatedAppDir}/environment"
    generatedAppEnvLogFile="${generatedAppEnvDir}/.log.txt"
    iacDir="${generatedAppDir}/iac"
    iacRootsDir="${iacDir}/roots"
    appLogFile="$generatedAppDir/environment/.log.txt"
    exdInputFileName="/tmp/exd-tf-headless-input.json" # exd = "extract deliverable"
    exdScriptPath="${generatedAppEnvDir}/extract-deliverable.sh"
    appName="tbat"
}

teardown () {
    rm -f "$exdInputFileName"
}

create_tf_app () {
    create-app.sh "$1" 2>&1
}

# Returns the input validation error message only
# Example:
#   ERROR: "APP_NAME" value is invalid: "aReallyLongInvalidValue".
get_input_validation_error_message() {
    # The sed pattern below gets rid of ANSI color codes in the output. These hidden characters will cause
    # assertions on the output to fail
    "$exdScriptPath" "$1" 2>&1 | grep "ERROR:" | sed -e 's/\x1b\[[0-9;]*m//g'
}

# Returns the input validation error message on one line and the reason the validation failed on the next line
# Example:
#   ERROR: "APP_NAME" value is invalid: "aReallyLongInvalidValue".
#   Must not include whitespace and length (23) must be between 1 and 10.
get_input_validation_full_error_message() {
    # The sed pattern below gets rid of ANSI color codes in the output. These hidden characters will cause
    # assertions on the output to fail
    "$exdScriptPath" "$1" 2>&1 | grep -A 1 "ERROR:" | sed -e 's/\x1b\[[0-9;]*m//g'
}

# bats file_tags=type:functional, suite:extract-deliverable, iac:terraform, category:input-validation

@test "headless input JSON must be structurally valie" {

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$exdInputFileName"
    this is not JSON
EOF

    run get_input_validation_error_message "$exdInputFileName"
    assert_output 'ERROR: Headless input contains structurally invalid JSON' 
}

@test "freshPull is required" {

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$exdInputFileName"
    {
        "fakeProperty": "y"
    }
EOF

    run get_input_validation_error_message "$exdInputFileName"
    assert_output 'ERROR: "freshPull" must be "y" or "n" but was ""' 
}

@test "includeEnv is required" {

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$exdInputFileName"
    {
        "freshPull": "y"
    }
EOF

    run get_input_validation_error_message "$exdInputFileName"
    assert_output 'ERROR: "includeEnv" must be "y" or "n" but was ""' 
}

@test "deleteDeliverableDir is required" {

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$exdInputFileName"
    {
        "freshPull": "y",
        "includeEnv": "n"
    }
EOF

    run get_input_validation_error_message "$exdInputFileName"
    assert_output 'ERROR: "deleteDeliverableDir" must be "y" or "n" but was ""' 
}

@test "EXTRACT_BRANCH_NAME is required" {

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$exdInputFileName"
    {
        "freshPull": "y",
        "includeEnv": "n",
        "deleteDeliverableDir": "y"
    }
EOF

    run get_input_validation_full_error_message "$exdInputFileName"
    assert_line --index 0 'ERROR: "EXTRACT_BRANCH_NAME" value is invalid: "".'
    assert_line --index 1 'Must not include whitespace and length (0) must be between 1 and 80.'
}

@test "freshPullDir is required" {

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$exdInputFileName"
    {
        "freshPull": "y",
        "includeEnv": "n",
        "deleteDeliverableDir": "y",
        "EXTRACT_BRANCH_NAME": "main"
    }
EOF

    run get_input_validation_full_error_message "$exdInputFileName"
    assert_line --index 0 'ERROR: "freshPullDir" value is invalid: "".'
    assert_line --index 1 'Must not include whitespace and length (0) must be between 1 and 150.'
}

@test "DELIVERABLE_NAME is required" {

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$exdInputFileName"
    {
        "freshPull": "y",
        "includeEnv": "n",
        "deleteDeliverableDir": "y",
        "EXTRACT_BRANCH_NAME": "main",
        "freshPullDir": "${appParentDir}pure-git-clones"
    }
EOF

    run get_input_validation_full_error_message "$exdInputFileName"
    assert_line --index 0 'ERROR: "DELIVERABLE_NAME" value is invalid: "".'
    assert_line --index 1 'Must not include whitespace and length (0) must be between 1 and 50.'
}

@test "deliverableParentDir is required" {

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$exdInputFileName"
    {
        "freshPull": "y",
        "includeEnv": "n",
        "deleteDeliverableDir": "y",
        "EXTRACT_BRANCH_NAME": "main",
        "freshPullDir": "${appParentDir}pure-git-clones",
        "DELIVERABLE_NAME": "bats-tf-deliverable"
    }
EOF

    run get_input_validation_full_error_message "$exdInputFileName"
    assert_line --index 0 'ERROR: "deliverableParentDir" value is invalid: "".'
    assert_line --index 1 'Must not include whitespace and length (0) must be between 1 and 150.'
}

@test "includeMakefile is required" {

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$exdInputFileName"
    {
        "freshPull": "y",
        "includeEnv": "n",
        "deleteDeliverableDir": "y",
        "EXTRACT_BRANCH_NAME": "main",
        "freshPullDir": "${appParentDir}pure-git-clones",
        "DELIVERABLE_NAME": "bats-tf-deliverable",
        "deliverableParentDir": "${appParentDir}customer-deliverables/$appName/"
    }
EOF

    run get_input_validation_error_message "$exdInputFileName"
    assert_output 'ERROR: "includeMakefile" must be "y" or "n" but was ""' 

}

@test "generateResolveScript is required" {

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$exdInputFileName"
    {
        "freshPull": "y",
        "includeEnv": "n",
        "deleteDeliverableDir": "y",
        "EXTRACT_BRANCH_NAME": "main",
        "freshPullDir": "${appParentDir}pure-git-clones",
        "DELIVERABLE_NAME": "bats-tf-deliverable",
        "deliverableParentDir": "${appParentDir}customer-deliverables/$appName/",
        "includeMakefile": "y"
    }
EOF

    run get_input_validation_error_message "$exdInputFileName"
    assert_output 'ERROR: "generateResolveScript" must be "y" or "n" but was ""' 

}

@test "includeBuildScript is required" {

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$exdInputFileName"
    {
        "freshPull": "y",
        "includeEnv": "n",
        "deleteDeliverableDir": "y",
        "EXTRACT_BRANCH_NAME": "main",
        "freshPullDir": "${appParentDir}pure-git-clones",
        "DELIVERABLE_NAME": "bats-tf-deliverable",
        "deliverableParentDir": "${appParentDir}customer-deliverables/$appName/",
        "includeMakefile": "y",
        "generateResolveScript": "y"
    }
EOF

    run get_input_validation_error_message "$exdInputFileName"
    assert_output 'ERROR: "includeBuildScript" must be "y" or "n" but was ""' 

}