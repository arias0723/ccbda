#!/usr/bin/env bash
# Simple deploy wrapper: converts .env -> terraform.tfvars and runs terraform
set -euo pipefail
cd "$(dirname "$0")"

ENV_FILE=".env"
TFVARS_FILE="terraform.tfvars"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing $ENV_FILE. Copy .env.example -> .env and edit values."
  exit 1
fi

echo "# generated from $ENV_FILE - do not commit" > "$TFVARS_FILE"

while IFS= read -r line || [ -n "$line" ]; do
  # skip empty lines and comments
  if [ -z "$line" ] || [[ ${line:0:1} == "#" ]]; then
    continue
  fi
  # split key=value
  key="${line%%=*}"
  value="${line#*=}"
  # strip surrounding quotes if present
  value="${value%\"}"
  value="${value#\"}"
  echo "${key} = \"${value}\"" >> "$TFVARS_FILE"
done < "$ENV_FILE"

echo "Created $TFVARS_FILE"
echo "Initializing terraform..."
terraform init

echo "Planning..."
terraform plan -var-file="$TFVARS_FILE"

echo "Apply? (y/N)"
read -r answer
if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
  terraform apply -var-file="$TFVARS_FILE"
else
  echo "Aborted apply."
fi