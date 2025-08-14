# Bad Configuration Detection Test Cases

## Current environment is not set in environment/.current-environment or this file does not exist

* Should log an explanatory error
* Should stop executing

## Current environment JSON file does not exist

If the user is NOT trying to create a new environment or pull down
the configs from an existing environment:

* Should log an explanatory error
* Should stop executing

## Not logged into the AWS account that is configured

* Should log an explanatory error
* Should stop executing
