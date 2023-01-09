#!/bin/bash
# - on the loadbalancer for the control planes

export K8S_NAME=demo
export K8S_SUBNET=10.0.10

# Setup haproxy on a server
# 1. configure selinux (or just disable), haproxy will not work w/ default selinux config
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# 2. sudo yum -y install haproxy
sudo yum -y install haproxy

# 3. sudo firewall-cmd --permanent --add-port=6443/tcp; sudo firewall-cmd --reload
sudo firewall-cmd --permanent --add-port=6443/tcp; sudo firewall-cmd --reload

#(4-5 only needed if loadbalancer also acts as gateway
# 4. append 'net.ipv4.ip_forward = 1' to /etc/sysctl.conf
cat <<EOF | sudo tee /etc/sysctl.conf
net.ipv4.ip_forward = 1
EOF

# 5. install 'baseos' so that we can use the 'route' command
sudo yum -y install net-tools

# 6. append to /etc/rc.local
sudo chmod 755 /etc/rc.d/rc.local
sudo route add default gw 10.0.0.1 metric 25
sudo route add -net 10.0.0.0 netmask 255.255.255.0 gw 10.0.0.1 metric 25

# 7. modify /etc/haproxy/haproxy.cfg & comment out the line containing 'option forwardfor'
sudo sed -i 's/option forwardfor/#option forwardfor/g' /etc/haproxy/haproxy.cfg

# 8. append to /etc/haproxy/haproxy.cfg
cat <<EOF | sudo tee -a /etc/haproxy/haproxy.cfg

frontend kubernetes-frontend
    bind ${K8S_SUBNET}.1:6443
    mode tcp
    option tcplog
    default_backend kubernetes-backend

backend kubernetes-backend
    mode tcp
    option tcp-check
    balance roundrobin
    server k-${K8S_NAME}-c1 ${K8S_SUBNET}.11:6443 check fall 3 rise 2
    server k-${K8S_NAME}-c2 ${K8S_SUBNET}.12:6443 check fall 3 rise 2
    server k-${K8S_NAME}-c3 ${K8S_SUBNET}.13:6443 check fall 3 rise 2
EOF

# 8. enable & start the haproxy service
sudo systemctl enable haproxy
sudo systemctl start haproxy
