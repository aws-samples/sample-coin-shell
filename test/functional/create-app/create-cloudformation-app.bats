#!/usr/bin/env bats

setup_file () {
    :
    # echo '# Hello there from setup_file' >&3
}

setup () {
    load '../../test-helper/common-setup'
    _common_setup

    appParentDir="/tmp/"
    gitProjectName="bats-cf"
    generatedAppDir="${appParentDir}${gitProjectName}"
    generatedAppEnvDir="${generatedAppDir}/environment"
    generatedAppEnvLogFile="${generatedAppEnvDir}/.log.txt"
    coinLogFile="$COIN_ROOT_DIR/.log.txt"
    iacDir="${generatedAppDir}/iac"
    iacRootsDir="${iacDir}/roots"
    inputFileName="/tmp/create-cf-app-headless-input.json"
    firstIacModuleName="example"
    envName="dev"
    appName="batcf"
    accountId="000000000000"
    defaultRegion="us-east-1"
    remoteLoc="na"
    createdBy="Anthony Watson"
}

teardown () {
    rm -f "$inputFileName"
    rm -rf "$generatedAppDir"
}

create_cloudformation_app () {
    # The sed pattern below gets rid of ANSI color codes in the output. These hidden characters will cause
    # assertions on the output to fail
    create-app.sh "$1" 2>&1
}

# bats file_tags=type:functional, suite:create-app, generate:app, category:input-validation, iac:cloudformation

@test "create CloudFormation app locally and deploy nothing" {
    
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
        "iac": "cf",
        "REMOTE_ENV_VAR_LOC": "$remoteLoc",
        "APP_NAME": "$appName",
        "AWS_DEFAULT_REGION": "$defaultRegion",
        "CREATED_BY": "$createdBy",
        "ENV_NAME": "$envName",
        "firstIacModuleName": "$firstIacModuleName",
        "gitProjectName": "$gitProjectName",
        "TF_S3_BACKEND_NAME": "blank"
    }
