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

# Extract lambda_version if it exists to match your main.tf
LAMBDA_VERSION="latest"

while IFS= read -r line || [ -n "$line" ]; do
  if [ -z "$line" ] || [[ ${line:0:1} == "#" ]]; then
    continue
  fi
  key="${line%%=*}"
  value="${line#*=}"
  value="${value%\"}"
  value="${value#\"}"
  echo "${key} = \"${value}\"" >> "$TFVARS_FILE"
  
  if [ "$key" == "lambda_version" ]; then
    LAMBDA_VERSION="$value"
  fi
done < "$ENV_FILE"

echo "Created $TFVARS_FILE"

echo "Building Lambda package..."
DIST_DIR="../dist"
LAMBDA_DIR="../lambda"
PACKAGE_ZIP="telegram_lambda_${LAMBDA_VERSION}.zip"
REQ_HASH_FILE="$DIST_DIR/req.hash"

mkdir -p "$DIST_DIR"

# Calculate the hash of requirements.txt (macOS compatible)
CURRENT_REQ_HASH=$(shasum "$LAMBDA_DIR/requirements.txt" | awk '{print $1}')

# Check if dependencies need to be downloaded
if [ -f "$REQ_HASH_FILE" ] && [ "$(cat "$REQ_HASH_FILE")" == "$CURRENT_REQ_HASH" ] && [ -d "$DIST_DIR/package" ]; then
  echo "Dependencies (requirements.txt) unchanged. Skipping pip install..."
else
  echo "Dependencies changed or missing. Installing via pip..."
  rm -rf "$DIST_DIR/package"
  mkdir -p "$DIST_DIR/package"
  pip install --target "$DIST_DIR/package" -r "$LAMBDA_DIR/requirements.txt" \
      --platform manylinux2014_x86_64 \
      --only-binary=:all: \
      --implementation cp \
      --python-version 3.12
  
  # Save the new hash
  echo "$CURRENT_REQ_HASH" > "$REQ_HASH_FILE"
fi

# Copy the latest lambda code (this happens every build)
cp "$LAMBDA_DIR/lambda_function.py" "$DIST_DIR/package/"

# Zip everything up, removing the old zip first
rm -f "$DIST_DIR/$PACKAGE_ZIP"
cd "$DIST_DIR/package"
zip -rq "../$PACKAGE_ZIP" .
cd ../../terraform

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