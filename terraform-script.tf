provider "google" {
  project = "eighth-upgrade-436909-e3"
  region  = "us-central1"
}

variable "instance_count" {
  type    = number
  default = 3
}

resource "google_compute_instance" "centos_vm" {
  count        = var.instance_count
  name         = "ansible-${count.index + 1}"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-stream-9"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata = {
    ssh-keys = "centos:${file("/root/.ssh/id_rsa.pub")}"
  }

  tags = ["http-server"]
}

# Output the instance IPs for the dynamic inventory
output "vm_ips" {
  value = google_compute_instance.centos_vm[*].network_interface[0].access_config[0].nat_ip
}



resource "null_resource" "generate_inventory" {
  provisioner "local-exec" {
    command = <<EOT
      echo 'all:' > /var/lib/jenkins/workspace/terra-multi-ans/inventory.gcp.yml
      echo '  children:' >> /var/lib/jenkins/workspace/terra-multi-ans/inventory.gcp.yml
      echo '    web:' >> /var/lib/jenkins/workspace/terra-multi-ans/inventory.gcp.yml
      echo '      hosts:' >> /var/lib/jenkins/workspace/terra-multi-ans/inventory.gcp.yml
      for i in $(seq 0 ${var.instance_count - 1}); do
        INSTANCE_IP=$(terraform output -json vm_ips | jq -r ".[$i]")
        echo "        web_ansible-$((i + 1)):" >> /var/lib/jenkins/workspace/terra-multi-ans/inventory.gcp.yml
        echo "          ansible_host: \$INSTANCE_IP" >> /var/lib/jenkins/workspace/terra-multi-ans/inventory.gcp.yml
        echo "          ansible_user: centos" >> /var/lib/jenkins/workspace/terra-multi-ans/inventory.gcp.yml
        echo "          ansible_ssh_private_key_file: /root/.ssh/id_rsa" >> /var/lib/jenkins/workspace/terra-multi-ans/inventory.gcp.yml
      done
    EOT
  }

  depends_on = [google_compute_instance.centos_vm]
}

