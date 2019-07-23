#!/bin/bash

RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# set -x
# set -e

########################################################
#### Change the following to customize your install ####
########################################################

#this will be the name of the resource group and the VM + all other compoents will use this as the base of their names
baseName="absv2" 

# for testing and rapidly creating multiple versions for tutorials or testing. 
# Script will create something like dockerBuild01 <- given a suffix of 01 and a baseName of dockerBuild
versionSuffix="020"

#The Azure location for your resources
location="westus2"

#Your Azure account name.
azureAccountName="VSE02"

#Your Azure Subscription
azureSubscription="c7e800cb-0ee6-4175-9605-a6b97c6f419f"

#VM Admin user information
adminusername="absadmin"

#custom dns name
customDnsBase="harebrained-apps.com"

########################################################
#### Docker TLS Certificate Details                 ####    
########################################################

tlsCountry=US
tlsState=Washington
tlsLocality=Seattle
tlsOrganization=harebrained-apps.com
tlsOrganizationalUnit=SoftwareDev
tlsEmail=steve@bargelt.com
tlsPassphrase=correcthorebatterystaple

########################################################
#### The remainder can be changed but not required  ####    
########################################################

echo "=> basenamelower <="
echo $baseNameLower

#Resource group info
rgName="$baseName$versionSuffix"

# Azure Container Registry (ACR) Name
acrName="${rgName}registry"

# Set variables for VNet
vnetName="${baseName}vnet"
vnetPrefix="10.0.0.0/16"
subnetName="default"
subnetPrefix="10.0.0.0/24"

# Set variables for VM
vmSize="Standard_D2S_V3"
publisher="Canonical"
offer="UbuntuServer"
sku="18.04-LTS"
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

# TODO: the docker running/stopped/non-existant code could use updating
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

printf "=> Setting the 'az' alias for azureCLi in Docker container <=\n"
alias az="docker exec -it azureCli az"

# Please store the private key securly once this is done!
printf "=> Creating admin SSH keypair: $rsaKeysLocation/$adminKeyPairName <=\n"
printf "=> ${RED}***** Please store the private key securly once this is done! *****${NC}  <=\n"
mkdir -p $rsaKeysLocation
ssh-keygen -t rsa -b 2048 -C "$adminusername@Azure-$rgName-$vmName" -f "$rsaKeysLocation/$adminKeyPairName" -q -N ""

docker exec -it azureCli az account set --subscription $azureSubscription

echo "=> Create resource group <="
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

publicIPAddress=$(docker exec -it azureCli az network public-ip show --resource-group $rgName --name $pipName |grep "ipAddress" | awk -F ":" '{print $2}' |tr -d ' ' |tr -d '\r' | tr -d ',' | tr -d '"')
publicIPAddress="$(echo "${publicIPAddress}" | tr -d '[:space:]')"

printf "PublicIP:$publicIPAddress\n"

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

echo "=> Create allow-https rule  <="
docker exec -it azureCli az network nsg rule create --protocol tcp \
    --direction inbound \
    --priority 1050 \
    --destination-port-range 443 \
    --access allow \
    --resource-group $rgName \
    --nsg-name $nsgName \
    --name allow-https

echo "=> Create the VM <="
docker exec -it azureCli az vm create \
    --resource-group $rgName \
    --name $vmName \
    --location $location \
    --size $vmSize \
    --nics $nicName \
    --image $publisher:$offer:$sku:$version \
    --admin-username $adminusername \
    --ssh-key-value "/config/$rsaKeysLocation/$adminKeyPairName.pub"

printf "=> create docker tls certs <=\n"
mkdir -p "$tlsCertLocation"
printf "\n\n"
printf "sh create-docker-tls.sh $customDnsName $fullDnsName $publicIPAddress $privateIPAddress $tlsCertLocation $tlsCountry $tlsState $tlsLocality $tlsOrganization $tlsOrganizationalUnit $tlsEmail $tlsPassphrase"
printf "\n\n"
sh create-docker-tls.sh $customDnsName $fullDnsName $publicIPAddress $privateIPAddress $tlsCertLocation $tlsCountry $tlsState $tlsLocality $tlsOrganization $tlsOrganizationalUnit $tlsEmail $tlsPassphrase

# printf "=> create Azure Container Registry <=\n"
# sh abs-create-acr.sh $rgName $acrName

printf "=> copying docker tls certs to VM via scp <=\n"
printf "scp -o StrictHostKeyChecking=no -i "$rsaKeysLocation/$adminKeyPairName" $tlsCertLocation/{ca,server-cert,server-key}.pem $adminusername@$publicIPAddress:~ \n"
scp -o StrictHostKeyChecking=no -i "$rsaKeysLocation/$adminKeyPairName" $tlsCertLocation/{ca,server-cert,server-key}.pem $adminusername@$publicIPAddress:~

printf "=> copying docker systemd siles to VM via scp <="
scp -o StrictHostKeyChecking=no -i "$rsaKeysLocation/$adminKeyPairName" ./override.conf $adminusername@$publicIPAddress:~
scp -o StrictHostKeyChecking=no -i "$rsaKeysLocation/$adminKeyPairName" ./daemon.json $adminusername@$publicIPAddress:~

printf "${GREEN}=> VM Created... <=${NC}\n"
printf "${GREEN}ssh -i $rsaKeysLocation/$adminKeyPairName $adminusername@$publicIPAddress${NC}\n"

printf "=> Run Custom Script in VM <=\n"
docker exec -it azureCli az vm extension set \
    --resource-group $rgName \
    --vm-name $vmName --name customScript \
    --publisher Microsoft.Azure.Extensions \
    --protected-settings '{"fileUris": ["https://raw.githubusercontent.com/stevebargelt/absSetupScripts/v2/custom-setup.sh"],"commandToExecute": "./custom-setup.sh"}'    

printf "${GREEN}=> Finished <=${NC}\n"
printf "${GREEN}Connect to docker TLS Enabled to everything is working:${NC}\n"
printf "${GREEN}docker --tlsverify --tlscacert=$tlsCertLocation/ca.pem --tlscert=$tlsCertLocation/cert.pem --tlskey=$tlsCertLocation/key.pem -H=tcp://$publicIPAddress:2376 version${NC}\n\n\n"

printf "=> Writing Delete Script ${RED}(Careful!)${NC} <= \n"
echo "#!/bin/bash
docker exec -it azureCli az group delete -n $rgName --no-wait
rm -rf $tlsCertLocation
rm -rf $rsaKeysLocation
" > $rgName-delete.sh

printf "=> Writing $rgName Notes <= \n"
echo "
Public Ip Address: $publicIPAddress
DNS: $dnsName
Full DNS: $fullDnsName
Custom DNS: $rgName.$customDnsName
Admin User Name: $adminusername

Remote Docker Commands:
docker --tlsverify --tlscacert=$tlsCertLocation/ca.pem --tlscert=$tlsCertLocation/cert.pem --tlskey=$tlsCertLocation/key.pem -H=tcp://$publicIPAddress:2376 version

SSH:
ssh -i $rsaKeysLocation/$adminKeyPairName $adminusername@$publicIPAddress

Create Azure Container Registry:
sh abs-create-acr.sh $rgName $acrName

Set user access to docker:
sudo usermod -aG docker $USER
(need to logoff/in to take effect)

Delete Entire Environment:
sh $rgName-delete.sh

" > $rgName-notes.md