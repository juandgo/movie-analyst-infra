#!/bin/bash
# Bastion bootstrap: only installs the Ansible controller tooling.
# Everything else (UI, API, DB schema, CloudWatch agent) is configured by Ansible FROM the bastion.
set -euxo pipefail
dnf install -y ansible-core git python3-pip python3-boto3 python3-botocore
ansible-galaxy collection install amazon.aws community.mysql -p /usr/share/ansible/collections
