#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

DEFAULT_USERNAME=$(whoami)
echo -n "USERNAME [$DEFAULT_USERNAME]: "
read USERNAME
USERNAME="${USERNAME:-${DEFAULT_USERNAME}}"

DEFAULT_HOST="cci-carina"
echo -n "HOST [$DEFAULT_HOST]: "
read HOST
HOST="${HOST:-${DEFAULT_HOST}}"

OUT=$(ssh $USERNAME@$HOST "locate -b \"\Dockerfile\" | sed 's/Dockerfile//g'")
printf "\n${GREEN}${USERNAME}-${HOST} directories:\n\n${OUT}\n${NC}"
DEFAULT_DIR=$(printf $OUT | head -n 1)
echo -n "Enter Directory for Dockerfile [$DEFAULT_DIR]: "
read DIR
DIR="${DIR:-${DEFAULT_DIR}}"

DEFAULT_TAG="$USERNAME-docker"
echo -n "What is the docker tag? [$DEFAULT_TAG]: "
read TAG
TAG="${TAG:-${DEFAULT_TAG}}"
TAG=$(echo $TAG | tr '[:upper:]' '[:lower:]')

OUT=$(ssh $USERNAME@$HOST "cd $DIR; docker build -t $TAG .")

printf "\n\n${GREEN}Docker image ${TAG} successfully create in ${HOST}${NC}\n"

