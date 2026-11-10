#!/bin/bash
set -euxo pipefail

exec > >(tee -a /var/log/user-data.log) 2>&1
echo "=== Starting Number Reverser node bootstrap at $(date) ==="

# 1. Update system packages
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl apt-transport-https ca-certificates iptables

# 2. Install k3s lightweight Kubernetes distribution
# Configured with write-kubeconfig-mode 644 for SSM/local access
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --tls-san $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo 'localhost') --write-kubeconfig-mode 644" sh -

# 3. Wait for Kubernetes API & node readiness
echo "Waiting for k3s node to be ready..."
until /usr/local/bin/kubectl get nodes | grep -q "Ready"; do
  sleep 5
done

# 4. Install Kyverno Policy Engine (v1.12.5)
echo "Installing Kyverno policy engine..."
/usr/local/bin/kubectl create -f https://github.com/kyverno/kyverno/releases/download/v1.12.5/install.yaml || true

# 5. Export kubeconfig for ubuntu user
mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube
chmod 600 /home/ubuntu/.kube/config

echo "=== Node bootstrap completed successfully at $(date) ==="

