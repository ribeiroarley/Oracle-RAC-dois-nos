# -*- mode: ruby -*-
# vi: set ft=ruby :

# Oracle RAC 23ai on Oracle Linux 9 (2 Nodes)
# Vagrantfile with VirtualBox Shared Storage and Software Directory mapping

Vagrant.configure("2") do |config|
  config.vm.box = "oraclelinux/9"
  config.vm.box_url = "https://oracle.github.io/vagrant-projects/boxes/oraclelinux/9.json"
  config.vm.boot_timeout = 900
  config.vm.synced_folder ".", "/vagrant", disabled: true

  asm_storage_dir = File.expand_path(".asm_storage")
  Dir.mkdir(asm_storage_dir) unless File.exist?(asm_storage_dir)

  asm_disks = [
    { name: "asm-crs01.vdi",  size: 5120  },
    { name: "asm-crs02.vdi",  size: 5120  },
    { name: "asm-crs03.vdi",  size: 5120  },
    { name: "asm-data01.vdi", size: 30720 },
    { name: "asm-reco01.vdi", size: 20480 }
  ]

  nodes = [
    {
      hostname: "racnode1",
      fqdn: "racnode1.localdomain",
      public_ip: "192.168.56.11",
      private_ip: "192.168.10.11",
      primary: true
    },
    {
      hostname: "racnode2",
      fqdn: "racnode2.localdomain",
      public_ip: "192.168.56.12",
      private_ip: "192.168.10.12",
      primary: false
    }
  ]

  nodes.each do |node|
    config.vm.define node[:hostname] do |vm_config|
      vm_config.vm.hostname = node[:fqdn]

      vm_config.vm.network "private_network", ip: node[:public_ip], netmask: "255.255.255.0", virtualbox__intnet: false
      vm_config.vm.network "private_network", ip: node[:private_ip], netmask: "255.255.255.0", virtualbox__intnet: "rac_priv_net"

      vm_config.vm.provider "virtualbox" do |v|
        v.name = node[:hostname]
        v.memory = 6144
        v.cpus = 2
        v.gui = false
        v.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
        v.customize ["modifyvm", :id, "--nicpromisc3", "allow-all"]
        v.customize ["modifyvm", :id, "--audio", "none"]
      end
    end
  end
end
