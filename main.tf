## Providers

provider "hcloud" {
  token = var.hcloud-token
}

## SSH Key Pair

resource "hcloud_ssh_key" "typhon" {
  name       = "typhon"
  public_key = file(var.ssh-pub-key)
}

## Network

resource "hcloud_network" "priv_net" {
  name     = "${var.env}-network"
  ip_range = "10.0.0.0/16"
  labels = {
    environment  = var.env
    resourcetype = "private-network"
  }
}

resource "hcloud_network_subnet" "priv_prim_subnet" {
  network_id   = hcloud_network.priv_net.id
  type         = "cloud"
  ip_range     = "10.0.0.0/24"
  network_zone = "eu-central"
}

## Virtual Machine

resource "hcloud_server" "minikube" {
  name        = "minikube"
  server_type = "cx41"
  image       = "debian-11"
  location    = "nbg1"
  ssh_keys = [
    hcloud_ssh_key.typhon.id
  ]

  network {
    network_id = hcloud_network.priv_net.id
    ip         = "10.0.0.11"
  }

  provisioner "file" {
    source      = "./src/minikube-bootstrap"
    destination = "/root"
    connection {
      host        = self.ipv4_address
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh-priv-key)
    }
  }

  provisioner "remote-exec" {
    inline = [
      "apt update && apt dist-upgrade -y",
      "apt install ansible -y",
      "ansible-playbook -i localhost /root/minikube-bootstrap/ansible.yml"
    ]
    connection {
      host        = self.ipv4_address
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh-priv-key)
    }
  }

  provisioner "local-exec" {
    command = "./src/get-kube-config.sh ${self.ipv4_address}"
  }

  labels = {
    environment  = var.env
    resourcetype = "server"
    service      = "minikube"
    region       = "nbg1"
  }

  depends_on = [hcloud_network_subnet.priv_prim_subnet]
}

resource "time_sleep" "wait" {
  depends_on      = [hcloud_server.minikube]
  create_duration = "30s"
}

## Load Balancer

resource "hcloud_load_balancer" "lb" {
  name               = "${var.env}-lb"
  load_balancer_type = "lb11"
  location           = "nbg1"
  algorithm {
    type = "least_connections"
  }
}

resource "hcloud_load_balancer_network" "lb_net" {
  load_balancer_id = hcloud_load_balancer.lb.id
  subnet_id        = hcloud_network_subnet.priv_prim_subnet.id
}

resource "hcloud_load_balancer_service" "lb_svc_http" {
  load_balancer_id = hcloud_load_balancer.lb.id
  protocol         = "tcp"
  listen_port      = 80
  destination_port = 32080
}

resource "hcloud_load_balancer_service" "lb_svc_https" {
  load_balancer_id = hcloud_load_balancer.lb.id
  protocol         = "tcp"
  listen_port      = 443
  destination_port = 32443
}

resource "hcloud_load_balancer_target" "lb_tgt_http" {
  type             = "server"
  load_balancer_id = hcloud_load_balancer.lb.id
  server_id        = hcloud_server.minikube.id
  use_private_ip   = "true"
  depends_on       = [hcloud_load_balancer_network.lb_net, hcloud_server.minikube]
}
