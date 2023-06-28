
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/bionic64"
  config.vm.hostname = "host"
  config.vm.network "private_network", ip: "192.168.56.4"
  # config.vm.define "guest" do |guest|
  #   guest.vm.hostname = "guest"
  #   guest.vm.network "private_network", ip: "192.168.56.5"
  # end
  # config.vm.define "host", primary: true do |host|
  #   host.vm.hostname = "host"
  #   host.vm.network "private_network", ip: "192.168.56.4"
  # end
  config.vm.provision "shell", path: "script.sh"
end
