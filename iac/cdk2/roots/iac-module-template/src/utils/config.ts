
export interface AppConfig {
    readonly appName: string;
    readonly envName: string;
    readonly awsAccountId: string;
    readonly awsDefaultRegion: string;
}

export async function getConfig(): Promise<AppConfig> {

    let config: AppConfig = {
        appName: process.env.APP_NAME as string,
        envName: process.env.ENV_NAME as string,
        awsAccountId: process.env.AWS_ACCOUNT_ID as string,
        awsDefaultRegion: process.env.AWS_DEFAULT_REGION as string,
    };
    return config;
}
