#Creamos el bucket y el sqs default en el localstack de acuerdo con https://docs.localstack.cloud/aws/integrations/infrastructure-as-code/terraform/#manual-configuration
#Omitimos la verificación con https://registry.terraform.io/providers/hashicorp/aws/latest/docs#skip_requesting_account_id-1

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_requesting_account_id  = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true

  endpoints {
    s3  = "http://s3.localhost.localstack.cloud:4566" 
    sqs = "http://localhost:4566"
  }
}
