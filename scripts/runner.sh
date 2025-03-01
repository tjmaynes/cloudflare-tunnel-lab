#!/usr/bin/env bash

set -e

RUN_TYPE=$1

function throw_if_required_tf_env_var_not_exists() {
  env_var_name=$1
  env_var_value=$2
  if [[ -z "$env_var_value" ]]; then
    echo "Please set environment variable '$env_var_name' before running this script"
    exit 1
  fi

  tf_variable_name=$(echo "$env_var_name" | tr '[:upper:]' '[:lower:]')
  export "TF_VAR_$tf_variable_name"="$env_var_value"
}

function check_requirements() {
  if [[ -z "$(command -v terraform)" ]]; then
    echo "Please install 'terraform' before running this script..."
    exit 1
  elif [[ -z "$(command -v docker)" ]]; then
    echo "Please install 'docker' before running this script..."
    exit 1
  fi

  throw_if_required_tf_env_var_not_exists "LAB_CONFIG_FILE" "$LAB_CONFIG_FILE"
  throw_if_required_tf_env_var_not_exists "CLOUDFLARE_ZONE" "$CLOUDFLARE_ZONE"
  throw_if_required_tf_env_var_not_exists "CLOUDFLARE_EMAIL" "$CLOUDFLARE_EMAIL"
  throw_if_required_tf_env_var_not_exists "CLOUDFLARE_ACCOUNT_ID" "$CLOUDFLARE_ACCOUNT_ID"
  throw_if_required_tf_env_var_not_exists "CLOUDFLARE_ZONE_ID" "$CLOUDFLARE_ZONE_ID"
  throw_if_required_tf_env_var_not_exists "CLOUDFLARE_ZERO_TRUST_TEAM_NAME" "$CLOUDFLARE_ZERO_TRUST_TEAM_NAME"
  throw_if_required_tf_env_var_not_exists "CLOUDFLARE_API_TOKEN" "$CLOUDFLARE_API_TOKEN"
  throw_if_required_tf_env_var_not_exists "CLOUDFLARE_EMAIL_LIST" "$CLOUDFLARE_EMAIL_LIST"

  if [[ -z "$DATA_DIRECTORY" ]]; then
    echo "Please set 'DATA_DIRECTORY' environment variable before running this script..."
    exit 1
  fi
  export CLOUDFLARE_TUNNEL_DATA_DIRECTORY="$DATA_DIRECTORY/cloudflare-tunnel"
  throw_if_required_tf_env_var_not_exists "CLOUDFLARE_TUNNEL_DATA_DIRECTORY" "$CLOUDFLARE_TUNNEL_DATA_DIRECTORY"
}

function main() {
  check_requirements

  [[ ! -d ".terraform" ]] && terraform init

  case "$RUN_TYPE" in
    "apply")
      terraform apply -auto-approve
      ;;
    "plan")
      terraform plan
      ;;
    "destroy")
      terraform destroy
      ;;
    *)
      echo "Arg '$RUN_TYPE' is not valid, please use 'apply' or 'plan'."
      exit 1
      ;;
  esac
}

main
