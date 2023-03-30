---
title: "使用kubeadm快速部署Kubernetes集群"
date: 2021-12-21T21:58:24+08:00
author: "郭冬"
description: "kubeadm是Kubernetes官方提供的用于快速部署集群的工具"
categories: ["技能矩阵"]
tags: ["Kubernetes"]
resources:
- name: "featured-image"
  src: "featured-image.jpeg"

lightgallery: true
---

kubeadm是Kubernetes官方提供的用于快速部署集群的工具。

<!--more-->

## 背景

kubeadm大大降低了Kubernetes集群部署的复杂度，但通常仅仅用来部署一个最小可用集群，方便学习和测试。生产级别的Kubernetes集群则需要高可用、高性能和更灵活的配置，建议通过源码包方式部署或选择已有的商业产品或公有云服务。

## 环境准备

> 注：以下步骤都需要在所有节点上以root用户操作完成

准备3台虚拟机节点（根据实际情况替换为真实IP）

```
OS: CentOS 7.9 x86_64
CPU: 2 vCores
Memory: 4 Gi

kubeadm01: 172.31.8.8
kubeadm02: 172.31.5.5
kubeadm03: 172.31.7.7
```

升级内核与系统软件包

```
yum install -y http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm
yum install --enablerepo=elrepo-kernel -y kernel-lt

kernel_str=$(grep -E 'menuentry.*elrepo' /boot/grub2/grub.cfg | cut -d\' -f2)

grub2-set-default "${kernel_str}"
grub2-editenv list

yum -y update
```

配置各节点主机名

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

配置主机名解析（根据实际情况替换为真实IP）

```
cat >> /etc/hosts <<EOF
172.31.8.8 kubeadm01
172.31.5.5 kubeadm02
172.31.7.7 kubeadm03
EO
```

配置内核参数

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

安装所需软件包

```
yum install -y epel-release
yum install -y chrony conntrack ipvsadm ipset jq iptables curl sysstat libseccomp wget socat git vim lrzsz wget man tree rsync gcc gcc-c++ cmake telnet
```

启用Chrony时间同步服务

```
systemctl start chronyd
systemctl enable chronyd
```

禁用Firewalld，Swap和SELinux

```
systemctl stop firewalld
systemctl disable firewalld

swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

setenforce 0
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
```

配置内核模块，然后重启生效

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

重启后，验证已加载内核模块

```
lsmod | grep -e ip_vs -e nf_conntrack_ipv4
```

安装Docker

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


禁用postfix，创建所需目录

```
systemctl stop postfix
systemctl disable postfix

mkdir -p /opt/k8s/{bin,work} /etc/{kubernetes,etcd}/cert
```

## 集群搭建

> 注：以下步骤需要在不同节点上操作完成（根据实际情况替换1.22.1为需要的版本）

在所有节点上安装kubeadm，kubelet和kubectl

```
cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
EOF

yum install -y kubelet-1.22.1 kubeadm-1.22.1 kubectl-1.22.1

systemctl enable kubelet
systemctl start kubelet
```

在所有节点上拉取Docker镜像

```
kubeadm config images pull --image-repository registry.aliyuncs.com/google_containers --kubernetes-version v1.22.1
```

```
[config/images] Pulled registry.aliyuncs.com/google_containers/kube-apiserver:v1.22.1
[config/images] Pulled registry.aliyuncs.com/google_containers/kube-controller-manager:v1.22.1
[config/images] Pulled registry.aliyuncs.com/google_containers/kube-scheduler:v1.22.1
[config/images] Pulled registry.aliyuncs.com/google_containers/kube-proxy:v1.22.1
[config/images] Pulled registry.aliyuncs.com/google_containers/pause:3.5
[config/images] Pulled registry.aliyuncs.com/google_containers/etcd:3.5.0-0
[config/images] Pulled registry.aliyuncs.com/google_containers/coredns:v1.8.4
```

列出默认所需镜像及版本

```
kubeadm config images list --kubernetes-version v1.22.1
```

```
k8s.gcr.io/kube-apiserver:v1.22.1
k8s.gcr.io/kube-controller-manager:v1.22.1
k8s.gcr.io/kube-scheduler:v1.22.1
k8s.gcr.io/kube-proxy:v1.22.1
k8s.gcr.io/pause:3.5
k8s.gcr.io/etcd:3.5.0-0
k8s.gcr.io/coredns/coredns:v1.8.4
```

在所有节点上修改已拉取的镜像的Tag

```bash
# 将除了coredns以外的镜像Tag为k8s.gcr.io镜像源
for i in $(docker images | grep google_containers | awk '{print $1":"$2}' | cut -d/ -f3 | grep -v coredns); do docker tag registry.aliyuncs.com/google_containers/$i k8s.gcr.io/$i;done
# 将coredns的镜像Tag为k8s.gcr.io镜像源，并增加/coredns前缀
for i in $(docker images | grep google_containers/coredns | awk '{print $1":"$2}' | cut -d/ -f3); do docker tag registry.aliyuncs.com/google_containers/$i k8s.gcr.io/coredns/$i;done
# 删除镜像的旧Tag
for i in $(docker images | grep google_containers | awk '{print $1":"$2}' | cut -d/ -f3); do docker rmi registry.aliyuncs.com/google_containers/$i;done
```

在kubeadm01上执行init（根据实际情况替换Node，Pod和Service的网段）

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

在kubeadm01上配置.kube/config

```
[root@kubeadm01 ~]# mkdir -p $HOME/.kube
[root@kubeadm01 ~]# cp /etc/kubernetes/admin.conf $HOME/.kube/config

[centos@kubeadm01 ~]$ mkdir -p $HOME/.kube
[centos@kubeadm01 ~]$ sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
[centos@kubeadm01 ~]$ sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

在kubeadm02和kubeadm03上执行join（根据实际情况替换参数的值）

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

在kubeadm01上查看节点状态

```
[centos@kubeadm01 ~]$ kubectl get nodes 
```

```
NAME        STATUS   ROLES                  AGE     VERSION
kubeadm01   Ready    control-plane,master   5m      v1.22.1
kubeadm02   Ready    <none>                 7m      v1.22.1
kubeadm03   Ready    <none>                 9m      v1.22.1
```

在kubeadm01上安装Flannel网络插件（根据实际情况替换Pod的网段）

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

在kubeadm01上修复scheduler和controller-manager

```
[centos@kubeadm01 ~]$ sudo cp -rpa /etc/kubernetes/manifests/etc/kubernetes/manifests.default
[centos@kubeadm01 ~]$ sudo sed -i '/port=0/d' /etc/kubernetes/manifests/kube-scheduler.yaml
[centos@kubeadm01 ~]$ sudo sed -i '/port=0/d' /etc/kubernetes/manifests/kube-controller-manager.yaml

[centos@kubeadm01 ~]$ sudo systemctl restart kubelet
```

在kubeadm01上查看clusterservice状态

```
[centos@kubeadm01 ~]$ kubectl get cs
```

```
NAME                 STATUS    MESSAGE                         ERROR
scheduler            Healthy   ok                              
controller-manager   Healthy   ok                              
etcd-0               Healthy   {"health":"true","reason":""} 
```

在kubeadm01上查看所有Pod的状态

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

## 配置优化

默认kube-proxy的mode为iptables，修改为功能更强大的ipvs

```
kubectl edit configmap kube-proxy -n kube-system
```

```yaml
mode: "ipvs"
```

```
kubectl get pods -n kube-system | grep kube-proxy | awk '{print $2}' | xargs kubectl -n kube-system delete pods
```