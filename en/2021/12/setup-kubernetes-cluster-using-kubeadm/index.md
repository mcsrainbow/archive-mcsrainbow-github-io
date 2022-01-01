# Setup Kubernetes Cluster Using kubeadm


kubeadm performs the actions necessary to get a minimum viable cluster up and running.

<!--more-->

## Prepare the Nodes

> Note: root user by default on all Nodes

Prepare the EC2 instances(replace the IP addresses as required)

```
OS: CentOS 7.9 x86_64
CPU: 2 vCores
Memory: 4 Gi

kubeadm01: 172.31.8.8
kubeadm02: 172.31.5.5
kubeadm03: 172.31.7.7
```

Upgrade kernel and packages

```
yum install -y http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm
yum install --enablerepo=elrepo-kernel -y kernel-lt

kernel_str=$(grep -E 'menuentry.*elrepo' /boot/grub2/grub.cfg | cut -d\' -f2)

grub2-set-default "${kernel_str}"
grub2-editenv list

yum -y update
```

Configure /etc/hostname

```
[root@kubeadm01 ~]# cat > /etc/hostname <<EOF
kubeadm01
EOF
[root@kubeadm01 ~]# hostname kubeadm01

[root@kubeadm02 ~]# cat > /etc/hostname <<EOF
kubeadm02
EOF
[root@kubeadm02 ~]# hostname kubeadm02

[root@kubeadm01 ~]# cat > /etc/hostname <<EOF
kubeadm03
EOF
[root@kubeadm03 ~]# hostname kubeadm03
```

Configure /etc/hosts(replace the IP addresses as required)

```
cat >> /etc/hosts <<EOF
172.31.8.8 kubeadm01
172.31.5.5 kubeadm02
172.31.7.7 kubeadm03
EO
```

Configure /etc/sysctl.conf

```
cat > /etc/sysctl.d/sysctl.conf <<EOF
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
net.ipv4.tcp_tw_recycle=0
vm.swappiness=0
vm.overcommit_memory=1
vm.panic_on_oom=0
fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=1048576
fs.file-max=52706963
fs.nr_open=52706963
net.ipv6.conf.all.disable_ipv6=1
net.netfilter.nf_conntrack_max=2310720
EOF

sysctl -p /etc/sysctl.d/sysctl.conf
```

Install required packages

```
yum install -y epel-release
yum install -y chrony conntrack ipvsadm ipset jq iptables curl sysstat libseccomp wget socat git vim lrzsz wget man tree rsync gcc gcc-c++ cmake telnet
```

Enable Chrony service

```
systemctl start chronyd
systemctl enable chronyd
```

Disable Firewalld, Swap and SELinux

```
systemctl stop firewalld
systemctl disable firewalld

swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

setenforce 0
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
```

Configure /etc/modules-load.d/kubernetes.conf and reboot

```
cat > /etc/modules-load.d/kubernetes.conf <<EOF
ip_vs_dh
ip_vs_ftp
ip_vs
ip_vs_lblc
ip_vs_lblcr
ip_vs_lc
ip_vs_nq
ip_vs_pe_sip
ip_vs_rr
ip_vs_sed
ip_vs_sh
ip_vs_wlc
ip_vs_wrr
nf_conntrack_ipv4
overlay
br_netfilter
EOF

systemctl enable systemd-modules-load.service

sync
reboot
```

Verify the kernel modules after reboot

```
lsmod | grep -e ip_vs -e nf_conntrack_ipv4
```

Install Docker

```
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum -y install docker-ce-20.10.8

cat > /etc/docker/daemon.json <<EOF
{"exec-opts": ["native.cgroupdriver=systemd"]}
EOF

usermod -G centos,adm,wheel,systemd-journal,docker,root centos

systemctl start  docker
systemctl enable docker
```


Disable postfix and create required directories

```
systemctl stop postfix
systemctl disable postfix

mkdir -p /opt/k8s/{bin,work} /etc/{kubernetes,etcd}/cert
```

## Setup the Cluster

> Note: Replace the version 1.22.1 as required

Install kubeadm, kubelet and kubectl on all Nodes

```
cat > /etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
EOF

yum install -y kubelet-1.22.1 kubeadm-1.22.1 kubectl-1.22.1

systemctl enable kubelet
systemctl start kubelet
```

Pull required Docker images on all Nodes

```
kubeadm config images pull --kubernetes-version v1.22.1
```

Run init on kubeadm01(replace the CIDR of Node, Pod and Service networks as required)

```
# Networks:
# Node: 172.31.0.0/16
# Pod: 10.192.0.0/16
# Service: 10.254.0.0/16

[root@kubeadm01 ~]# kubeadm init --apiserver-advertise-address=0.0.0.0 \
--apiserver-bind-port=6443 \
--kubernetes-version=v1.22.1 \
--pod-network-cidr=10.192.0.0/16 \
--service-cidr=10.254.0.0/16 \
--image-repository=k8s.gcr.io \
--ignore-preflight-errors=swap \
--token-ttl=0
```

