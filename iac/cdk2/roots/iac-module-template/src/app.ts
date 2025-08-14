#!/usr/bin/env node

import * as cdk from "aws-cdk-lib";
import "source-map-support/register";
import { AwsSolutionsChecks } from 'cdk-nag';
import { getConfig } from "./utils/config";
import { ###COIN_IAC_MOD_CAMELCASE###Stack } from './stack';

/**
 * Main application function, make it async so it can call asnyc functions properly.
 */
async function main() {
    const app = new cdk.App();

    //Load config, when ready start the app
    console.log("Loading Configurations...");
    const config = await getConfig();
    console.log(JSON.stringify(config));
    console.log("DONE");

    if (!config) throw Error("Config not defined");

    cdk.Aspects.of(app).add(new AwsSolutionsChecks());

    cdk.Tags.of(app).add("App", config.appName);
    cdk.Tags.of(app).add("Env", config.envName);

    new ###COIN_IAC_MOD_CAMELCASE###Stack(app, `${config.appName}-${config.envName}-###COIN_IAC_MOD_SPINALCASE###`, {
        config,
        env: { account: config.awsAccountId, region: config.awsDefaultRegion }
    });

    app.synth();
}

main();
