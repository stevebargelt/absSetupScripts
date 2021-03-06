#!/bin/bash

########################################################
#### Change the following to customize your install ####
########################################################

#this will be the name of the resource group and the VM + all other compoents will use this as the base of their names
baseName="abs" 

# for testing and rapidly creating multiple versions for tutorials or testing. Script will create something like dockerBuild01 <- given a suffix of 01 and a baseName of dockerBuild
versionSuffix="3"

#Storage accounts names must be unique. Adding a random number may help with that. Kept it to 3 
#  digits because they also must be under 24 characters. Should probs add some checks fof this.
storageAccountRandom=$((100 + RANDOM % 899)) 

#The Azure location for your resources
location="westus2"

#Your Azure account name.
azureAccountName="Visual Studio Enterprise"

#Your Azure Subscription
azureSubscription="61ed2619-32a9-45d9-8e24-771cc7c48d4a"

#VM Admin user information
username="dockeruser"

#custom dns name
customDnsBase="harebrained-apps.com"

########################################################
#### The remainder can be changed but not required  ####    
########################################################

#dns names and storage account names can't have upppercase letters
baseNameLower=$(echo "$baseName" | tr '[:upper:]' '[:lower:]')

echo "=> basenamelower <="
echo $baseNameLower

#Resource group info
rgName="$baseName$versionSuffix"

# Set variables for VNet
vnetName="${baseName}vnet"
vnetPrefix="10.0.0.0/16"
subnetName="default"
subnetPrefix="10.0.0.0/24"

# Set variables for storage
stdStorageAccountName="${baseNameLower}storage${versionSuffix}${storageAccountRandom}"

# Set variables for VM
vmSize="Standard_D2S_V3"
publisher="Canonical"
offer="UbuntuServer"
sku="16.04.0-LTS"
version="latest"
vmName="${baseName}"
nicName="${baseName}NIC"
privateIPAddress="10.0.0.4"
pipName="${baseName}-ip"
nsgName="${baseName}-nsg"
osDiskName="osdisk"

#VM Admin user information
adminKeyPairName="id_${vmName}_rsa"

#DNS Naming
dnsName="${baseNameLower}system$versionSuffix"
fullDnsName="${dnsName}.${location}.cloudapp.azure.com"
customDnsName="${baseNameLower}.$customDnsBase"

#where to place the remote Docker Host TLS certs
tlsCertLocation="./certs/$rgName"
rsaKeysLocation="./keys/$rgName"

SCRIPTS_LOCATION=$PWD

########################################################
#### The script actually begins...                  ####
########################################################

#TODO: the docker running/stopped/non-existant code could use updating
RUNNING=$(docker inspect --format="{{ .State.Running }}" azureCli 2> /dev/null)

if [ $? -eq 1 ]; then
  	echo "azureCli container does not exist. Executing docker run"
	docker run -td --name azureCli -v $SCRIPTS_LOCATION:/config microsoft/azure-cli
	
	docker exec -it azureCli az login  
fi

if [ "$RUNNING" == false ]; then
  	echo "azureCli is not running. Executing docker start"
      #should START here
	docker start azureCli
	
	docker exec -it azureCli az login  
fi

#Please store the private key securly once this is done!
printf "=> Creating admin SSH keypair: $rsaKeysLocation/$adminKeyPairName <="
mkdir -p $rsaKeysLocation
ssh-keygen -t rsa -b 2048 -C "$username@Azure-$rgName-$vmName" -f "$rsaKeysLocation/$adminKeyPairName" -q -N ""

set -xe

docker exec -it azureCli az account set --subscription "$azureSubscription"

echo "=> Create resource group <="
# Create Resource Group
docker exec -it azureCli az group create --name $rgName --location $location

echo "=> Create  VNet <="
docker exec -it azureCli az network vnet create --resource-group $rgName \
    --name $vnetName \
    --address-prefixes $vnetPrefix \
    --location $location

echo "=> Create  subnet <="
docker exec -it azureCli az network vnet subnet create --resource-group $rgName \
    --vnet-name $vnetName \
    --name $subnetName \
	  --address-prefix $subnetPrefix

echo "=> Create Public IP <="
docker exec -it azureCli az network public-ip create --resource-group $rgName \
    --name $pipName \
    --location $location \
    --allocation-method Static

echo "=> Get IP Address <=<"

