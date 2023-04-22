#!/bin/bash

source .env

# sudo ansible-playbook playbooks/linux/setup-linux.yml

export DOPPLER_TOKEN=$DOPPLER_TOKEN

doppler secrets substitute playbooks/github/.env.template --project ansible --config dev > playbooks/github/.env

sudo ansible-playbook playbooks/github/git-auth.yml