#!/bin/sh
PROJECT_NAME=`cat .project-name`
ansible-container --debug --project-name ${PROJECT_NAME} run --roles-path ./roles/ -- -vvv
