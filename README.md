# fedora-iot-raspberry-pi-kubernetes
Running kubernetes on a small fedora-iot raspberry pi cluster
Fedora IOT kubernetes cluster on Raspbery Pi
This is a cheap 4 node raspberry pi kubernetes cluster, mostly inspired by geerlinguy project:  https://github.com/geerlingguy/raspberry-pi-dramble
My goal was to start learning ansible and kubernetes using the pis as a sandbox.  I also wanted to use fedora-iot instead of raspian, as fedora-iot uses the whole “immutable-os” concept from core-os - a lot of things to learn on such a cheap little system.  
The BOM is below, also add four 32gb microsd cards, I used samsung EVO plus - don’t use el-cheapo microsd cards or things will be painfully slow.  I didn’t bother to install the cooling fans as the PIs don’t seem to have any heat issues running a variety of things this last month.  Entire thing can be built for <$250 assuming you use a random switch you have laying around.
Also I bought 4 blinkstick nanos… I wish they were a bit less expensive and there was a distributor in the US, but I paid the 15 pounds British and they shipped them internationally.  These I want to use to have a visual representation of what state each node is in.
BOM:
https://github.com/edhaynes/fedora-iot-raspberry-pi-kubernetes/blob/master/Screenshot%20from%202019-07-10%2011-47-22.png





This is what the topology looks like, I’m using my fedora workstation as a jumphost and DHCP/NAT server for the PIs.
https://github.com/edhaynes/fedora-iot-raspberry-pi-kubernetes/blob/master/sl7OQAZtIKae03_w45lOzCQ.png


Fedora-iot is great, though I do wish there wasn’t the requirement for keyboard configuration on the first boot.  It has everything you need to run containers and I’ve already been saved by rolling back a bad change that bricked the system (an incorrect edit in SELinux file).

I used my fedora 30 workstation as a jumphost for the PIs, acting as a DHCP server and Nat server.
to configure NAT on fedora workstation:
sysctl -w net.ipv4.ip_forward=1

nat-script: - run this script as root on fedora workstation to setup iptables
#!/bin/sh
INTIF="enp0s20f0u5u3u1"
EXTIF="enp0s31f6"
/sbin/depmod -a
/sbin/modprobe ip_tables
/sbin/modprobe ip_conntrack
/sbin/modprobe ip_conntrack_ftp
/sbin/modprobe ip_conntrack_irc
/sbin/modprobe iptable_nat
/sbin/modprobe ip_nat_ftp
iptables -P INPUT ACCEPT
iptables -F INPUT
iptables -P OUTPUT ACCEPT
iptables -F OUTPUT
iptables -P FORWARD DROP
iptables -F FORWARD
iptables -t nat -F
iptables -A FORWARD -i $EXTIF -o $INTIF -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i $INTIF -o $EXTIF -j ACCEPT
iptables -t nat -A POSTROUTING -o $EXTIF -j MASQUERADE

I then installed dhcpd on fedora

sudo dnf install dhcp
edit /etc/dhcpd.conf as below.  First time raspberry pis boot they will be assigned ip by server.  We then use nmap to find the ip addresses and arp to find their mac addresses so we can statically set their addresses in the dhcpd.conf

dhcpd.conf:
subnet 10.0.100.0 netmask 255.255.255.0 {  
  range 10.0.100.2 10.0.100.200;

  option domain-name-servers 8.8.8.8, 8.8.4.4;
  option routers 10.0.100.1;
}

sudo systemctl start dhcpd.service




Report all live IP addresses on the 10.0.100.x subnet
nmap -sn 10.0.100.0/24

