#!/bin/bash
set -xe
if [ "$#" -gt 2 ]; then
  rgName="$1"
  vmName="$2"
  CERT_LOCATION="$3"
else
  echo " => ERROR: You must specify the resource group name, the VM name, and the location of the TLS certs ex. ./create-docker-tls.sh dockerBuild dockerBuildVM ~/tlsCerts  <="
  exit 1
fi

SCRIPTS_LOCATION=$PWD

cd $CERT_LOCATION
# Convert the ca, cert and key to base 64 for transfer up to Azure 
echo "=> Convert CA, server-cert, and key to base 64 and stick in ENV vars <="
CA_BASE64="$(cat ca.pem | base64)"
CERT_BASE64="$(cat server-cert.pem | base64)"
KEY_BASE64="$(cat server-key.pem | base64)"

# Get rid of any old isntances of the .json config files
rm -f pub.json prot.json

echo "=> Create the config .json files <="
echo "{
    \"docker\":{
        \"port\": \"2376\"
    }
}" > pub.json

echo "{
    \"certs\": {
        \"ca\": \"$CA_BASE64\",
        \"cert\": \"$CERT_BASE64\",
        \"key\": \"$KEY_BASE64\"
    }
}" > prot.json

echo "=> Kill the CA, CERT, and KEY env vars <="
# Kill the environment vars since they contain secrets
CA_BASE64="nothingtoseehere"
unset CA_BASE64
CERT_BASE64="nothingtoseehere"
unset CERT_BASE64
KEY_BASE64="nothingtoseehere"
unset KEY_BASE64

echo "=> Install Docker extensions in VM <="
docker exec -it azureCli azure vm extension set $rgName $vmName DockerExtension Microsoft.Azure.Extensions '1.0' --auto-upgrade-minor-version --public-config-path /config/$CERT_LOCATION/pub.json --private-config-path /config/$CERT_LOCATION/prot.json

# Remove the .json files... no longer needed AND prot.json contains secrets
rm -v prot.json pub.json