#!/bin/bash
set -e

exec > >(tee /var/log/user-data.log) 2>&1
echo "user_data started at $(date)"

apt-get update -y
apt-get install -y curl

# Tạo 2GB swap
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# Lấy public IP từ metadata endpoint trước khi cài k3s
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# Cấu hình tls-san trước khi cài — k3s sẽ include public IP trong cert ngay lúc init
mkdir -p /etc/rancher/k3s
cat > /etc/rancher/k3s/config.yaml << EOF
tls-san:
  - ${PUBLIC_IP}
  - ${PRIVATE_IP}
EOF

# Cài k3s
curl -sfL https://get.k3s.io | sh -

sleep 15
systemctl is-active k3s

# Kubeconfig cho user ubuntu — trỏ thẳng đến public IP (cert đã có SAN)
mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
sed -i "s/127.0.0.1/${PUBLIC_IP}/g" /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config
chmod 600 /home/ubuntu/.kube/config

echo 'export KUBECONFIG=~/.kube/config' >> /home/ubuntu/.bashrc

echo "user_data completed at $(date)"
echo "Public IP: ${PUBLIC_IP}"
