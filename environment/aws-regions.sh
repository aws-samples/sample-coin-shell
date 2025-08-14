#!/usr/bin/env bash

# This script configures the valid AWS regions that can be used.

# Create global constants to hold AWS region values
awsRegionChoicesArray=()
awsRegionCodesArray=()

# Add all supported AWS regions to the below list
awsRegionChoicesArray+=("ap-east-1 (Hong Kong)")
awsRegionChoicesArray+=("ap-northeast-1 (Tokyo)")
awsRegionChoicesArray+=("ap-northeast-2 (Seoul)")
awsRegionChoicesArray+=("ap-northeast-3 (Osaka)")
awsRegionChoicesArray+=("ap-south-1 (Mumbai)")
awsRegionChoicesArray+=("ap-south-2 (Hyderabad)")
awsRegionChoicesArray+=("ap-southeast-1 (Singapore)")
awsRegionChoicesArray+=("ap-southeast-2 (Sydney)")
awsRegionChoicesArray+=("ap-southeast-3 (Jakarta)")
awsRegionChoicesArray+=("ap-southeast-4 (Melbourne)")
awsRegionChoicesArray+=("eu-central-1 (Frankfurt)")
awsRegionChoicesArray+=("eu-central-2 (Zurich)")
awsRegionChoicesArray+=("eu-north-1 (Stockholm)")
awsRegionChoicesArray+=("eu-south-1 (Milan)")
awsRegionChoicesArray+=("eu-south-2 (Spain)")
awsRegionChoicesArray+=("eu-west-1 (Ireland)")
awsRegionChoicesArray+=("eu-west-2 (London)")
awsRegionChoicesArray+=("eu-west-3 (Paris)")
awsRegionChoicesArray+=("us-east-1 (N. Viginia)")
awsRegionChoicesArray+=("us-east-2 (Ohio)")
awsRegionChoicesArray+=("us-west-1 (N. Califonia)")
awsRegionChoicesArray+=("us-west-2 (Oregon)")

# Add valid AWS region codes into an array
for awsRegionIndex in ${!awsRegionChoicesArray[@]}; do
    awsRegionCodesArray+=("${awsRegionChoicesArray[$awsRegionIndex]%[[:space:]](*}") # trim region description off the end
done

# Create a pipe-delimited string with all of the valid AWS region codes
printf -v awsJoinedRegionCodes '%s|' "${awsRegionCodesArray[@]}"
# remove final pipe at the end of the string
awsJoinedRegionCodes="${awsJoinedRegionCodes%|}"

# Create a regex to validate an AWS region code entry
awsJoinedRegionCodesRegex="^(${awsJoinedRegionCodes})$"
