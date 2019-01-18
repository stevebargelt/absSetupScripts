# Jenkins Docker

## TErraform

```shell

terraform init \
  -var-file="secret.tfvars" \
  -var-file="abs.tfvars"

terraform plan \
  -var-file="secret.tfvars" \
  -var-file="abs.tfvars"

terraform apply \
  -var-file="secret.tfvars" \
  -var-file="abs.tfvars"

```