python = python2.7
SHELL=/bin/bash
PROJECT_NAME=$(shell cat $(PWD)/.project-name)

all: p-env/bin/pip clean_build

clean_build: clean initialize build

build:  p-env/bin/ansible-container
	@echo p-env/bin/ansible-container --debug --project-name $(PROJECT_NAME) build --roles-path ./roles/ -- -vvv
	@p-env/bin/ansible-container --debug --project-name $(PROJECT_NAME) build --roles-path ./roles/ -- -vvv
	@echo "Application docker image was build"

run:  p-env/bin/ansible-container
	@echo p-env/bin/ansible-container --debug --project-name $(PROJECT_NAME) run --roles-path ./roles/ -- -vvv
	@p-env/bin/ansible-container --debug --project-name $(PROJECT_NAME) run --roles-path ./roles/ -- -vvv
	@echo "Application environment was started"

stop:   p-env/bin/ansible-container
	@echo p-env/bin/ansible-container --debug --project-name $(PROJECT_NAME) stop
	@p-env/bin/ansible-container --debug --project-name $(PROJECT_NAME) stop
	@echo "Application environment was stopped"

p-env/bin/pip: p-env/bin/python
	p-env/bin/pip install -r requirements.txt

p-env/bin/python:
	virtualenv -p $(python) --no-site-packages p-env
	@touch $@

p-env/bin/ansible-container: p-env/bin/pip
	@touch $@

clean:
	@rm -rf .Python p-env roles

initialize:
	@init.sh

.PHONY: all clean initialize build run stop

