# Environment Variable Resolution Test Cases

## app-env-var-names.txt contains a variable that is not set to a value

  * Should log an explanatory error
  * If the variable is not a dynamic lookup
    * Should exit immediately with an error code

## Retrieving Current Environment Values

* Should load values from `environment/.environment-<current>.json` where <current> is the value set in `environment/.current-environment`

## Retrieving Dynamically Looked Up Values

Dynamic Lookup Configurations are configs with values that are NOT set in environment JSON files. Instead, the values live in the SSM Parameter Store or Secrets Manager.

If a configuration name from `environment/app-env-var-names.txt` is also defined in `environment/dynamic-lookups.sh`, that configuration is considered a "dynamic lookup".

* Values set in `environment/dynamic-lookups.sh` should be able to reference static environment configs such as $APP_NAME

* If the environment variable, `DYNAMIC_RESOLUTION`, is not set to "y"
  * If lookup values cache file exists at `environment/.environment-<envName>-lookup-cache.json`
    * Should use cached values
  * Else
    * All Dynamic Lookup configurations should be set to blank strings
* Else
  * The configuration value should be looked up from AWS
  * A message should be shown on screen to inform the user that the lookup is happening
  * The lookup value should be cached in memory so that it is only looked up once per command execution
  * All lookup values should be cached in a `environment/.environment-<envName>-lookup-cache.json` file 
  * If the configuration lookup fails
    * If the environment variable, `FAIL_ON_LOOKUP_ERROR`, is set to "n"
      * Should set the configuration value to a blank string
    * Else
      * Should log an error and exit with a failure code

## Environment Constants

* Should load environment constant values from `environment/environment-constants.json`.

* Values from `environment/.environment-<current>.json` should override
values from `environment/environment-constants.json`
  * If the constant is set to "blank"
    * Display an INFO message to let the user know that a value has been detected that overrides the blank constant value
  * If the constant is NOT set to "blank"
    * A warning should be displayed to let the user know that they are overriding a constant.

* If a setting from `environment/app-env-var-names.txt` is NOT set in `environment/.environment-<current>.json` but IS set in `environment/env-constants.json`
  * No error should be shown and the constant value should be used

## Sensitive Environment Configs

* Should load environment values from `environment/.environment-<current>-sensitive.json`.
* Should not throw an error if `environment/.environment-<current>-sensitive.json` does not exist.

* Values from `environment/.environment-<current>-sensitive.json` should override
values from `environment/.environment-<current>.json` that are set to a value of "sensitive"

* If environment value is set to "sensitive" but no `environment/.environment-<current>-sensitive.json` file exists, display an error message.

* If environment value is set to "sensitive" but no override value is set in `environment/.environment-<current>-sensitive.json`, display an error message.

## Placeholder found in template file does not exist in app-env-var-names.txt

If a traditional tripple pound sign placeholder is set in a file and that
placeholder does not exist in `environment/app-env-var-names.txt`
* Should log an explanatory error

## Built-In Placeholders

* Should resolve `###CUR_DIR_NAME###` to the current module directory name
  * If we have an IaC module here: `iac/roots/nested/mymod`
    * If the `projectUseNestedPathForCurDirName` constant is set to "y"
      * `CUR_DIR_NAME` should resolve to `nested/mymod`
    * If the `projectUseNestedPathForCurDirName` constant is set to "n"
      * `CUR_DIR_NAME` should resolve to `mymod`
* Should resolve these based on current Git repository settings:
  * `###gitProjectName###`
  * `###gitProjectGroup###`
  * `###gitRepoDomain###`

## Command Line Overrides

If a variable is set on the command line with the appropriate naming convention (e.g. starts with "COIN_OVERRIDE_"), it should override values set in the environment configuration JSON file. For example, if a variable name is X, setting COIN_OVERRIDE_X as a variable before calling utility-functions.sh should cause the override value to be used.