EOF

    # use for debugging:
    # cat $inputFileName >&3

    run create_cloudformation_app "$inputFileName"
    
    assert_output --partial "Congratulations! Your application has been created at ${generatedAppDir}"
    assert_output --partial "A CloudFormation module has been created for you under your project's /iac/roots/${firstIacModuleName} directory"
    assert_exists "$generatedAppDir"
    assert_exists "$generatedAppEnvDir"

    # Verify that create app extensions are called
    run cat "$coinLogFile"
    # echo -e $output >&3
    assert_output --partial "executing ask_custom_create_app_questions_headless_input_validation"
    assert_output --partial "executing take_custom_create_app_actions"
    assert_output --partial "executing take_custom_create_app_deployment_actions"

    cd "$generatedAppDir" 

    currentEnvName="$(make gce)" 
    assert [ "$currentEnvName" == "$envName" ]

    # Verify that all of the sh scripts got copied over to the environment directory
    assert_exists "$generatedAppEnvDir/aws-regions.sh"
    assert_exists "$generatedAppEnvDir/bash-5-utils.sh"
    assert_exists "$generatedAppEnvDir/constants.sh"
    assert_exists "$generatedAppEnvDir/create-app-env-questions.sh"
    assert_exists "$generatedAppEnvDir/create-app-environment.sh"
    assert_exists "$generatedAppEnvDir/create-iac-module.sh"
    assert_exists "$generatedAppEnvDir/delete-app-environment.sh"
    assert_exists "$generatedAppEnvDir/dynamic-lookups.sh"
    assert_exists "$generatedAppEnvDir/extract-deliverable.sh"
    assert_exists "$generatedAppEnvDir/generate-deployment-instructions.sh"
    assert_exists "$generatedAppEnvDir/gitlab.sh"
    assert_exists "$generatedAppEnvDir/utility-functions.sh"

    # Verify that all non sh files got copied over to the environment directory
    assert_exists "$generatedAppEnvDir/.current-environment"
    assert_exists "$generatedAppEnvDir/.choice-cache.json"
    assert_exists "$generatedAppEnvDir/.environment-${envName}.json"
    assert_exists "$generatedAppEnvDir/.log.txt"
    assert_exists "$generatedAppEnvDir/app-env-var-names.txt"
    # assert_exists "$generatedAppEnvDir/DEV_GUIDE_CLOUDFORMATION.md"
    assert_exists "$generatedAppEnvDir/environment-constants.json"
    assert_exists "$generatedAppEnvDir/Makefile"
    assert_exists "$generatedAppEnvDir/coin-app-version"
    assert_exists "$generatedAppEnvDir/README.md"
    assert_exists "$generatedAppEnvDir/images"

    # app constants should have APP_NAME
    constantsAppName="$(jq -r '.APP_NAME' "$generatedAppEnvDir/environment-constants.json")"
    assert [ "$appName" == "$constantsAppName" ]
    
    # use for debugging:
    # cat "$generatedAppEnvDir/.environment-${envName}.json" >&3

    # Verify that environment JSON has the right values
    envJsonAccountId="$(jq -r '.AWS_ACCOUNT_ID' "$generatedAppEnvDir/.environment-${envName}.json")"
    assert [ "$accountId" == "$envJsonAccountId" ]
    envJsonDefaultRegion="$(jq -r '.AWS_DEFAULT_REGION' "$generatedAppEnvDir/.environment-${envName}.json")"
    assert [ "$defaultRegion" == "$envJsonDefaultRegion" ]
    envJsonEnvName="$(jq -r '.ENV_NAME' "$generatedAppEnvDir/.environment-${envName}.json")"
    assert [ "$envName" == "$envJsonEnvName" ]
    envJsonRemoteLoc="$(jq -r '.REMOTE_ENV_VAR_LOC' "$generatedAppEnvDir/.environment-${envName}.json")"
    assert [ "$remoteLoc" == "$envJsonRemoteLoc" ]
    envJsonCreatedBy="$(jq -r '.CREATED_BY' "$generatedAppEnvDir/.environment-${envName}.json")"
    assert [ "$createdBy" == "$envJsonCreatedBy" ]

    # Verify that environment JSON does NOT have values it shouldn't have in this context
    envJsonTfS3BackendName="$(jq 'has("TF_S3_BACKEND_NAME")' "$generatedAppEnvDir/.environment-${envName}.json")"
    assert [ "$envJsonTfS3BackendName" == "false" ]
    envJsonSecondaryRegion="$(jq 'has("AWS_SECONDARY_REGION")' "$generatedAppEnvDir/.environment-${envName}.json")"
    assert [ "$envJsonSecondaryRegion" == "false" ]

    # Verify that choice cache JSON has the right values
    cacheJsonAppName="$(jq -r '.defaultAppName' "$generatedAppEnvDir/.choice-cache.json")"
    assert [ "$cacheJsonAppName" == "$appName" ]
    cacheJsonAccountId="$(jq -r '.defaultAwsAccountNum' "$generatedAppEnvDir/.choice-cache.json")"
    assert [ "$cacheJsonAccountId" == "$accountId" ]
    cacheJsonRegion="$(jq -r '.defaultRegion' "$generatedAppEnvDir/.choice-cache.json")"
    assert [ "$cacheJsonRegion" == "$defaultRegion" ]
    cacheJsonDeployCicdResources="$(jq -r '.defaultDeployRole' "$generatedAppEnvDir/.choice-cache.json")"
    assert [ "$cacheJsonDeployCicdResources" == "n" ]
    cacheJsonRemoteEnvVarLoc="$(jq -r '.defaultRemoteEnvVarLoc' "$generatedAppEnvDir/.choice-cache.json")"
    assert [ "$cacheJsonRemoteEnvVarLoc" == "$remoteLoc" ]
    cacheJsonDeployTfBackend="$(jq -r '.defaultDeployTfBackend' "$generatedAppEnvDir/.choice-cache.json")"
    assert [ "$cacheJsonDeployTfBackend" == "n" ]
    cacheJsonDeployTfBackend="$(jq -r '.defaultDeployCdk2Backend' "$generatedAppEnvDir/.choice-cache.json")"
    assert [ "$cacheJsonDeployTfBackend" == "n" ]

    # Verify IaC contents
    assert_exists "$iacRootsDir"
    assert_exists "$iacRootsDir/README.md"
    assert_exists "$iacRootsDir/$firstIacModuleName"
    assert_exists "$iacRootsDir/$firstIacModuleName/cf.yml"
    assert_exists "$iacRootsDir/$firstIacModuleName/parameters.json"
    assert_exists "$generatedAppEnvDir/iac-module-template"
    assert_not_exists "$iacRootsDir/cicd"

    # Verify the correct files got put in the project's root directory
    assert_exists "$generatedAppDir/.gitignore"
    assert_exists "$generatedAppDir/.gitleaksignore"
    assert_exists "$generatedAppDir/Makefile"
    assert_exists "$generatedAppDir/Makefile-4-customer"
    assert_exists "$generatedAppDir/README.md"
    assert_not_exists "$generatedAppDir/gitlab-ci.yaml"

    assert_exists "$generatedAppDir/build-script"

    # Verify contents of the generated project's Makefile
    run cat "$generatedAppDir/Makefile"
    assert_output --partial "deploy-$firstIacModuleName"
    assert_output --partial "destroy-$firstIacModuleName"

    # Verify contents of the generated project's environment/Makefile
    run cat "$generatedAppEnvDir/Makefile"
    assert_output --partial "create-environment:"
    assert_output --partial "get-current-environment:"
    assert_output --partial "switch-current-environment:"
    assert_output --partial "create_iac_root_module:"

    # Verify contents of the generated project's Makefile-4-customer
    run cat "$generatedAppDir/Makefile-4-customer"
    assert_output --partial "init:"
    assert_output --partial "deploy-$firstIacModuleName"
    assert_output --partial "destroy-$firstIacModuleName"

    cd -
}

