#!/bin/bash
set -euo pipefail

# --- Swap 2GB ---
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# --- Cài k3s ---
curl -sfL https://get.k3s.io | sh -

# --- Kubeconfig cho user ubuntu ---
mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
sed -i "s/127.0.0.1/$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)/g" \
    /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config
chmod 600 /home/ubuntu/.kube/config
