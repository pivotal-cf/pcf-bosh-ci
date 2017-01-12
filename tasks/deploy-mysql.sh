#!/usr/bin/env bash

set -e

eval "$(pcf-bosh-ci/scripts/director-environment bosh-vars-store/*-bosh-vars-store.yml terraform-state/metadata)"

cf_vars_store_json=$(pcf-bosh-ci/scripts/yaml2json cf-vars-store/*-cf-vars-store.yml)

cat <<MYSQLVARS > p-mysql-vars-template.yml
---
################
# MySQL config #
################

cf_mysql_external_host: p-mysql.$(jq -r .sys_domain terraform-state/metadata)

###########################
# MySQL Monitoring config #
###########################

mysql_monitoring_recipient_email: not-a-real-email@example.com
mysql_monitoring_cluster_identifier: "p-mysql-$(cat terraform-state/name)"

########################
# Cloud Foundry config #
########################

cf_api_url: https://api.$(jq -r .sys_domain terraform-state/metadata)
cf_uaa_admin_client_secret: $(echo "$cf_vars_store_json" | jq -r .uaa_admin_client_secret)
cf_admin_username: admin
cf_admin_password: $(echo "$cf_vars_store_json" | jq -r .uaa_scim_users_admin_password)
cf_app_domains: [$(jq -r .apps_domain terraform-state/metadata)]
cf_sys_domain: $(jq -r .sys_domain terraform-state/metadata)
cf_skip_ssl_validation: true
cf_nats:
  password: $(echo "$cf_vars_store_json" | jq -r .nats_password)
  machines: ((nats_ips))
  user: nats
  port: 4222
MYSQLVARS

bosh -n interpolate p-mysql-vars-template.yml \
    -l pcf-bosh-ci/vars-files/gcp-nats-ips.yml > p-mysql-vars.yml

cp mysql-vars-store/*-mysql-vars-store.yml new-mysql-vars-store/mysql-vars-store.yml

bosh -n deploy p-mysql-deployment/p-mysql-deployment.yml \
  --deployment p-mysql \
  --ops-file pcf-bosh-ci/ops-files/p-mysql-overrides.yml \
  --vars-file p-mysql-vars.yml \
  --vars-store new-mysql-vars-store/mysql-vars-store.yml
