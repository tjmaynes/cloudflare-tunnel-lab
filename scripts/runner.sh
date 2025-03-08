#!/usr/bin/env bash

RUN_TYPE=$1

function ensure_tf_env_var_exists() {
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

  ensure_tf_env_var_exists "LAB_CONFIG_FILE" "$LAB_CONFIG_FILE"

  DATA_DIRECTORY="$(pwd)/tmp"
  ensure_tf_env_var_exists "DATA_DIRECTORY" "$DATA_DIRECTORY"
  [[ ! -d "$DATA_DIRECTORY/cloudflare-tunnel/creds" ]] && mkdir -p "$DATA_DIRECTORY/cloudflare-tunnel/creds"
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
