# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  skip_provider_registration = true # This is only required when the User, Service Principal, or Identity running Terraform lacks the permissions to register Azure Resource Providers.
  features {}
}


resource "azurerm_resource_group" "mtc-rg" {
  name     = "mtc-resources"
  location = "Australia East"
  tags = {
    environment = "dev"

  }
}

resource "azurerm_virtual_network" "mtc-vn" {
  name                = "mtc-network"
  resource_group_name = azurerm_resource_group.mtc-rg.name
  location            = azurerm_resource_group.mtc-rg.location
  address_space       = ["10.123.0.0/16"]

  tags = {
    environment = "dev"

  }

}

resource "azurerm_subnet" "mtc-subnet" {
  name                 = "mtc-subnet"
  resource_group_name  = azurerm_resource_group.mtc-rg.name
  virtual_network_name = azurerm_virtual_network.mtc-vn.name
  address_prefixes     = ["10.123.1.0/24"]

}

resource "azurerm_network_security_group" "mtc-sg" {
  name                = "mtc-sg"
  location            = azurerm_resource_group.mtc-rg.location
  resource_group_name = azurerm_resource_group.mtc-rg.name

  tags = {
    environment = "dev"
  }


}
resource "azurerm_network_security_rule" "mtc-dev-rule" {
  name                        = "mtc-dev-rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.mtc-rg.name
  network_security_group_name = azurerm_network_security_group.mtc-sg.name
}

resource "azurerm_subnet_network_security_group_association" "mtc-sga" {
  subnet_id                 = azurerm_subnet.mtc-subnet.id
  network_security_group_id = azurerm_network_security_group.mtc-sg.id
}



resource "azurerm_public_ip" "mtc-ip" {
  name                = "mtc-ip"
  resource_group_name = azurerm_resource_group.mtc-rg.name
  location            = azurerm_resource_group.mtc-rg.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "dev"
  }
}

#7

resource "azurerm_network_interface" "mtc-nic" {
  name                = "mtc-inc"
  location            = azurerm_resource_group.mtc-rg.location
  resource_group_name = azurerm_resource_group.mtc-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.mtc-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mtc-ip.id


  }
  tags = {
    environment = "dev"
  }
}

#8 Create ssh-keygen first  throuth terminal by  using command ssh-keygen -t rsa
#Check your rsa key  byusing command ls ~/.ssh

resource "azurerm_linux_virtual_machine" "mtc-vm" {
  name                = "mtc-vm"
  resource_group_name = azurerm_resource_group.mtc-rg.name
  location            = azurerm_resource_group.mtc-rg.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.mtc-nic.id,
  ]

  #create a file  named customdata.tpl via VS explorer
  #calling the file using below

  custom_data = filebase64("customdata.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/mtcazurekey.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }


  #9 - Provisioner

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-script.tpl", {
      hostname     = self.public_ip_address,
      user         = "adminuser",
      identityfile = "~/.ssh/mtcazurekey"


    })

    interpreter = var.host_os == "windows" ? ["Powershell", "-Command"] : ["bash", "-c"]

    #interpreter = ["Powershell", "-Command"] #for windows 
    #interpreter =["bash","-c"] #for Linux or MAC


  }


  tags = {
    environment = "dev"
  }



}

#9.2  Query to get the Ip address of the VM we created.
data "azurerm_public_ip" "mtc-ip-data" {
  name                = azurerm_public_ip.mtc-ip.name
  resource_group_name = azurerm_resource_group.mtc-rg.name
}

#10 Output Values
output "public_ip_address" {
  value = "${azurerm_linux_virtual_machine.mtc-vm.name}: ${data.azurerm_public_ip.mtc-ip-data.ip_address}"
}



#check the vm were created using the command terraform state  list 
#check if the vm  you created has a public ip using the command  terraform state show azurerm_linux_virtual_machine.mtc-vm    
#try to connect  to vm using command ssh -i ~/.ssh/mtcazurekey adminuser@104.210.93.78
#check the OS  version using  command  lsb_release -a \
#check the Docker   version using  command   docker --version
#install ssh remote using Exntesions at the VS Explorer
# Use  Provisioner
#9.2  Query to get the Ip address of the VM we created.
#10 Output Values
# Create variables.tf
#Create a terraform.tfvars 
#to by pass/overide  variables.tf use terraform console -var=host_os="linux"
#Create a osx.tfvars 
#to by pass/overide terraforms.tfvars use terraform console  -var-file="osx.tfvars"
 
