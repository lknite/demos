#!/bin/bash

##
# - on the each node

echo "enter sudo passwd:"
sudo ls

# install docker, this installs containerd (todo, install containerd only)
sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf -y install containerd.io

# enable br_netfilter kernel module
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# enable wireguard module (if using wireguard)
cat <<EOF | sudo tee /etc/modules-load.d/wireguard.conf
wireguard
ip_tables
EOF

# load the br_netfilter before continuing (needed for next step)
sudo modprobe overlay
sudo modprobe br_netfilter

# create conf file to add additional bridge values to sysctl
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

# load additional sysctl configs
sudo sysctl --system

#
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

#
sudo yum -y update

# Set SELinux in permissive mode (effectively disabling it)
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
#sudo yum install -y kubelet-1.25.3 kubeadm-1.25.3 kubectl-1.25.3 --disableexcludes=kubernetes

sudo systemctl enable --now kubelet

# Disable firewall (or enable the needed ports)
sudo systemctl disable firewalld
sudo systemctl stop firewalld

# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# enable ip_forward via sysctl config file
cat <<EOF | sudo tee /etc/sysctl.conf
net.ipv4.ip_forward = 1
EOF

# reload sysctl
sudo sysctl -p

# [configure containerd]
# make a copy of the default containerd configuration
containerd config default | sudo tee /etc/containerd/config.toml
# set to use systemd
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
# adjust pause image to what's actually installed
PAUSE_IMAGE=$(kubeadm config images list | grep pause)
sudo -E sed -i "s,sandbox_image = .*,sandbox_image = \"$PAUSE_IMAGE\",g" /etc/containerd/config.toml

# restart the containerd service
sudo systemctl enable containerd
sudo systemctl restart containerd

# Install tc, required but not installed by default
sudo yum -y install tc

## Install jq & cifs-utils, used by CIFS Flexvolume Plugin
#sudo yum -y install jq cifs-utils

## Install CIFS Flexvolume Plugin
#VOLUME_PLUGIN_DIR="/usr/libexec/kubernetes/kubelet-plugins/volume/exec"
#sudo mkdir -p "$VOLUME_PLUGIN_DIR/fstab~cifs"
#sudo curl -L -O https://raw.githubusercontent.com/fstab/cifs/master/cifs
#sudo chmod 755 cifs
#sudo mv cifs "$VOLUME_PLUGIN_DIR/fstab~cifs"

## Install the following system packages
#sudo yum install -y lsscsi iscsi-initiator-utils sg3_utils device-mapper-multipath
## Enable multipathing
#sudo mpathconf --enable --with_multipathd y

## Ensure that iscsid and multipathd are running
#sudo systemctl enable iscsid multipathd
#sudo systemctl start iscsid multipathd

## Start and enable iscsi
#sudo systemctl enable iscsi
#sudo systemctl start iscsi

# Install xcp-ng guest tools, enable & start service
sudo yum -y install epel-release
sudo yum -y install xe-guest-utilities-latest
sudo systemctl enable xe-linux-distribution
sudo systemctl start xe-linux-distribution

# Seems to be required lately, to get around errors:
# - Failed to allocate directory watch: Too many open files
sysctl fs.inotify.max_user_instances=512
