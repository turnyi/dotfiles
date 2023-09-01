#!/bin/bash

source .env

# sudo ansible-playbook playbooks/linux/setup-linux.yml

export DOPPLER_TOKEN=$DOPPLER_TOKEN

doppler secrets substitute config/.config/gh/hosts.template.yml --project ansible --config dev >config/.config/gh/hosts.yml

cd config && bash install.sh cd -
