# Jenkins Docker

## Terraform

Terraform version is a work in progress. Teh basic infrastructure does get created.

### ToDo:

1. Create SSH keys for VM
1. Create TLS keys for remote Docker communication
1. Verify connection to remote Docker w/ TLS
1. Clone git repo and start with docker compose
~~1. Install Docker in VM~~

Maybe:
1. Pull backup data to restore state
1. Use renew or add letsencrypt


### Basics

Create secret.tfvars :

```terraform

azure_subscription_id = "00000000-0000-0000-0000-000000000000"

```

Edit abs.tfvars for your enviroment.

Create the TLS keys for SSHing into your VM

~~~shell

sh tls-create.sh

~~~

```shell

terraform init -var-file="secret.tfvars" -var-file="abs.tfvars"

terraform plan -var-file="secret.tfvars" -var-file="abs.tfvars"

terraform apply -var-file="secret.tfvars" -var-file="abs.tfvars"

```

### Manual Verify

To manually verify you can connect over SSH

Replace abs3 with your fullName variable
Replace absadmin with your adminUsername
Replace abs3.westus2.cloudapp.azure.com wit your fqdn or Public IP

```shell

eval "$(ssh-agent -s)"  
ssh-add ./keys/abs3/id_abs3_rsa
ssh absadmin@abs3.westus2.cloudapp.azure.com

```

## Shell Script

Edit the variables in the first 30 lines of the script.

```shell

sh abs_create.sh

```

Get a cup of coffee... this takes a little while. 
