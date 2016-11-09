#!/bin/bash
rm -rf keys
rm -rf certs

printf 'While you wait... EDIT KNOWN HOSTS'
printf 'code ~/.ssh/known_hosts'

sh abs_create.sh

ssh-add ./keys/dockerbuild/id_dockerbuild_rsa

ssh -o StrictHostKeyChecking=no "dockeruser@dockerbuildsystem.westus.cloudapp.azure.com" -i "./keys/dockerbuild/id_dockerbuild_rsa" "git clone https://github.com/stevebargelt/jenkinsDocker" 

cd certs/dockerBuild

# docker --tlsverify --tlscacert=ca.pem --tlscert=cert.pem --tlskey=key.pem -H=tcp://dockerbuildsystem.westus.cloudapp.azure.com:2376 version

# docker-compose build --tlsverify --tlscacert=ca.pem --tlscert=cert.pem --tlskey=key.pem -H=tcp://dockerbuildsystem.westus.cloudapp.azure.com:2376 -f ~/code/jenkinsDocker/docker-compose.yml -p jenkins

#docker-compose -p jenkins build nginx data master slave slavedotnet

#docker exec jenkins_master_1 cat /var/jenkins_home/secrets/initialAdminPassword