nmap -sn 10.0.100.0/24
Starting Nmap 7.70 ( https://nmap.org ) at 2019-07-10 16:26 EDT
Nmap scan report for 10.0.100.1
Host is up (0.00091s latency).
Nmap scan report for kube1 (10.0.100.61)
Host is up (0.0013s latency).
Nmap scan report for kube2 (10.0.100.62)
Host is up (0.0012s latency).
Nmap scan report for kube3 (10.0.100.63)
Host is up (0.0011s latency).
Nmap scan report for kube4 (10.0.100.64)
Host is up (0.0010s latency).
Nmap done: 256 IP addresses (5 hosts up) scanned in 2.73 seconds

Figure out the mac addressses of the raspberry pis to populate dhcp server configuration

[ehaynes@new-host-3 ~]$ arp -a

kube1 (10.0.100.61) at b8:27:eb:8f:6c:64 [ether] on enp0s20f0u5u3u1

kube4 (10.0.100.64) at b8:27:eb:42:a2:fe [ether] on enp0s20f0u5u3u1

IP-STB2.home (192.168.1.100) at 3c:df:a9:a2:c1:01 [ether] on enp0s31f6

_gateway (192.168.2.1) at 1c:87:2c:4a:11:18 [ether] on wlp3s0

kube3 (10.0.100.63) at b8:27:eb:1e:9b:84 [ether] on enp0s20f0u5u3u1

IP-STB1.home (192.168.1.101) at 3c:df:a9:65:1e:98 [ether] on enp0s31f6

kube2 (10.0.100.62) at b8:27:eb:5b:1f:e8 [ether] on enp0s20f0u5u3u1

Wireless_Broadband_Router.home (192.168.1.1) at 00:7f:28:5f:69:77 [ether] on enp0s31f6



now edit the dhcpd.conf to put the appropriate mac values in.  you should shutdown the pis, reboot dhcpd, and flush your arp cache.  Now that we know the macs of the PIs we can statically set the addresses in dhcpd.conf like below:

Dhcpd.conf: 

subnet 10.0.100.0 netmask 255.255.255.0 {  
  range 10.0.100.2 10.0.100.200;

  option domain-name-servers 8.8.8.8, 8.8.4.4;
  option routers 10.0.100.1;
}

host kube1 {
   option host-name "kube1";
   hardware ethernet b8:27:eb:8f:6c:64;
   fixed-address 10.0.100.61;
}

host kube2 {
   option host-name "kube2";
   hardware ethernet b8:27:eb:5b:1f:e8;
   fixed-address 10.0.100.62;
}
host kube3 {
   option host-name "kube3";
   hardware ethernet b8:27:eb:1e:9b:84;
   fixed-address 10.0.100.63;
}
host kube4 {
   option host-name "kube4";
   hardware ethernet b8:27:eb:42:a2:fe;
   fixed-address 10.0.100.64;
}

also i edited my /etc/hosts to know about the pis 

cat /etc/hosts

127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

10.0.100.61 kube1

10.0.100.62 kube2

10.0.100.63 kube3

10.0.100.64 kube4


and i set up a file I called inventory to use with ad-hoc ansible commands
cat inventory 


[pis]

kube1

kube2

kube3

kube4

[pis:vars]

ansible_ssh_user=pi



Configuring Fedora IOT: 


On your jumphost/workstation :Download Fedora IOT 

wget https://dl.fedoraproject.org/pub/alt/iot/30/IoT/aarch64/images/Fedora-IoT-30-20190515.1.aarch64.raw.xz

make sure you have arm image installer 
sudo dnf install arm-image-installer

insert microssd into reader.   use lkblk to figure out which disk it is.  note in my case it happens the 32G microssd is /dev/sda which often is the system disk in linux… be careful you target the correct disk so you don’t wipe your system.

ehaynes@new-host-3 fedora_iot]$ lsblk

NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT

sda           8:0    1  29.8G  0 disk 

├─sda1        8:1    1   142M  0 part /run/media/ehaynes/F02A-29CE

├─sda2        8:2    1     1G  0 part /run/media/ehaynes/76d84759-c70c-4ed6-ae42

└─sda3        8:3    1  28.7G  0 part /run/media/ehaynes/96db2e6f-4327-4c2f-aa62

nvme0n1     259:0    0 953.9G  0 disk 

├─nvme0n1p1 259:1    0   499M  0 part 

├─nvme0n1p2 259:2    0    99M  0 part /boot/efi

├─nvme0n1p3 259:3    0    16M  0 part 

├─nvme0n1p4 259:4    0   758G  0 part 

├─nvme0n1p5 259:5    0 163.4G  0 part /

└─nvme0n1p6 259:6    0    32G  0 part [SWAP]



unmount any partitions on the disk
sudo umount /dev/sda1
sudo umount /dev/sda2
sudo umount /dev/sda3






Install Fedora IOT to the microssd

sudo arm-image-installer --image=Fedora-IoT-30-20190515.1.aarch64.raw.xz  --target=rpi3 --media=/dev/xxx --addkey=/home/ehaynes/.ssh/id_rsa.pub --resizefs


boot Fedora IOT and use keyboard to create user account pi (administrator), make sure to set a password  A weird thing I noticed is that it would not boot if I had logitech wireless keyboard dongle plugged in … hmm.  works fine after it boots first time

install your ssh key
ansible-playbook -i inventory copy_ssh_keys_to_pis.yml  -u ehaynes -k

cat copy_ssh_keys_to_pis.yml 

---

- hosts: all

  tasks:
  
    - authorized_key:
    
        user: pi
        
        state: present
        
        key: "{{ lookup('file', '/home/ehaynes/.ssh/id_rsa.pub') }}"
        


here is stuff to install to resolve dependencies - unfortunately it seems ansible doesn’t have an rpm-ostree module yet

sudo rpm-ostree update
sudo rpm-ostree install python python-pip kubernetes-kubeadm docker ethtool tc

