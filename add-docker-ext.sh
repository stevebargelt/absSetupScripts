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

CA_BASE64="$(cat ca.pem | base64)"
CERT_BASE64="$(cat server-cert.pem | base64)"
KEY_BASE64="$(cat server-key.pem | base64)"

rm -f pub.json prot.json

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


docker exec -it azureCli azure vm extension set $rgName $vmName DockerExtension Microsoft.Azure.Extensions '1.0' --auto-upgrade-minor-version --public-config-path /config/$CERT_LOCATION/pub.json --private-config-path /config/$CERT_LOCATION/prot.json

#rm -v prot.json pub.json