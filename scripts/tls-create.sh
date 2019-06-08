### This script is called from abs_create.tf terraform

## Parameters:

set -e
if [ "$#" -gt 4 ]; then
  USERNAME="$1"
  RECOURCE_GROUP_NAME="$2"
  VM_NAME="$3"
  RSA_KEYS_LOCATION="$4"
  KEY_PAIR_NAME="$5"
else
  echo " => ERROR: You must specify the correct number of parameters (5)<="
  exit 1
fi

echo " => Ensuring config directory exists... <="
mkdir -pv "$RSA_KEYS_LOCATION"

#Please store the private key securly once this is done!
 yes y | ssh-keygen -t rsa -b 2048 -C "$USERNAME@Azure-$RECOURCE_GROUP_NAME-$VM_NAME" -f "$RSA_KEYS_LOCATION/$KEY_PAIR_NAME" -q -N ""
