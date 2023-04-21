#!/bin/bash

source .env

echo $DOPPLER_TOKEN

export DOPPLER_TOKEN=$DOPPLER_TOKEN
doppler secrets substitute playbooks/github/.env.template --project ansible --config dev > playbooks/github/.env