#!/bin/bash

####################

echo Setup: Install go \(currently limited to version 1.13.9\)

sudo apt-get update -y -q

cd /tmp
wget https://dl.google.com/go/go1.13.9.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.13.9.linux-amd64.tar.gz
rm -rf go1.13.9.linux-amd64.tar.gz

####################

echo Setup: Install bazel

sudo apt install g++ unzip zip -y -q
sudo apt-get install openjdk-8-jdk -y -q
cd /tmp
wget https://github.com/bazelbuild/bazel/releases/download/0.26.1/bazel-0.26.1-installer-linux-x86_64.sh
chmod +x bazel-0.26.1-installer-linux-x86_64.sh
./bazel-0.26.1-installer-linux-x86_64.sh --user

####################

echo Setup: Enlist compute

cd ~
git clone https://github.com/Open5g-cloud/compute.git ~/go/src/k8s.io/compute
cd ~/go/src/k8s.io
ln -s ./compute kubernetes

git config --global credential.helper 'cache --timeout=3600000'

####################

echo Setup: Install etcd

cd ~/go/src/k8s.io/compute/
git tag v1.15.0
./hack/install-etcd.sh

####################

echo Setup: Install Docker

sudo apt -y install docker.io
sudo gpasswd -a $USER docker

####################

echo Setup: Install crictl

cd /tmp
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.17.0/crictl-v1.17.0-linux-amd64.tar.gz
sudo tar zxvf crictl-v1.17.0-linux-amd64.tar.gz -C /usr/local/bin
rm -f crictl-v1.17.0-linux-amd64.tar.gz

touch /tmp/crictl.yaml
echo runtime-endpoint: unix:///run/containerd/containerd.sock >> /tmp/crictl.yaml
echo image-endpoint: unix:///run/containerd/containerd.sock >> /tmp/crictl.yaml
echo timeout: 10 >> /tmp/crictl.yaml
echo debug: true >> /tmp/crictl.yaml
sudo mv /tmp/crictl.yaml /etc/crictl.yaml

mkdir -p /etc/containerd
sudo rm -rf /etc/containerd/config.toml
sudo containerd config default > /tmp/config.toml
sudo mv /tmp/config.toml /etc/containerd/config.toml
sudo systemctl restart containerd

####################

echo Setup: Install miscellaneous

sudo apt install awscli -y -q
sudo apt install python-pip -y -q
sudo apt install jq -y -q

####################

echo Setup: Install Kind

cd ~/go/src/
GO111MODULE="on" go get sigs.k8s.io/kind@v0.7.0

####################

echo Setup: Network Related

cd ~/network
sudo apt-get update
sudo apt-get install -y \
    build-essential clang-7 llvm-7 \
    libelf-dev \
    python3 \
    python3-pip \
    libcmocka-dev \
    lcov

sudo apt install docker.io
sudo pip3 install netaddr docker scapy
sudo systemctl unmask docker.service
sudo systemctl unmask docker.socket
sudo systemctl start docker
sudo systemctl enable docker

sudo docker build -f ./test/Dockerfile -t buildbox:v2 ./test

git submodule update --init --recursive

ver=$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
curl -Lo kind https://github.com/kubernetes-sigs/kind/releases/download/$ver/kind-$(uname)-amd64
chmod +x kind
sudo mv kind /usr/local/bin

curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

pip3 install fs
pip3 install protobuf
pip3 install grpcio
pip3 install grpcio-tools
pip3 install luigi==2.8.12
pip3 install kubernetes==11.0.0
pip3 install rpyc
pip3 install pyroute2
pip3 install ipaddress
pip3 install netaddr
pip3 install kopf
pip3 install PyYAML

####################

echo Setup: Setup profile

echo PATH=\"\$HOME/go/src/k8s.io/compute/third_party/etcd:/usr/local/go/bin:\$HOME/go/bin:\$HOME/go/src/k8s.io/compute/_output/bin:\$HOME/go/src/k8s.io/compute/_output/dockerized/bin/linux/amd64:\$PATH\" >> ~/.profile
echo GOPATH=\"\$HOME/go\" >> ~/.profile
echo GOROOT=\"/usr/local/go\" >> ~/.profile
echo >> ~/.profile
echo alias compute=\"cd \$HOME/go/src/k8s.io/compute\" >> ~/.profile
echo alias k8s=\"cd \$HOME/go/src/k8s.io/kubernetes\" >> ~/.profile
echo alias network=\"cd \$HOME/network\" >> ~/.profile
echo alias up=\"\$HOME/go/src/k8s.io/compute/hack/compute-up.sh\" >> ~/.profile
echo alias status=\"git status\" >> ~/.profile
echo alias pods=\"kubectl get pods -A -o wide\" >> ~/.profile
echo alias nets=\"echo 'kubectl get subnets'\; kubectl get subnets\; echo\; echo 'kubectl get droplets'\; kubectl get droplets\; echo\; echo 'kubectl get bouncers'\; kubectl get bouncers\; echo\; echo 'kubectl get dividers'\; kubectl get dividers\; echo\; echo 'kubectl get vpcs'\; kubectl get vpcs\; echo\; echo 'kubectl get eps'\; kubectl get eps\; echo\; echo 'kubectl get networks'\; kubectl get networks\" >> ~/.profile

echo export PYTHONPATH=\"\$HOME/network/\" >> ~/.profile
echo export GPG_TTY=\$\(tty\) >> ~/.profile

echo cd \$HOME/go/src/k8s.io/compute >> ~/.profile

source "$HOME/.profile"

####################

echo Setup: Install kubetest

cd ~/go/src/k8s.io
git clone https://github.com/kubernetes/test-infra.git
cd ~/go/src/k8s.io/test-infra/
GO111MODULE=on go install ./kubetest
GO111MODULE=on go mod vendor

####################

echo Setup: Machine setup completed!

sudo reboot
