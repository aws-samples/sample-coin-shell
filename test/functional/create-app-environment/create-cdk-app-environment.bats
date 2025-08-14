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
    load '../../test-helper/common-setup'
    _common_setup

    appParentDir="/tmp/"
    gitProjectName="bats-cdk-local-deploy-nothing"
    generatedAppDir="${appParentDir}${gitProjectName}"
    generatedAppEnvDir="${generatedAppDir}/environment"
    generateEnvScriptPath="${generatedAppDir}/environment/create-app-environment.sh"
    createAppEnvInputFileName="/tmp/create-cdk-app-env-headless-input.json"
    createAppEnvLogFile="$generatedAppDir/environment/.log.txt"
    choiceCacheFile="$generatedAppEnvDir/.choice-cache.json"
    appName="cbat"
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

@test "create cdk app environment" {
    envName="new"
    accountId="000000000000"
    remoteEnvVarLoc="na"
    defaultRegion="us-west-2"
    createdBy="Watson, Anthony"

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$createAppEnvInputFileName"
    {
        "AWS_ACCOUNT_ID": "$accountId",
        "REMOTE_ENV_VAR_LOC": "$remoteEnvVarLoc",
        "ENV_NAME": "$envName",
        "AWS_DEFAULT_REGION": "$defaultRegion",
        "CREATED_BY": "$createdBy"
    }
EOF

    run create_cdk_app_environment "$createAppEnvInputFileName"

    # use for debugging:
    # echo -e "\n\n\n" >&3
    # cat "$createAppEnvLogFile" >&3
    
    assert_output --partial "Congratulations! Your \"${envName}\" application environment has been created."
    assert_exists "$generatedAppEnvDir/.environment-${envName}.json"

    # cat "$generatedAppEnvDir/.environment-${envName}.json" >&3

    # Verify that create app environment extensions are called
    run cat "$createAppEnvLogFile"
    # echo -e $output >&3
    assert_output --partial "executing take_custom_create_app_environment_actions"
    assert_output --partial "executing take_custom_create_app_environment_deployment_actions"
    assert_output --partial "executing ask_custom_create_app_environment_questions_headless_input_validation"

    # Verify that environment JSON has the right values
    envJsonAccountId="$(jq -r '.AWS_ACCOUNT_ID' "$generatedAppEnvDir/.environment-${envName}.json")"
    assert [ "$accountId" == "$envJsonAccountId" ]

    envJsonRegion="$(jq -r '.AWS_DEFAULT_REGION' "$generatedAppEnvDir/.environment-${envName}.json")"
    assert [ "$defaultRegion" == "$envJsonRegion" ]

    envJsonEnvName="$(jq -r '.ENV_NAME' "$generatedAppEnvDir/.environment-${envName}.json")"
    assert [ "$envName" == "$envJsonEnvName" ]

    envJsonRemoteVarLoc="$(jq -r '.REMOTE_ENV_VAR_LOC' "$generatedAppEnvDir/.environment-${envName}.json")"
    assert [ "$remoteEnvVarLoc" == "$envJsonRemoteVarLoc" ]

    envJsonCreatedBy="$(jq -r '.CREATED_BY' "$generatedAppEnvDir/.environment-${envName}.json")"
    assert [ "$createdBy" == "$envJsonCreatedBy" ]

    # Verify that the new environment was set to the current environment
    cd "$generatedAppDir" 
    currentEnvName="$(make gce)" 
    assert [ "$currentEnvName" == "$envName" ]

    # Verify that the user's entries were captured so that they can be loaded as defaults
    # if the create app environment wizard is run again
    assert_exists "$choiceCacheFile"
    # cat "$choiceCacheFile" >&3

    defaultUseEnvWithCicd="$(jq -r '.defaultUseEnvWithCicd' "$choiceCacheFile")"
    assert [ "$defaultUseEnvWithCicd" == "n" ]
    defaultAppName="$(jq -r '.defaultAppName' "$choiceCacheFile")"
    assert [ "$defaultAppName" == "$appName" ]
    defaultCreatedBy="$(jq -r '.defaultCreatedBy' "$choiceCacheFile")"
    assert [ "$defaultCreatedBy" == "$createdBy" ]
    defaultAwsAccountNum="$(jq -r '.defaultAwsAccountNum' "$choiceCacheFile")"
    assert [ "$defaultAwsAccountNum" == "$accountId" ]
    defaultCacheRegion="$(jq -r '.defaultRegion' "$choiceCacheFile")"
    assert [ "$defaultCacheRegion" == "$defaultRegion" ]
    defaultDeployRole="$(jq -r '.defaultDeployRole' "$choiceCacheFile")"
    assert [ "$defaultDeployRole" == "n" ]
    defaultDeployRemoteEnvVars="$(jq -r '.defaultDeployRemoteEnvVars' "$choiceCacheFile")"
    assert [ "$defaultDeployRemoteEnvVars" == "n" ]
    defaultRemoteEnvVarLoc="$(jq -r '.defaultRemoteEnvVarLoc' "$choiceCacheFile")"
    assert [ "$defaultRemoteEnvVarLoc" == "na" ]
    defaultDeployTfBackend="$(jq -r '.defaultDeployTfBackend' "$choiceCacheFile")"
    assert [ "$defaultDeployTfBackend" == "n" ]
    defaultDeployCdk2Backend="$(jq -r '.defaultDeployCdk2Backend' "$choiceCacheFile")"
    assert [ "$defaultDeployCdk2Backend" == "y" ]

    cd -
}