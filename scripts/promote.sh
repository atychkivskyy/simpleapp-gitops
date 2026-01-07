#!/bin/bash

set -e

SOURCE_ENV=$1  # e.g., dev
TARGET_ENV=$2  # e.g., staging

if [ -z "$SOURCE_ENV" ] || [ -z "$TARGET_ENV" ]; then
    echo "Usage: ./promote.sh <source-env> <target-env>"
    echo "Example: ./promote.sh dev staging"
    exit 1
fi

# Extract current image tag from source environment
IMAGE_TAG=$(grep "newTag:" k8s/overlays/$SOURCE_ENV/kustomization.yaml | awk '{print $2}')
IMAGE_NAME=$(grep "newName:" k8s/overlays/$SOURCE_ENV/kustomization.yaml | awk '{print $2}')

echo "Promoting $IMAGE_NAME:$IMAGE_TAG from $SOURCE_ENV to $TARGET_ENV"

# Update target environment
cd k8s/overlays/$TARGET_ENV
kustomize edit set image simpleapp-api=$IMAGE_NAME:$IMAGE_TAG

cd ../../..
git add .
git commit -m "promote: simpleapp-api $IMAGE_TAG from $SOURCE_ENV to $TARGET_ENV"
git push

echo "Promotion complete!"