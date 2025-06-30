#!/bin/bash

sudo dnf install -y dnf-plugins-core git
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo dnf -y install packer

