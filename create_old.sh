#!/bin/bash

versionSuffix="solo3" #for testing and rapidly creating multiple versions for tutorial

azureAccountName="Visual Studio Enterprise"

#Resource group info
rgName="dockerBuild$versionSuffix"
location="westus"

# Set variables for VNet
vnetName="dockerBuildvnet"
vnetPrefix="10.0.0.0/16"
subnetName="default"
subnetPrefix="10.0.0.0/24"

# Set variables for storage
stdStorageAccountName="dockerbuildstorage$versionSuffix"

# Set variables for VM
vmSize="Standard_DS1_V2"
publisher="Canonical"
offer="UbuntuServer"
sku="16.04.0-LTS"
version="latest"
vmName="dockerBuild"
nicName="dockerbuildNIC"
privateIPAddress="10.0.0.4"
pipName="dockerBuild-ip"
nsgName="dockerBuild-nsg"
osDiskName="osdisk"

#VM Admin user information
username="dockeruser"
adminPublicKeyPath="/Users/steve/.ssh/id_dockerbuild_rsa.pub" #this is copied to the current directory so it can be accessed in the azureCli Docker Container  
adminPrivateKeyPath="/Users/steve/.ssh/id_dockerbuild_rsa" #only referenced to SSH into newly created VM

#DNS Naming
dnsName="dockerbuildsystem$versionSuffix"
fullDnsName="$dnsName.westus.cloudapp.azure.com"
customDnsName="dockerbuild.harebrained-apps.com"

#where to place the remote Docker Host TLS certs
tlsCertLocation="/Users/steve/tlsCerts"

SCRIPTS_LOCATION=$PWD

#copy the public key to to this directory so the azureCli Docker container has access
echo "Copying admin public key from $adminPublicKeyPath to $SCRIPTS_LOCATION"
#cp $adminPublicKeyPath $SCRIPTS_LOCATION

RUNNING=$(docker inspect --format="{{ .State.Running }}" azureCli 2> /dev/null)

if [ $? -eq 1 ]; then
  	echo "azureCli does not exist. Executing docker run"
	docker run -td --name azureCli -v $SCRIPTS_LOCATION:/config -v $tlsCertLocation:/certs microsoft/azure-cli
	
	docker exec -it azureCli azure login  
fi

if [ "$RUNNING" == "false" ]; then
  	echo "azureCli is not running. Executing docekr start"
      #should START here
	docker start -td --name azureCli
	
	docker exec -it azureCli azure login  
fi

set -e 

docker exec -it azureCli azure account set "$azureAccountName"

# Create Resource Group
docker exec -it azureCli azure group create $rgName $location

# Create storage account
# docker exec -it azureCli azure storage account create $stdStorageAccountName \
#     --resource-group $rgName \
#     --location $location \
# 	--kind Storage \
# 	--sku-name PLRS

# # Create the VNet
# docker exec -it azureCli azure network vnet create --resource-group $rgName \
#     --name $vnetName \
#     --address-prefixes $vnetPrefix \
#     --location $location

# #Create the subnet 
# docker exec -it azureCli azure network vnet subnet create --resource-group $rgName \
#     --vnet-name $vnetName \
#     --name $subnetName \
# 	--address-prefix $subnetPrefix

# # Create a public IP
# docker exec -it azureCli azure network public-ip create --resource-group $rgName \
#     --name $pipName \
#     --location $location \
#     --allocation-method Static \
#     --domain-name-label $dnsName \
# 	--idle-timeout 4 \
# 	--ip-version IPv4

# Get subnet ID
# subnetId="$(docker exec -it azureCli azure network vnet subnet show --resource-group $rgName \
#                 --vnet-name $vnetName \
#                 --name $subnetName|grep Id)"
# subnetId=${subnetId#*/}

# echo "SUBNET ID =$subnetId BUT DO WE NEED IT?? *************************************"

# # Create NIC 
# docker exec -it azureCli azure network nic create --name $nicName \
#     --resource-group $rgName \
#     --location $location \
#     --private-ip-address $privateIPAddress \
# 	--subnet-vnet-name $vnetName \
#     --public-ip-name $pipName \
# 	-k default
# #--subnet-id $subnetId \

# #Create Networg Secutiry group
# docker exec -it azureCli azure network nsg create --resource-group $rgName \
# --name $nsgName \
# --location $location

# #Create Inbound Security Rules
# docker exec -it azureCli azure network nsg rule create --protocol tcp \
# --direction inbound \
# --priority 1000 \
# --destination-port-range 22 \
# --access allow \
# --resource-group $rgName \
# -a $nsgName \
# --name allow-ssh

# docker exec -it azureCli azure network nsg rule create --protocol tcp \
# --direction inbound \
# --priority 1010 \
# --destination-port-range 80 \
# --access allow \
# --resource-group $rgName \
# -a $nsgName \
# --name allow-http

# docker exec -it azureCli azure network nsg rule create --protocol tcp \
# --direction inbound \
# --priority 1020 \
# --destination-port-range 2376 \
# --access allow \
# --resource-group $rgName \
# -a $nsgName \
# --name allow-docker-tls

# #bind the NSG to the NIC
# echo "=> Bind the NSG to the NIC <="
# docker exec -it azureCli azure network nic set --resource-group $rgName \
# -n $nicName \
# -o $nsgName

#Create the VM
# docker exec -it azureCli azure vm create --resource-group $rgName \
#     --name $vmName \
#     --location $location \
#     --vm-size $vmSize \
#     --vnet-subnet-name $subnetName \
#     --nic-name $nicName \
#     --os-type linux \
#     --image-urn $publisher:$offer:$sku:$version \
#     --storage-account-name $stdStorageAccountName \
#     --admin-username $username \
#     --ssh-publickey-file "/config/$(basename $adminPublicKeyPath)" \
# 	--storage-account-container-name vhds \
#     --os-disk-vhd $osDiskName.vhd

docker exec -it azureCli azure vm create --resource-group $rgName \
    --name $vmName \
    --location $location \
    --vm-size $vmSize \
    --vnet-name $vnetName \
    --vnet-address-prefix $vnetPrefix \
    --vnet-subnet-name $subnetName \
    --vnet-subnet-address-prefix $subnetPrefix \
    --nic-name $nicName \
    --os-type linux \
    --image-urn $publisher:$offer:$sku:$version \
    --storage-account-name $stdStorageAccountName \
    --admin-username $username \
    --ssh-publickey-file "/config/$(basename $adminPublicKeyPath)" \
	--storage-account-container-name vhds \
    --os-disk-vhd $osDiskName.vhd

#can use... 
# --generate-ssh-keys \
# places keys in Docker container at:
# /root/.azure/ssh/$vmName-cert.pem

publicIPAddress=$(docker exec -it azureCli azure vm show $rgName $vmName |grep "Public IP address" | awk -F ":" '{print $3}')

echo "Public IP Address=$publicIPAddress"

#this is necessary because of a bug in the Azure VM / Extension deployment
#ssh-add $adminPrivateKeyPath
#		it will fail unless we run an apt-get update in the VM
#ssh $username@$fullDnsName "sudo apt-get update"

#sh create-docker-tls.sh $customDnsName $publicIPAddress $privateIPAddress $tlsCertLocation

echo "=> STOPPING HERE... MORE INFO... <="

echo "CustomDNS:$customDnsName"
echo "PublicIP:$publicIPAddress"
echo "PrivateIP:$privateIPAddress"
echo "TLSCertLocation:$tlsCertLocation"

echo "add-docker-ext.sh $rgName $vmName $tlsCertLocation"