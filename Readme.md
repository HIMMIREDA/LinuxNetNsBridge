# Proof of concept about container networking using linux network namespaces

read script.sh comments to know the architecture and ip addrs of interfaces in each net namespace

1. run vm (ip addr of vm is 192.168.56.4 in private network (=host-only network) see Vagrantfile):
```bash
vagrant up
```
2. ssh to vm:
```bash
env -i HOME="$HOME" TERM="xterm" zsh -l -c "vagrant ssh"
```
3. try ping from different namespaces
```bash
sudo ip netns exec ns1 ping 10.10.0.20
sudo ip netns exec ns2 ping 10.10.0.10
sudo ip netns exec ns1 ping 8.8.8.8 #outside traffic
sudo ip netns exec ns2 ping  google.com
ping 127.0.0.1:8080
ping 10.10.0.1:8080
ping 10.10.0.10:8080
sudo ip netns exec ns2 ping 10.10.0.1:8080
sudo ip netns exec ns1 ping 10.10.0.1:8080 # test Hairpin NAT 
```
4. delete vm:
```bash
vagrant destroy
```

