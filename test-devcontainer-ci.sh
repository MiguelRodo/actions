#!/bin/bash
mkdir -p .devcontainer
cat << 'JSON' > .devcontainer/devcontainer.json
{
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu"
}
JSON

docker pull mcr.microsoft.com/devcontainers/base:ubuntu
