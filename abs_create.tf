variable "azure_subscription_id" {}
variable "baseName" {}
variable "version" {}
variable "customDNSBase" {}
variable "location" {}


# create an override.tf with the real subscription_id
provider "azurerm" {
  version = "=1.21.0"
  subscription_id = "${var.azure_subscription_id}"
}

# Change the following per your environment
locals {
  baseName = "abs"
  version = "2"
  adminKeyPairName = "id_${var.baseName}${var.version}_rsa"
  keysLocation = "./keys/${var.baseName}${var.version}"
  customDNSName="${var.baseName}${var.version}.${var.customDNSBase}"
  azureDNSName="${var.baseName}${var.version}.${var.location}.cloudapp.azure.com"
}

# Create a resource group
resource "azurerm_resource_group" "test" {
  name     = "${var.baseName}${var.version}"
  location = "${var.location}"
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "test" {
  name                = "${var.baseName}-network"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.test.location}"
  resource_group_name = "${azurerm_resource_group.test.name}"
}

# Create a Subnet
resource "azurerm_subnet" "test" {
  name                 = "${var.baseName}-subnet"
  resource_group_name  = "${azurerm_resource_group.test.name}"
  virtual_network_name = "${azurerm_virtual_network.test.name}"
  address_prefix       = "10.0.0.0/24"
}

resource "azurerm_public_ip" "test" {
  name                 = "${var.baseName}-ip"
  resource_group_name  = "${azurerm_resource_group.test.name}"
  location             = "${azurerm_resource_group.test.location}"
  allocation_method    = "Static"
}

resource "azurerm_network_security_group" "test" {
  name                = "${azurerm_resource_group.test.name}-nsg"
  resource_group_name = "${azurerm_resource_group.test.name}"
  location            = "${azurerm_resource_group.test.location}"
  
  security_rule {
    name                       = "allow-ssh"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-http"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-docker-tls"
    priority                   = 1020
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "2376"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-jenkins-JNLP"
    priority                   = 1030
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "50000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-docker-registry"
    priority                   = 1040
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "https"
    priority                   = 1050
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }


}
resource "azurerm_network_interface" "test" {
  name                = "${azurerm_resource_group.test.name}-nic"
  resource_group_name = "${azurerm_resource_group.test.name}"
  location            = "${azurerm_resource_group.test.location}"
  network_security_group_id = "${azurerm_network_security_group.test.id}"
  
  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = "${azurerm_subnet.test.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.test.ip_address}"
  }
}

resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${azurerm_resource_group.test.name}"
    }

    byte_length = 4
}

resource "azurerm_storage_account" "test" {
  name                     = "${var.baseName}${var.version}registry${random_id.randomId.hex}"
  account_kind             = "BlobStorage"
  resource_group_name      = "${azurerm_resource_group.test.name}"
  location                 = "${azurerm_resource_group.test.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_virtual_machine" "main" {
  name                  = "${var.baseName}${var.version}-vm"
  location              = "${azurerm_resource_group.test.location}"
  resource_group_name   = "${azurerm_resource_group.test.name}"
  network_interface_ids = ["${azurerm_network_interface.test.id}"]
  vm_size               = "Standard_DS1_v2"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  # delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "${var.baseName}${var.version}"
    admin_username = "absadmin"
  }
  os_profile_linux_config {
    disable_password_authentication = true
  
    ssh_keys {
      key_data = "${file("${local.keysLocation}/${local.adminKeyPairName}.pub")}"
      path = "/home/absadmin/.ssh/authorized_keys"
    }  
  }

    # connection {
    #     host = "sometestdn.ukwest.cloudapp.azure.com"
    #     user = "testuser"
    #     type = "ssh"
    #     private_key = "${file("~/.ssh/id_rsa_unencrypted")}"
    #     timeout = "1m"
    #     agent = true
    # }

    # provisioner "remote-exec" {
    #     inline = [
    #       "sudo apt-get update",
    #       "sudo apt-get install docker.io -y",
    #       "git clone https://github.com/somepublicrepo.git",
    #       "cd Docker-sample",
    #       "sudo docker build -t mywebapp .",
    #       "sudo docker run -d -p 5000:5000 mywebapp"
    #     ]
    # }  
}
