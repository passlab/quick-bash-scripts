#!/bin/bash
# Script that routes a remote jupyter notebook service over ssh to your localhost
#  1.) Host - The name of the host or the IP address
#  2.) Username - The username you're using to ssh into the host

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

cleanup() {
    printf "${RED}\n\nCLEANING UP JUPYTER REMOTELY!\n\n${NC}"
    rv=$?
    ssh $1@$2 'kill -9 $(cat pid.txt); rm jupyter.log pid.txt'
    ssh $1@$2 'python3 -m notebook stop 8889'
    printf "\n\n${GREEN}JUPYTER EXITED!${NC}\n\n"
    exit $rv
}

cleanupDocker() {
    printf "${RED}\n\nCLEANING UP DOCKER JUPYTER REMOTELY for ${1}@${2} docker ${3}\n\n${NC}"
    rv=$?
    ssh $1@$2 "docker exec ${3} python3 -m notebook stop 8889"
    ssh $1@$2 "docker container stop ${3}"
    printf "\n\n${GREEN}JUPYTER EXITED!${NC}\n\n"
    exit $rv
}

echo -n "USERNAME [root]: "

read USERNAME

echo -n "HOST [192.39.192.2]: "

read HOST

echo -n "Use a docker container? [y/N]: "

read USE_DOCKER_CONTAINER

if [ "$USE_DOCKER_CONTAINER" == "y" ]; then
    
    echo -n "DOCKER NAME [brats]: "

    read DOCKER_NAME

    echo -n "DOCKER IMAGE [nvidia/cuda]: "

    read DOCKER_IMAGE

    trap "cleanupDocker $USERNAME $HOST $DOCKER_NAME" EXIT

    ssh $USERNAME@$HOST "docker run -d -it --rm -p 8889:8889 --name ${DOCKER_NAME} ${DOCKER_IMAGE}"
    OUT=$(ssh $USERNAME@$HOST "docker exec ${DOCKER_NAME} nohup python3 -m notebook --no-browser --port=8889 --ip=0.0.0.0 --allow-root > jupyter.log & echo $!> pid.txt")
    JUPYTER_OUTPUT=$(ssh $USERNAME@$HOST "docker exec ${DOCKER_NAME} python3 -m notebook list")
else
    trap "cleanup $USERNAME $HOST" EXIT

    OUT=$(ssh $USERNAME@$HOST 'nohup python3 -m notebook --no-browser --port=8889 --ip=0.0.0.0 --allow-root > jupyter.log & echo $!> pid.txt')
    JUPYTER_OUTPUT=$(ssh $USERNAME@$HOST 'python3 -m notebook list')
fi

URL=$(echo $JUPYTER_OUTPUT | sed 's/Currently running servers: //g' | sed 's/ ::.*//g')
ssh -fNT -L 8889:localhost:8889 $USERNAME@$HOST

printf "\n\n${GREEN}Jupyter notebook runnig remotely from ${HOST}${NC}\n"
printf "\t${GREEN}Open at:${NC} $URL"

open -a Safari $URL

while "$@"; do 
    sleep 5
done