publicIPAddress=$(docker exec -it azureCli az network public-ip show --resource-group $rgName --name $pipName |grep "ipAddress" | awk -F ":" '{print $2}' |tr -d '\r' | tr -d ',' | tr -d '"')
echo "PublicIP:$publicIPAddress"

echo "=> Create network security group <="
docker exec -it azureCli az network nsg create --resource-group $rgName \
    --name $nsgName \
    --location $location

echo "=> Create NIC <="
docker exec -it azureCli az network nic create --name $nicName \
    --resource-group $rgName \
    --subnet $subnetName \
    --vnet-name $vnetName \
    --network-security-group $nsgName \
    --location $location \
    --private-ip-address $privateIPAddress \
    --public-ip-address $pipName

echo "=> Create inbound security rules <="
echo "=> Create allow-ssh rule <="
docker exec -it azureCli az network nsg rule create --protocol tcp \
    --direction inbound \
    --priority 1000 \
    --destination-port-range 22 \
    --access allow \
    --resource-group $rgName \
    --nsg-name $nsgName \
    --name allow-ssh

echo "=> Create allow-http rule <="
docker exec -it azureCli az network nsg rule create --protocol tcp \
    --direction inbound \
    --priority 1010 \
    --destination-port-range 80 \
    --access allow \
    --resource-group $rgName \
    --nsg-name $nsgName \
    --name allow-http

echo "=> Create allow-docker-tls rule  <="
docker exec -it azureCli az network nsg rule create --protocol tcp \
    --direction inbound \
    --priority 1020 \
    --destination-port-range 2376 \
    --access allow \
    --resource-group $rgName \
    --nsg-name $nsgName \
    --name allow-docker-tls

echo "=> Create allow-jenkins-jnlp rule  <="
docker exec -it azureCli az network nsg rule create --protocol tcp \
    --direction inbound \
    --priority 1030 \
    --destination-port-range 50000 \
    --access allow \
    --resource-group $rgName \
    --nsg-name $nsgName \
    --name allow-jenkins-JNLP

# Added the two following rules in part three of tutorial 
echo "=> Create allow-docker-registry rule  <="
docker exec -it azureCli az network nsg rule create --protocol tcp \
    --direction inbound \
    --priority 1040 \
    --destination-port-range 5000 \
    --access allow \
    --resource-group $rgName \
    --nsg-name $nsgName \
    --name allow-docker-registry

echo "=> Create allow-https rule  <="
docker exec -it azureCli az network nsg rule create --protocol tcp \
    --direction inbound \
    --priority 1050 \
    --destination-port-range 443 \
    --access allow \
    --resource-group $rgName \
    --nsg-name $nsgName \
    --name allow-https

#Added the registry blob storage in part 3 of the tutorial
echo "=> Create the Docker Registry Blob Storage <="
docker exec -it azureCli az storage account create \
    --resource-group $rgName \
    --name ${baseNameLower}${versionSuffix}registry${storageAccountRandom} \
    --kind BlobStorage \
    --sku Standard_LRS \
    --access-tier Hot \
    --location $location

echo "=> Create the VM <="
docker exec -it azureCli az vm create \
    --resource-group $rgName \
    --name $vmName \
    --location $location \
    --size $vmSize \
    --nics $nicName \
    --image $publisher:$offer:$sku:$version \
    --admin-username $username \
    --ssh-key-value "/config/$rsaKeysLocation/$adminKeyPairName.pub"

# publicIPAddress=$(docker exec -it azureCli az network public-ip show --resource-group $rgName --name $pipName |grep "ipAddress" | awk -F ":" '{print $2}' |tr -d '\r' | tr -d ',' | tr -d '"')
# echo "PublicIP:$publicIPAddress"

# printf "=> Installing Docker Extension will fail unless we run an apt-get update in the VM <="
# ssh -o StrictHostKeyChecking=no $username@$fullDnsName -i "$rsaKeysLocation/$adminKeyPairName" "sudo apt-get update" 

printf "=> create docker tls certs <="
mkdir -p "$tlsCertLocation"
sh create-docker-tls.sh $customDnsName $fullDnsName $publicIPAddress $privateIPAddress $tlsCertLocation

printf "=> Add Docker extension to VM <="
sh add-docker-ext.sh $rgName $vmName $tlsCertLocation

printf "=> Finished <=\n"
printf "Connect to docker:\n"
printf "cd $tlsCertLocation"
printf "DO THIS: docker --tlsverify --tlscacert=ca.pem --tlscert=cert.pem --tlskey=key.pem -H=tcp://$publicIPAddress:2376 version"