Note that once you start running kube master SELinux warning “SELInux: mount invalid.” is a benign warning.  A bug has been filed.

Kubernetes doesn’t like swap for some reason.  
 
sudo systemctl stop zram-swap.service
sudo systemctl disable zram-swap.service

Kubernetes also wants ip forwarding turned on
sysctl -w net.ipv4.ip_forward=1


Start some stuff kubernetes wants to see to install master & nodes

systemctl enable kubelet.service
systemctl start kubelet.service
systemctl start docker.service
systemctl enable docker.serice

Enable ports for the API
sudo firewall-cmd --add-port=6443/tcp --permanent
sudo firewall-cmd --add-port=10250/tcp --permanent

Install API for my blinkstick nano USB device
pip install blinkstick --user
sudo ~/.local/bin/blinkstick --add-udev-rule 

then reboot for udev-rule to take effect

Test Led
blinkstick --pulse red

edit /etc/hosts on the 4 pis to reflect the following:
10.0.100.61 kube1
10.0.100.62 kube2
10.0.100.63 kube3
10.0.100.64 kube4


For the Kubernetes Master:

you run

sudo kubeadmin init

First time you run it will go through pre-checks … assuming everything is configured as above you will have one Error in the pre-checks:   unsupported kernel version. if there are any other errors fix them before going forward.  Once you’re down to that one Error you can change command to 

sudo kubeadm init --ignore-preflight-errors=all

So the default timeout is too short for raspberry pi’s cpu to get everything done.  I don’t think there is a way to change timeout from commandline, and the kube-apiserver.yaml file hasn’t been created yet to edit … so after running kubeadm init in another window as root I repeatedly executed this command until i did not get the “file not found” editing kube-apiserver.yaml soon after it’s created… this allowed kubeadm init to finish lol.   There is a better way I’m sure.

sed -i 's/initialDelaySeconds: [0-9]\+/initialDelaySeconds: 180/' /etc/kubernetes/manifests/kube-apiserver.yaml
Then I follow the instructions kubeadm init gives you:
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl apply --filename https://git.io/weave-kube-1.6
assuming things go well the output will be to give the kubeadm join command like below.  Make sure to copy it as it is unique to your install and needed to join the other kubernetes nodes.

kubeadm join 10.0.100.64:6443 --token 1alw8x.4nd5ay8s4dlrt6fd --discovery-token-ca-cert-hash sha256:88510a3f8754051c648ad70fe180bc68fa66a2bad03ff7a72606d8403837d154
Now on the other 3 nodes run the kubeadm join command.  As before make sure you don’t have any preflight errors other than unsupported kernel version.  like on the master you will need ipv4 forwarding on, swap disabled, docker enabled and started, and kubelet enabled and started.
once this is done you should be able to log into the kubernetes master and do 
kubectl get nodes
NAME    STATUS   ROLES    AGE     VERSION
kube1   Ready    <none>   3h20m   v1.13.5
kube2   Ready    <none>   3h1m    v1.13.5
kube3   Ready    <none>   136m    v1.13.5
kube4   Ready    master   21h     v1.13.5

If any show as not ready you can run
kubectl describe nodes
to get an idea of what’s going wrong





Blinkstick commands:
Set blinksticks to light led on both sides:
ansible -i inventory all -a "blinkstick --set-mode 3" -b
Variety of color commands:
ansible -i inventory all -a "blinkstick blue" 
ansible -i inventory all -a "blinkstick --pulse orange" 
ansible -i inventory all -a "blinkstick --pulse purple" 
ansible -i inventory all -a "blinkstick blue" --forks 1
ansible -i inventory all -a "blinkstick purple" --forks 1
ansible -i inventory all -a "blinkstick purple" --forks 2






Some handy commands:

Report all live IP addresses on the 10.0.100.x subnet
nmap -sn 10.0.100.0/24


Reboot all of inventory
ansible all -i inventory -m shell -a "sleep 1s; shutdown -r now" -b -B 60 -P 0

Get current disk usage.
$ ansible all -i inventory -a "df -h"

Get current memory usage.
$ ansible all -i inventory -a "free -m"

Reboot all the Pis.
$ ansible all -i inventory -m shell -a "sleep 1s; shutdown -r now" -b -B 60 -P 0


install package
ansible -i inventory all -m apt -a "name=python-dev state=present" -b

Shut down all the Pis.
$ ansible all -i inventory -m shell -a "sleep 1s; shutdown -h now" -b -B 60 -P 0

Equivalent of “apt update ; apt upgrade”
ansible -i inventory -m apt -a "upgrade=yes update_cache=yes" -b all

Equivalent of pip install openshift
ansible -i inventory -m pip -a "name=openshift" all -b 



