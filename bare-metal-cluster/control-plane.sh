#!/bin/bash
#
# Setup script for Control Plane (Master) in a Kubernetes cluster.

# Exit immediately if a command exits with a non-zero status, print commands and their arguments, and treat unset variables as an error.
set -euxo pipefail

# Flag to determine if public IP access to the API server is needed.
PUBLIC_IP_ACCESS="true"

# Determine the hostname of the current machine.
NODENAME=$(hostname -s)

# Define the CIDR block for pod IPs.
POD_CIDR="192.168.0.0/16"

# Pull the required images using kubeadm.
sudo kubeadm config images pull

# Initialize the Kubernetes cluster.
if [[ "$PUBLIC_IP_ACCESS" == "false" ]]; then
    # Use private IP for the Kubernetes API server.
    MASTER_PRIVATE_IP=$(ip addr show eth0 | awk '/inet / {print $2}' | cut -d/ -f1)
    sudo kubeadm init --apiserver-advertise-address="$MASTER_PRIVATE_IP" \
                      --apiserver-cert-extra-sans="$MASTER_PRIVATE_IP" \
                      --pod-network-cidr="$POD_CIDR" \
                      --node-name "$NODENAME" \
                      --ignore-preflight-errors Swap
elif [[ "$PUBLIC_IP_ACCESS" == "true" ]]; then
    # Use public IP for the Kubernetes API server.
    MASTER_PUBLIC_IP=$(curl ifconfig.me && echo "")
    sudo kubeadm init --control-plane-endpoint="$MASTER_PUBLIC_IP" \
                      --apiserver-cert-extra-sans="$MASTER_PUBLIC_IP" \
                      --pod-network-cidr="$POD_CIDR" \
                      --node-name "$NODENAME" \
                      --ignore-preflight-errors Swap
else
    echo "Error: Invalid value for MASTER_PUBLIC_IP: $PUBLIC_IP_ACCESS"
    exit 1
fi

# Configure kubeconfig for kubectl.
mkdir -p "$HOME"/.kube
sudo cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config

# Install Calico Network Plugin.
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml

echo "Control Plane Boot Up Completed"