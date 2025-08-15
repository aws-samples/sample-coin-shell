# Create App Environment Wizard Test Cases

The create app environment wizard is defined here: `environment/create-app-environment.sh`

## Input Validation

See the "Input Validation" section of `wizard-create-app.md` since the validation rules are the same for creating new apps and create new environments for apps.

## Load Previous Values

* If `environment/.choice-cache.json` is present
  * Should ask if the user wants to load previously cached wizard values
    * If yes, the default answers should be set from the cache
    * If not, the defautl answers should be set from system defaults
* Else
  * Should load default settings from the `initialChoiceVals` that is baked
  into `environment/create-app-environment.sh`

## Choice Caching

Should cache user choices in `environment/.choice-cache.json` when the script exits

## Logging

Should log wizard-session debugging information to `environment/.log.txt`

## Asking Questions and Environment Constants

* Set all values automatically that are found in `environment/environment-constants.json`
and do not ask the user to enter anything for those configurations
* Ask the user to enter values for all configurations declared in `environment/app-env-var-names.txt` that are not already set by `environment/environment-constants.json`.

## Fresh Repository Download

Should not show any errors or warnings about the current environment files not being
set up since these files will not be present when a fresh repository clone is taken.
Start by deleting `environment/.choice-cache.json` and any `.environment-*.json` files
and `environment/make-env` in order to test this.

## Environment JSON File Generation

* Should generate a `environment/.environment-<ENV_NAME>.json file`
* The JSON file should have all of the user's choices
* The JSON file should NOT have entries for dynamic configs found in `environment/dynamic-lookups.sh`
* The JSON file should NOT have entries for configs that are set in `environment/environment-constants.json`
* After the wizard completes, it should set the `environment/.current-environment` to the newly created environment

## Headless Mode

A file path can be passed into the wizard as the first argument to put the wizard into "headless" mode. The file contents should be a full environment JSON file. In headless mode, the values from the JSON file will be used and the user will not be asked any interactive questions regarding entering those values.

Even in headless mode, the deployment related questions will still be asked.

* Should perform input validation on headless input file
* Should not create a new app environment if this environment variable has been set: `export COIN_CREATE_APP_ENV_DRY_RUN="y"`

## Disabling Deployment Actions

* if user enters all 0's for account id, don't ask about deployment options or execute them

### Mapping AWS CLI Profiles to COIN Environments

* When creating a new app environment interactively
  * Should not ask the user about AWS CLI profiles if (s)he set the AWS account ID as all 0's
  * When you want to create a new profile automatically
    * Profile does not exist
      * Adds new profile entry in `~/.aws/config` file
      * Creates/updates `environment/.cli-profiles.json`
    * Profile exists
      * Skips creating entry in `~/.aws/config` file and logs this
      * Creates/updates `environment/.cli-profiles.json`
  * When you want to associate an existing profile
    * Does not update `~/.aws/config` file
    * Creates/updates `environment/.cli-profiles.json` with user-entered value
  * When you want to skip profile mapping to COIN environments
    * Does not update `~/.aws/config` file
    * Does not create/update `environment/.cli-profiles.json`
* When creating a new app environment in headless mode
  * Same test scenarios as interactive mode

### Custom Extensions

* Should call custom extension functions defined in `extensions.sh`
  * `ask_custom_create_app_environment_questions`
  * `ask_custom_create_app_environment_questions_headless_input_validation` 
  * `take_custom_create_app_environment_actions`
  * `take_custom_create_app_environment_deployment_actions`