```
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 172.31.8.8:6443 --token 2333y7.y7xev857t8n4w5em \
        --discovery-token-ca-cert-hash sha256:df7857bdae645dad4072db71ae9e92efd248ead2d8fb184edd1720a4cddc5049
```

Create .kube/config on kubeadm01

```
[root@kubeadm01 ~]# mkdir -p $HOME/.kube
[root@kubeadm01 ~]# cp /etc/kubernetes/admin.conf $HOME/.kube/config

[centos@kubeadm01 ~]$ mkdir -p $HOME/.kube
[centos@kubeadm01 ~]$ sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
[centos@kubeadm01 ~]$ sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Join the cluster via command on kubeadm02 and kubeadm03(repace the values as required)

```
[root@kubeadm02 ~]# kubeadm join 172.31.8.8:6443 --ignore-preflight-errors=swap \
        --token 2333y7.y7xev857t8n4w5em \
        --discovery-token-ca-cert-hash sha256:df7857bdae645dad4072db71ae9e92efd248ead2d8fb184edd1720a4cddc5049

[root@kubeadm03 ~]# kubeadm join 172.31.8.8:6443 --ignore-preflight-errors=swap \
        --token 2333y7.y7xev857t8n4w5em \
        --discovery-token-ca-cert-hash sha256:df7857bdae645dad4072db71ae9e92efd248ead2d8fb184edd1720a4cddc5049
```

```
This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

Check all Nodes status on kubeadm01

```
[centos@kubeadm01 ~]$ kubectl get nodes 
```

```
NAME        STATUS   ROLES                  AGE     VERSION
kubeadm01   Ready    control-plane,master   5m      v1.22.1
kubeadm02   Ready    <none>                 7m      v1.22.1
kubeadm03   Ready    <none>                 9m      v1.22.1
```

Install Flannel on kubeadm01(replace the CIDR of Pod network as required)

```
[centos@kubeadm01 ~]$ mkdir flannel 
[centos@kubeadm01 ~]$ cd flannel
[centos@kubeadm01 flannel]$ wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
[centos@kubeadm01 flannel]$ vim kube-flannel.yml
```

```yaml
 net-conf.json: |
    {
      "Network": "10.192.0.0/16",
      "Backend": {
        "Type": "vxlan"
      }
    }
```

```
[centos@kubeadm01 flannel]$ kubectl create -f kube-flannel.yml
```

Fix scheduler and controller-manager on kubeadm01

```
[centos@kubeadm01 ~]$ sudo cp -rpa /etc/kubernetes/manifests/etc/kubernetes/manifests.default
[centos@kubeadm01 ~]$ sudo sed -i '/port=0/d' /etc/kubernetes/manifests/kube-scheduler.yaml
[centos@kubeadm01 ~]$ sudo sed -i '/port=0/d' /etc/kubernetes/manifests/kube-controller-manager.yaml

[centos@kubeadm01 ~]$ sudo systemctl restart kubelet
```

Check clusterservice status on kubeadm01

```
[centos@kubeadm01 ~]$ kubectl get cs
```

```
NAME                 STATUS    MESSAGE                         ERROR
scheduler            Healthy   ok                              
controller-manager   Healthy   ok                              
etcd-0               Healthy   {"health":"true","reason":""} 
```

Check all Pods status on kubeadm01

```
[centos@kubeadm01 flannel]$ kubectl get pod --all-namespaces
```

```
NAMESPACE              NAME                                        READY   STATUS      RESTARTS   AGE
kube-system            coredns-78fcd69978-99vcx                    1/1     Running     0          5m
kube-system            coredns-78fcd69978-lm5bt                    1/1     Running     0          5m
kube-system            etcd-kubeadm01                              1/1     Running     0          5m
kube-system            kube-apiserver-kubeadm01                    1/1     Running     0          5m
kube-system            kube-controller-manager-kubeadm01           1/1     Running     0          5m
kube-system            kube-flannel-ds-b6c49                       1/1     Running     0          5m
kube-system            kube-flannel-ds-nspjx                       1/1     Running     0          7m
kube-system            kube-flannel-ds-sl5l2                       1/1     Running     0          9m
kube-system            kube-proxy-7r755                            1/1     Running     0          5m
kube-system            kube-proxy-nxz8c                            1/1     Running     0          7m
kube-system            kube-proxy-w8v6s                            1/1     Running     0          9m
kube-system            kube-scheduler-kubeadm01                    1/1     Running     0          5m
```

## Optimize the Cluster

Change the kube-proxy mode to ipvs, by default it's iptables

```
kubectl edit configmap kube-proxy -n kube-system
```

```yaml
mode: "ipvs"
```

```
kubectl get pods -n kube-system | grep kube-proxy | awk '{print $2}' | xargs kubectl -n kube-system delete pods
```
