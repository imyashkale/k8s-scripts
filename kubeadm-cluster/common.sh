#!/bin/bash
#
# Common setup for all servers (Control Plane and Nodes)
# This script is intended for setting up a Kubernetes cluster on servers, both Control Plane and Nodes, using CRI-O as the container runtime.

# Set options for the script
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error.
# -x: Print each command to the standard error output before executing it.
# -o pipefail: Return the exit status of the last (rightmost) command in the pipeline.
set -euxo pipefail

# Variable Declaration
KUBERNETES_VERSION="1.28.1-00"

# Disable swap
# The 'swapoff -a' command is used to deactivate all swap devices on the system.
# This is a critical step in Kubernetes setup, as swap can interfere with container performance.
# Swapping is the process of moving data between RAM and swap space on disk, and it can cause performance issues in a containerized environment.
# Disabling swap ensures that the system relies solely on physical memory, improving container performance and stability.
# The '-a' option specifies that all swap devices should be turned off.
sudo swapoff -a

# Keep the swap off during reboot by adding a cron job
# This command appends a new cron job to the user's crontab using the '@reboot' directive.
# The cron job executes the command '/sbin/swapoff -a' at system reboot, ensuring that swap remains disabled.
# 'crontab -l 2>/dev/null' lists the user's crontab, and '2>/dev/null' suppresses any error output if the crontab is empty or does not exist.
# The new cron job is added with 'echo "@reboot /sbin/swapoff -a"', and the entire crontab is replaced with the updated content.
# If there was an issue updating the crontab, the '|| true' ensures that the script does not exit on error, preventing interruption of the setup process.
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab - || true

# Update package lists
sudo apt-get update -y

# Install CRI-O Runtime
OS="xUbuntu_22.04"
VERSION="1.28"

# Create the .conf file to load the modules at bootup
# This command uses a 'here document' to create a configuration file '/etc/modules-load.d/crio.conf'.
# The file contains two kernel modules, 'overlay' and 'br_netfilter', each on a new line.
# These modules are required for the proper functioning of CRI-O, the container runtime used in the Kubernetes setup.
# Loading these modules ensures that the necessary kernel features are available during system boot.
cat <<EOF | sudo tee /etc/modules-load.d/crio.conf
overlay
br_netfilter
EOF

# Load required kernel modules
# The 'modprobe' command is used to add or remove kernel modules from the Linux kernel.
# In this context, 'modprobe overlay' and 'modprobe br_netfilter' are executed to load the 'overlay' and 'br_netfilter' kernel modules, respectively.
# These modules are essential for the proper functioning of CRI-O, the container runtime used in the Kubernetes setup.
# Loading these modules provides necessary kernel features required for containerization.
sudo modprobe overlay
sudo modprobe br_netfilter

# Set up sysctl parameters to persist across reboots
# This command uses a here document to define the content of the configuration file '/etc/sysctl.d/99-kubernetes-cri.conf'.
# The file contains three sysctl parameters, each on a separate line, which are crucial for Kubernetes and CRI-O setup.
# These parameters control network bridge behavior and IPv4 forwarding, ensuring the proper functioning of the containerized environment.
# Writing these parameters to '/etc/sysctl.d/99-kubernetes-cri.conf' ensures their persistence across system reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF


# Apply sysctl parameters
sudo sysctl --system

# Configure apt sources for CRI-O installation
cat <<EOF | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /
EOF

cat <<EOF | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.list
deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/ /
EOF

# Import GPG keys for the apt repositories
curl -L https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$VERSION/$OS/Release.key | sudo apt-key --keyring /etc/apt/trusted.gpg.d/libcontainers.gpg add -
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | sudo apt-key --keyring /etc/apt/trusted.gpg.d/libcontainers.gpg add -

# Update apt and install CRI-O
sudo apt-get update
sudo apt-get install cri-o cri-o-runc -y

# Start and enable CRI-O service
sudo systemctl daemon-reload
sudo systemctl enable crio --now

echo "CRI runtime installed successfully"

# Install Kubernetes tools
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl

# Add Kubernetes apt repository and keyring
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://dl.k8s.io/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update apt and install Kubernetes tools
sudo apt-get update -y
sudo apt-get install -y kubelet="$KUBERNETES_VERSION" kubectl="$KUBERNETES_VERSION" kubeadm="$KUBERNETES_VERSION"
sudo apt-get update -y
sudo apt-get install -y jq

# Check if the 'eth0' network interface exists
if ip link show eth0 > /dev/null 2>&1; then
    # 'eth0' exists, so we retrieve its IP address.
    # The 'ip --json addr show eth0' command outputs details of the 'eth0' interface in JSON format.
    # 'jq' is used to parse the JSON and extract the IPv4 ('inet') address.
    local_ip="$(ip --json addr show eth0 | jq -r '.[0].addr_info[] | select(.family == "inet") | .local')"

# If 'eth0' does not exist, check for the 'ens5' network interface
elif ip link show ens5 > /dev/null 2>&1; then
    # 'ens5' exists, so we retrieve its IP address with the same method as above.
    local_ip="$(ip --json addr show ens5 | jq -r '.[0].addr_info[] | select(.family == "inet") | .local')"

# If neither 'eth0' nor 'ens5' are found, output an error message and exit the script.
else
    echo "Neither eth0 nor ens5 interface found."
    exit 1
fi

# Display the retrieved local IP address
echo "Local IP: $local_ip"

# Configure kubelet to use the local IP address
cat > /etc/default/kubelet << EOF
KUBELET_EXTRA_ARGS=--node-ip=$local_ip
EOF

echo "Kubernetes tools installed successfully"
