# COIN Shell Release Notes

# November 2025

* Added `make help` and `make coin-help` commands that will print out documentation for each command, grouped by category
* CDK stack synthesizer now defaults to using the current user's IAM credentials to perform deployments instead of trying to assume a role created by the CDK bootstrap.
* Fix project-specific CDK binary detection so that it can work with yarn/npm workspaces
* Improve CDK context-clearing behavior to not clear acknowledged-issue-numbers

# October 2025

* Perform validation of your environmnt configurations either directly or automatically before running a script
  * To use, call `make validate-current-environment` directly or add the validation step to an existing Make target
* Easily perform an `aws sso login` based on your current environment by running `make aws-sso-login`

## August 14, 2025

Initial release!
