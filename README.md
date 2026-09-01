

## Using LocalStack

LocalStack is a local AWS emulator. You can use Terraform and AWS CLI against LocalStack to test your configuration and simulate AWS resource deployments. This sandbox includes a file named `localstack_overrides.tf` that configures the AWS provider in your configuration to point to LocalStack instead of trying to reach AWS. This uses the free edition of LocalStack, which has limitations on which resources it will allow you to deploy. For more information on which resources are included in the free version, refer to the [AWS service feature coverage](https://docs.localstack.cloud/user-guide/aws/feature-coverage/) documentation.


## Using AWS

If you would like to deploy resources to AWS, delete the `localstack_overrides.tf` file and configure the AWS provider using the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables.

## AWS CLI

This sandbox has the `aws` command aliased to the `awslocal` CLI, the tool to make AWS CLI calls to LocalStack. You can use this tool just as you would the normal `aws` CLI. For example, the following command will communicate with LocalStack to get a list of the EC2 instances it currently has mocked.


http://localhost:30000 for hello world