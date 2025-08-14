#!/usr/bin/env bats

setup_file () {
    :
    # echo '# Hello there from setup_file' >&3
}

setup () {
    load '../../test-helper/common-setup'
    _common_setup

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
    defaultRegion="us-east-1"
    remoteLoc="na"
    createdBy="Anthony Watson"
    tfBackend="$appName-$envName-tf-back-end"
    secretCreated="n"

    simpleSecretName="bats-simple-secret"
    simpleSecretValue="BatsSecretValue123"

    jsonSecretName="bats-json-secret"
    jsonSecretKey="batsKey"
    jsonSecretKeyVal="batsKeyValue"
    jsonSecretValue="{\"$jsonSecretKey\":\"$jsonSecretKeyVal\",\"anotherKey\":\"someValue\"}"

    secretConfigNameSimple="SECRET_BATS_SIMPLE_CONFIG"
    secretConfigNameJson="SECRET_BATS_JSON_CONFIG_PROP_$jsonSecretKey"

    # Create a secret with a simple value on the cloud
    run aws secretsmanager create-secret \
    --name "$simpleSecretName" \
    --secret-string "$simpleSecretValue" \
    --region "$defaultRegion"

    # Create a secret with a JSON value on the cloud
    run aws secretsmanager create-secret \
    --name "$jsonSecretName" \
    --secret-string "$jsonSecretValue" \
    --region "$defaultRegion"

    assert_success
    secretCreated="y"

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
        "AWS_ACCOUNT_ID": "$realAwsAccountId",
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

    run create_terraform_app "$inputFileName"
    
    assert_output --partial "Congratulations! Your application has been created at ${generatedAppDir}"
    assert_exists "$generatedAppDir"

}

teardown () {
    rm -f "$inputFileName"
    rm -rf "$generatedAppDir"

    if [[ "$secretCreated" == "y" ]]; then
        # Delete the secrets created on the cloud
        run aws secretsmanager delete-secret --secret-id "$simpleSecretName" --region "$defaultRegion" --force-delete-without-recovery
        assert_success
        run aws secretsmanager delete-secret --secret-id "$jsonSecretName" --region "$defaultRegion" --force-delete-without-recovery
        assert_success
    fi
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
    make pce f="$1" 2>&1 | sed -e 's/\x1b\[[0-9;]*m//g'
}

# bats file_tags=type:functional, suite:placeholder-resolution, iac:terraform

@test "secret placeholder resolution" {

    cd "$generatedAppDir" 

    # Configure a dynamic lookup for the secrets
    echo "LOOKUPS[$secretConfigNameSimple]=$simpleSecretName" >> "$generatedAppEnvDir/dynamic-lookups.sh"
    echo "LOOKUPS[$secretConfigNameJson]=$jsonSecretName" >> "$generatedAppEnvDir/dynamic-lookups.sh"

    # Add new required properties to app-env-var-names.txt. The value of these properties will be retrieved from AWS Secrets Manager
    echo -e "\n# Value to be looked up from a simple secret\n$secretConfigNameSimple" >> "$generatedAppEnvDir/app-env-var-names.txt"
    echo -e "\n# Value to be looked up from a JSON secret\n$secretConfigNameJson" >> "$generatedAppEnvDir/app-env-var-names.txt"

    # Run the print-current-environment utility to get the value of the new configuration
    # By default, dynamic resolution is disabled, meaning that no attempt will be made to look up the SSM param value from the cloud
    run execute_pce
    # echo "$output" >&3
    assert_output --partial "\"$secretConfigNameSimple\": \"blank\""
    assert_output --partial "\"$secretConfigNameJson\": \"blank\""

    # Now, turn on dynamic resolution and verfiy that the configuration got set to the value from the SSM param
    export DYNAMIC_RESOLUTION="y"
    run execute_pce
    # echo "$output" >&3
    assert_output --partial "\"$secretConfigNameSimple\": \"$simpleSecretValue\""
    assert_output --partial "\"$secretConfigNameJson\": \"$jsonSecretKeyVal\""

    # Verify that the value from AWS Secrets Manager got cached locally
    assert_exists "$generatedAppEnvDir/.environment-$envName-lookup-cache.json"
    run cat "$generatedAppEnvDir/.environment-$envName-lookup-cache.json"
    # echo "$output" >&3
    assert_output --partial "\"$secretConfigNameSimple\": \"$simpleSecretValue\""
    assert_output --partial "\"$secretConfigNameJson\": \"$jsonSecretKeyVal\""

    # Now, turn off dynamic resolution and verfiy that the configuration got set to the value from the local cache
    export DYNAMIC_RESOLUTION="n"
    run execute_pce
    # echo "$output" >&3
    assert_output --partial "\"$secretConfigNameSimple\": \"$simpleSecretValue\""
    assert_output --partial "\"$secretConfigNameJson\": \"$jsonSecretKeyVal\""

    cd -
}
