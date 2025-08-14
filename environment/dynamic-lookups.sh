#!/usr/bin/env bash

# This script allows you to configure dynamic lookups for placeholder resolution.
# For example, you can define a placeholder in a file and have it be resolved
# with a value that was retreived from the SSM Parameter Store or Secrets Manager. 
# To accomplish this, you configure an association in this file between your 
# placeholder and the path to lookup the value.
# Examples:
#   Look up SSM param key using the environment's default AWS region
#   LOOKUPS[SSM_MYVAR]=/$APP_NAME/$ENV_NAME/someOptionalPath/myVar
# 
#   Look up SSM param key from a specific region that is set directly in the variable name
#   LOOKUPS[SSM_US_WEST_2_MYVAR]=/$APP_NAME/$ENV_NAME/someOptionalPath/myVar
#
#   Look up a secret that has a single value
#   LOOKUPS[SECRET_MYSECRETVAR]=$APP_NAME-config
#
#   This example will set your variable value to the "username" property
#   of a secret if the secret holds a JSON object that has "username"
#   as one of its properties. Just add "_PROP_<myPropName>" to the name
#   of the lookup to configure this behavior.
#   LOOKUPS[SECRET_MYSECRETVAR_PROP_username]=$APP_NAME-config

# Add dynamic lookup configurations here:

