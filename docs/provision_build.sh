#!/bin/sh

set -e

GREEN="$(tput setaf 2)"
RESET="$(tput sgr0)"

PROJECT_NAME=`cat .project-name`

# echo "${GREEN} Building conductor image ${RESET}"
# ansible-container build

echo "${GREEN} Building ${PROJECT_NAME} ${RESET}"
ansible-container --debug --project-name ${PROJECT_NAME} build --roles-path ./roles/ -- -vvv
