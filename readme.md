# Jenkins Docker

## Terraform

Terraform version is a work in progress. Teh basic infrastructure does get created.
ToDo:

1. Create SSH keys
1. Install docker
1. Create TLS keys
1. Verify connection to remote Docker w/ TLS

```shell

terraform init -var-file="secret.tfvars" -var-file="abs.tfvars"

terraform plan -var-file="secret.tfvars" -var-file="abs.tfvars"

terraform apply -var-file="secret.tfvars" -var-file="abs.tfvars"

```

secret.tfvars :
```terraform

azure_subscription_id = "00000000-0000-0000-0000-000000000000"

```

## Shell Script

```shell

sh abs_create.sh

```
