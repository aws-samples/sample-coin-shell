# Create App IaC Module Test Cases

The create IaC module wizard is defined here: `environment/create-iac-module.sh`

## Input Validation

Should validate a max length and ensure no white space for the new module name.

## Logging

Should log wizard-session debugging information to `environment/.log.txt`

## Expected Behavior

* Should ask the user for the module name
* Should ask the user where to put the module
  * Should enforce that the module must be placed somewhere under `iac/roots`
* Should check if a module directory already exists that matches the user's input and ask the user to change the name/location if so
* Should generate a new module, for example, under `iac/roots/<newModuleName>`
  * The new module should be based on the `environment/iac-module-template`
  * These placeholders should be resolved in the new module to match the name the user typed in:
    * COIN_IAC_MOD_SPINALCASE
    * COIN_IAC_MOD_CAMELCASE
* Should update `environment/Makefile` with deploy/destroy targets
  * Target definitions must be specific to the IaC type for the app (e.g. CDK, Terraform, CloudFormation)
* Should update `environment/Makefile-4-customer` with deploy/destroy targets

