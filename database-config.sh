#!/usr/bin/env bash

export DB_USERNAME=multicloud
export DB_PASSWORD=multicloud 
export DB_DATABASE=multicloud
for t in username password database
do
    k="DB_${t^^}"
    v="${!k}"
    sops set config.yaml '["common"]["database"]["settings"]["credentials"]["'"$t"'"]' "\"$v\""
done
