#!/bin/bash

if [ "$#" -gt 1 ]; then
  RESOURCE_GROUP_NAME="$1"
  ACR_NAME="$2"
else
  echo " => ERROR: You must specify the Azure Resource Group Name and the Azure Container Registry (ACR) Name  <="
  exit 1
fi

#TODO: Send sku as a parameter

printf "=> Creating the Azure Container Registry <=\n"
docker exec -it azureCli az acr create -n $ACR_NAME -g $RESOURCE_GROUP_NAME --sku Basic --admin-enabled true

printf "=> The registry FQDN is: <=\n"
registryDNS=$(docker exec -it azureCli az acr list --resource-group $RESOURCE_GROUP_NAME --query "[].{acrLoginServer:loginServer}" |grep "acrLoginServer" | awk -F ":" '{print $2}' |tr -d ' ' |tr -d '\r' | tr -d ',' | tr -d '"')
printf "$registryDNS\n\n"

printf "=> The registry password is: <=\n"
registryPasssword=$(docker exec -it azureCli az acr credential show -n $ACR_NAME --query 'passwords[0].value' |tr -d ' ' |tr -d '\r' | tr -d ',' | tr -d '"')
printf "$registryPasssword\n\n"

printf "=> Appending to $RESOURCE_GROUP_NAME Notes <= \n"
echo "
Registry DNS:
$registryDNS

Registry Password:
$registryPasssword" >> $RESOURCE_GROUP_NAME-notes.md