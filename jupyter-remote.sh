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
    ssh $1@$2 "python3 -m notebook stop ${4}"
    printf "\n\n${GREEN}JUPYTER EXITED!${NC}\n\n"
    lsof -ti:$3 | xargs kill -9
    exit $rv
}

cleanupDocker() {
    printf "${RED}\n\nCLEANING UP DOCKER JUPYTER REMOTELY for ${1}@${2} docker ${3}\n\n${NC}"
    rv=$?
    ssh $1@$2 "docker exec ${3} python3 -m notebook stop ${4}"
    ssh $1@$2 "docker container stop ${3}"
    lsof -ti:$4 | xargs kill -9
    printf "\n\n${GREEN}JUPYTER EXITED!${NC}\n\n"
    exit $rv
}

DEFAULT_USERNAME=$(whoami)
echo -n "USERNAME [$DEFAULT_USERNAME]: "
read USERNAME
USERNAME="${USERNAME:-${DEFAULT_USERNAME}}"

DEFAULT_HOST="cci-carina"
echo -n "HOST [$DEFAULT_HOST]: "
read HOST
HOST="${HOST:-${DEFAULT_HOST}}"

echo -n "Use a docker container? [y/N]: "

read USE_DOCKER_CONTAINER

if [ "$USE_DOCKER_CONTAINER" == "y" ]; then

    OUT=$(ssh $USERNAME@$HOST "docker image ls | grep -v \"<none>\" | sed 's/ .*//' | sed '1d'")
    printf "\n${GREEN}Current docker images:\n\n${OUT}\n${NC}"
    DEFAULT_DOCKER_IMAGE=$(printf $OUT | head -n 1)
    echo -n "DOCKER IMAGE [$DEFAULT_DOCKER_IMAGE]: "
    read DOCKER_IMAGE
    DOCKER_IMAGE="${DOCKER_IMAGE:-${DEFAULT_DOCKER_IMAGE}}"

    DEFAULT_DOCKER_NAME=$DOCKER_IMAGE
    echo -n "DOCKER NAME [$DEFAULT_DOCKER_NAME]: "
    read DOCKER_NAME
    DOCKER_NAME="${DOCKER_NAME:-${DEFAULT_DOCKER_NAME}}"

    DEFAULT_PORT="8889"
    echo -n "PORT [$DEFAULT_PORT]: "
    read PORT
    PORT="${PORT:-${DEFAULT_PORT}}"

    # Get Directory
    OUT=$(ssh $USERNAME@$HOST "find . -maxdepth 1 -type d | grep -v '\.\/\.' | sed 's/\.\///g' | sed 's/\.//g' | while read line; do echo \$(pwd)/\$line; done")
    printf "\n${GREEN}${USERNAME}-${HOST} directories:\n\n${OUT}\n${NC}"
    DEFAULT_DIR=$(printf $OUT | head -n 1)
    echo -n "Enter Directory [$DEFAULT_DIR]: "
    read DIR
    DIR="${DIR:-${DEFAULT_DIR}}"

    DOCKER_USER=$(ssh $USERNAME@$HOST "docker inspect --format "{{.Config.User}}" $DOCKER_IMAGE")

    trap "cleanupDocker $USERNAME $HOST $DOCKER_NAME $PORT" EXIT

    ssh $USERNAME@$HOST "docker run -d -it --rm -u 0 --gpus all -p ${PORT}:${PORT} --name ${DOCKER_NAME} --security-opt apparmor=unconfined -v ${DIR}:/home/${DOCKER_USER}/development ${DOCKER_IMAGE}"
    OUT=$(ssh $USERNAME@$HOST "docker exec ${DOCKER_NAME} nohup python3 -m notebook --no-browser --port=${PORT} --ip=0.0.0.0 --allow-root > jupyter.log & echo $!> pid.txt")
    JUPYTER_OUTPUT=$(ssh $USERNAME@$HOST "docker exec ${DOCKER_NAME} python3 -m notebook list")
else

    DEFAULT_PORT="8889"
    echo -n "PORT [$DEFAULT_PORT]: "
    read PORT
    PORT="${PORT:-${DEFAULT_PORT}}"

    trap "cleanup $USERNAME $HOST" EXIT

    OUT=$(ssh $USERNAME@$HOST "nohup python3 -m notebook --no-browser --port=${PORT} --ip=0.0.0.0 --allow-root > jupyter.log & echo $!> pid.txt")
    JUPYTER_OUTPUT=$(ssh $USERNAME@$HOST 'python3 -m notebook list')
fi

URL=$(echo $JUPYTER_OUTPUT | sed 's/Currently running servers: //g' | sed 's/ ::.*//g')
ssh -fNT -L $PORT:localhost:$PORT $USERNAME@$HOST

printf "\n\n${GREEN}Jupyter notebook runnig remotely from ${HOST}${NC}\n"
printf "\t${GREEN}Open at:${NC} $URL"

open -a Safari $URL

while "$@"; do 
    sleep 5
done
