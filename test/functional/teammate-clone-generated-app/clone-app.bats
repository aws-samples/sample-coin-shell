#!/usr/bin/env bats

setup_file () {
    load '../../test-helper/common-setup'
    _common_setup

    appParentDir="/tmp/"
    gitProjectName="bats-cdk-local-deploy-nothing"
    generatedAppDir="${appParentDir}${gitProjectName}"
    inputFileName="/tmp/create-cdk-app-headless-input.json"
    firstIacModuleName="example"
    generateEnvScriptPath="${generatedAppDir}/environment/create-app-environment.sh"
    envName="dev"

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
        "ENV_NAME": "$envName",
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
    load '../../test-helper/common-setup'
    _common_setup

    appParentDir="/tmp/"
    gitProjectName="bats-cdk-local-deploy-nothing"
    generatedAppDir="${appParentDir}${gitProjectName}"
    generatedAppEnvDir="${generatedAppDir}/environment"
    generateEnvScriptPath="${generatedAppDir}/environment/create-app-environment.sh"
    createAppEnvInputFileName="/tmp/create-cdk-app-env-headless-input.json"
    createAppEnvLogFile="$generatedAppDir/environment/.log.txt"
    firstIacModuleName="example"
    envName="dev"
}

teardown () {
    :
}

create_cdk_app () {
    # The sed pattern below gets rid of ANSI color codes in the output. These hidden characters will cause
    # assertions on the output to fail
    create-app.sh "$1" 2>&1
}

create_cdk_app_environment () {
    # The sed pattern below gets rid of ANSI color codes in the output. These hidden characters will cause
    # assertions on the output to fail
    "$generateEnvScriptPath" "$1" 2>&1
}

# bats file_tags=type:functional, suite:create-app-environment, generate:app-env, category:input-validation

@test "inform user if current environment is not set" {
    
    cd "$generatedAppDir" 

    # Simulate that a teammate has cloned a generated project and has not set up an environment yet
    mv "$generatedAppEnvDir/.current-environment" "$generatedAppEnvDir/temp.current-environment"

    run make pce
    # echo "$output" >&3
    assert_output --partial "WARNING: The current environment setting is not configured"
    assert_output --partial "This is expected if you just downloaded your application's source code."
    assert_output --partial "The current environment setting can be configured using one of these:"

    assert_failure

    # Put back the orriginal current environment file to ensure we don't impact subsequent tests
    mv "$generatedAppEnvDir/temp.current-environment" "$generatedAppEnvDir/.current-environment" 

    cd -
}

@test "inform user if current environment json file does not exist" {
    
    cd "$generatedAppDir"

    origCurrentEnv="$(make gce)"

    badEnvName="fake"

    # Intentionally set the current environment to a non-existent value
    echo $badEnvName > "$generatedAppEnvDir/.current-environment"

    run make pce
    # echo "$output" >&3
    assert_output --partial "ERROR: environment settings file \"${appParentDir}${gitProjectName}/environment/.environment-${badEnvName}.json\" could not be found."
    assert_output --partial "Please ensure that the current environment is set correctly in environment/.current-environment"

    assert_failure

    # Restore valid state so that other tests are not corrupted
    echo $origCurrentEnv > "$generatedAppEnvDir/.current-environment"

    cd -
}

@test "inform user if AWS credentials are incorrect or not set" {
    
    cd "$generatedAppDir"

    # Set AWS Account ID for the environment to one that looks real
    jq '.AWS_ACCOUNT_ID = "123456789012"' "$generatedAppEnvDir/.environment-${envName}.json" > "$generatedAppEnvDir/tmp.json" && mv "$generatedAppEnvDir/tmp.json" "$generatedAppEnvDir/.environment-${envName}.json"

    run make "diff-$firstIacModuleName"
    assert_output --partial "The AWS CLI must be logged in as a principal in the"
    assert_output --partial "\"123456789012\" account before proceeding."
    assert_output --partial "Currently logged into account "

    assert_failure

    cd -
}