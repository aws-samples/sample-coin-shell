
export interface CicdConfig {
    readonly appName: string;
    readonly envName: string;
    readonly awsAccountId: string;
    readonly awsDefaultRegion: string;
    // BEGIN_GITLAB_ROLE_CICD_PROPS_API
    readonly gitLabGroup: string;
    readonly gitLabProject: string;
    // END_GITLAB_ROLE_CICD_PROPS_API
}

export async function getConfig(): Promise<CicdConfig> {
    const config: CicdConfig = {
        appName: process.env.APP_NAME as string,
        envName: process.env.ENV_NAME as string,
        awsAccountId: process.env.AWS_ACCOUNT_ID as string,
        awsDefaultRegion: process.env.AWS_DEFAULT_REGION as string,
        // BEGIN_GITLAB_ROLE_CICD_PROPS_VALUE
        gitLabGroup: process.env.gitProjectGroup as string,
        gitLabProject: process.env.gitProjectName as string,
        // END_GITLAB_ROLE_CICD_PROPS_VALUE
    };
    return config;
}
