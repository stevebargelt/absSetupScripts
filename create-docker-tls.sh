#!/bin/bash
#  Example usage:
#	 ./create-docker-tls.sh myhost.docker.com PUBLIC-IP PRIVATE-IP FOLDER
#	 ./create-docker-tls.sh myhost.docker.com 40.78.31.164 10.0.0.4 ~/tlsCerts

set -xe
STR=4096
if [ "$#" -gt 4 ]; then
  DOCKER_HOST="$1"
  AZURE_DNS="$2"
  PUBLIC_IP="$3"
  PRIVATE_IP="$4"
  CERT_LOCATION="$5"
else
  echo " => ERROR: You must specify the docker FQDN, the Public IP, the Private IP, and where to create the certs as the arguments to this script! ex. ./create-docker-tls.sh myhost.docker.com 52.78.31.13 10.0.0.4 ~/tlsCerts  <="
  exit 1
fi

ORIGINAL_DIR=$PWD

echo " => Ensuring config directory exists..."
mkdir -p "$CERT_LOCATION"
cd "$CERT_LOCATION"

echo " => Generating CA key"
openssl genrsa -aes256 \
  -out ca-key.pem $STR

echo " => Generating CA certificate"
openssl req \
  -new \
  -key ca-key.pem \
  -x509 \
  -sha256 \
  -days 365 \
  -subj "/CN=$DOCKER_HOST" \
  -out ca.pem

echo " => Generating server key"
openssl genrsa \
  -out server-key.pem $STR

echo " => Generating server CSR"
openssl req \
  -subj "/CN=$DOCKER_HOST" \
  -new \
  -sha256 \
  -key server-key.pem \
  -out server.csr

echo "subjectAltName=IP:$PRIVATE_IP,IP:$PUBLIC_IP,IP:127.0.0.1,DNS:$DOCKER_HOST,DNS:$AZURE_DNS" > extfileServer.cnf

echo " => Creating server cert..."
openssl x509 \
  -req \
  -days 365 \
  -sha256 \
  -in server.csr \
  -CA ca.pem \
  -CAcreateserial \
  -CAkey ca-key.pem \
  -out server-cert.pem \
  -extfile extfileServer.cnf

echo " => Generating client key"
openssl genrsa \
  -out key.pem $STR

echo " => Generating client CSR"
openssl req \
  -subj "/CN=client" \
  -new \
  -key key.pem \
  -out client.csr

echo " => Creating extended key usage"
echo extendedKeyUsage = "clientAuth" > extfile.cnf

echo " => Creating client cert"
openssl x509 \
  -req \
  -days 365 \
  -sha256 \
  -in client.csr \
  -CA ca.pem \
  -CAkey ca-key.pem \
  -CAcreateserial \
  -out cert.pem \
  -extfile extfile.cnf

echo " => Removing certificate signing requests"
rm -v client.csr server.csr

echo " => Removing extfile.cnf"
rm -v extfile.cnf
rm -v extfileServer.cnf

echo " => Setting permissions on keys: read only by current user"
chmod -v 0400 ca-key.pem key.pem server-key.pem

echo " => Setting permissions on certificates: No write"
chmod -v 0444 ca.pem server-cert.pem cert.pem

cd $ORIGINAL_DIR