import * as cdk from "aws-cdk-lib";

export interface AppConfig {
    readonly appName: string;
    readonly envName: string;
    readonly awsAccountId: string;
    readonly awsDefaultRegion: string;

    /**
     * Synthesizer to use for CDK stacks.
     */
    readonly stackSynthesizer: cdk.IStackSynthesizer;
}

export async function getConfig(): Promise<AppConfig> {

    let config: AppConfig = {
        appName: process.env.APP_NAME as string,
        envName: process.env.ENV_NAME as string,
        awsAccountId: process.env.AWS_ACCOUNT_ID as string,
        awsDefaultRegion: process.env.AWS_DEFAULT_REGION as string,

        /*
         * See https://docs.aws.amazon.com/cdk/v2/guide/configure-synth.html
         * cdk.CliCredentialsStackSynthesizer - Instead of assuming the CDK bootstrap deployment roles, all stack operations will be performed using the CLI's current credentials.
         * cdk.DefaultStackSynthesizer - attempts to assume CDK bootstrap IAM roles for performing deployments
        */
        stackSynthesizer: new cdk.CliCredentialsStackSynthesizer(),
    };
    return config;
}