# bats test_tags=deploys:true
# Test creating and deleting the app stack
@test "create cloudformation app and deploy it" {
    
    # We can't store real account numbers in a Git repo so we use environment variables to tell the
    # test which account to use to create the app
    if [ -z "$BATS_COIN_AWS_ACCOUNT" ]; then
        skip "BATS_COIN_AWS_ACCOUNT is not set"
    fi

    realAwsAccountId="$BATS_COIN_AWS_ACCOUNT"

    local cliAccountId=$(aws sts get-caller-identity --query Account --output text)
    
    if [[ "$realAwsAccountId" != "$cliAccountId" ]]; then
        skip "You are logged into account \"$cliAccountId\" but this the does not match the configured account: \"$realAwsAccountId\""
    fi

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "APP_NAME": "$appName",
        "AWS_ACCOUNT_ID": "$realAwsAccountId",
        "AWS_DEFAULT_REGION": "$defaultRegion",
        "AWS_SECONDARY_REGION": "blank",
        "cicd": "",
        "useCicd": "n",
        "coinAwsCliProfileName": "",
        "CREATED_BY": "Anthony Watson",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployRemoteEnvVars": "n",
        "deployCicdResources": "n",
        "deployTfBackend": "n",
        "ENV_NAME": "$envName",
        "firstIacModuleName": "$firstIacModuleName",
        "gitRepoDomain": "",
        "gitRepoProvider": "",
        "gitProjectGroup": "",
        "gitProjectName": "$gitProjectName",
        "hasSecondaryRegion": "n",
        "iac": "cf",
        "appParentDir": "$appParentDir",
        "REMOTE_ENV_VAR_LOC": "na",
        "TF_S3_BACKEND_NAME": "blank"
    }
EOF

    # use for debugging:
    # cat $BATS_COIN_AWS_ACCOUNT >&3
    
    run create_cloudformation_app "$inputFileName"

    # use for debugging in another terminal:
    # tail -n 50 -F "$COIN_HOME/.log.txt"
    
    assert_output --partial "Congratulations! Your application has been created at ${generatedAppDir}"

    cd "$generatedAppDir"

    # Deploy the app

    make deploy-example
    run cat "$generatedAppEnvDir/.log.txt"
    # echo -e $output >&3
    assert_output --partial "Finished executing CloudFormation command(s) on ${appParentDir}${gitProjectName}/iac/roots/${firstIacModuleName}"

    # Perform cleanup on created resources

    make destroy-example
    run cat "$generatedAppEnvDir/.log.txt"
    # echo -e $output >&3
    
    assert_output --partial "Executing \"cloudformation delete-stack --stack-name $appName-$envName-$firstIacModuleName\""
        
    cd -
}