# This Template creates a Linux & Windows10 VM(s) and the associated Azure network infrastructure - JPearse (Microsoft)
#
# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "TerraformDemo" {
    name     = "TerraformDemo"
    location = "westeurope"

    tags = {
        environment = "Demo"
        Lab = "Terraform"
        creation = "${timestamp()}"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
    name                = "vNet-Core-Demo"
    address_space       = ["10.2.0.0/16"]
    location            = "westeurope"
    resource_group_name = "${azurerm_resource_group.TerraformDemo.name}"

    tags = {
        environment = "Demo"
        lab = "Terraform"
        creation = "${timestamp()}"
    }
}

# Create subnet(s)
resource "azurerm_subnet" "AzureBastionSubnet" {
    name                 = "AzureBastionSubnet"
    resource_group_name  = "${azurerm_resource_group.TerraformDemo.name}"
    virtual_network_name = "${azurerm_virtual_network.myterraformnetwork.name}"
    address_prefix       = "10.2.1.0/27"
}

resource "azurerm_subnet" "Frontend" {
    name                 = "Frontend"
    resource_group_name  = "${azurerm_resource_group.TerraformDemo.name}"
    virtual_network_name = "${azurerm_virtual_network.myterraformnetwork.name}"
    address_prefix       = "10.2.2.0/24"
}

resource "azurerm_subnet" "Backend" {
    name                 = "Backend"
    resource_group_name  = "${azurerm_resource_group.TerraformDemo.name}"
    virtual_network_name = "${azurerm_virtual_network.myterraformnetwork.name}"
    address_prefix       = "10.2.3.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "LinuxPublicIP" {
    name                         = "LinuxPublicIP"
    location                     = "westeurope"
    resource_group_name          = "${azurerm_resource_group.TerraformDemo.name}"
    allocation_method            = "Dynamic"

    tags = {
        environment = "Demo"
        lab = "Terraform"
        creation = "${timestamp()}"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
    name                = "Frontend-NSG"
    location            = "westeurope"
    resource_group_name = "${azurerm_resource_group.TerraformDemo.name}"
    
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "RDP"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "3389"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Demo"
        lab = "Terraform"
        creation = "${timestamp()}"
    }
}

resource "azurerm_subnet_network_security_group_association" "myterraformnsg" {
  subnet_id                 = "${azurerm_subnet.Frontend.id}"
  network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"
}

# Create network interface(s)

# Linux VM
resource "azurerm_network_interface" "LinuxNIC" {
    name                      = "LinuxNIC"
    location                  = "westeurope"
    resource_group_name       = "${azurerm_resource_group.TerraformDemo.name}"
    network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = "${azurerm_subnet.Frontend.id}"
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = "${azurerm_public_ip.myterraformpublicip.id}"
    }

    tags = {
        environment = "Demo"
        lab = "Terraform"
        creation = "${timestamp()}"
    }
}

# Windows 10

resource "azurerm_network_interface" "Win10NIC" {
    name                      = "Win10NIC"
    location                  = "westeurope"
    resource_group_name       = "${azurerm_resource_group.TerraformDemo.name}"
    network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = "${azurerm_subnet.Frontend.id}"
        private_ip_address_allocation = "Dynamic"
    }

    tags = {
        environment = "Demo"
        lab = "Terraform"
        creation = "${timestamp()}"
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${azurerm_resource_group.TerraformDemo.name}"
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = "${azurerm_resource_group.TerraformDemo.name}"
    location                    = "westeurope"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "Demo"
        lab = "Terraform"
        creation = "${timestamp()}"
    }
}

# Create virtual machine(s)
#
# Windows 10
resource "azurerm_virtual_machine" "win10client" {
    name                           = "Win10"
    location                       = "westeurope"
    resource_group_name            = "${azurerm_resource_group.TerraformDemo.name}"
    network_interface_ids          = ["${azurerm_network_interface.Win10NIC.id}"]
    vm_size                        = "Standard_DS1_v2"
    delete_os_disk_on_termination  = "True"
 
    storage_os_disk {
   	    name              = "Win10Disk"
   	    caching           = "ReadWrite"
   	    create_option     = "FromImage"
    	managed_disk_type = "Premium_LRS"
    	os_type           = "Windows"
    }
 
   storage_image_reference {
    	publisher = "MicrosoftWindowsDesktop"
    	offer     = "Windows-10"
    	sku       = "rs5-pro"
    	version   = "17763.253.65"
    }
 
  os_profile {
   	    computer_name  = "Windows10"
    	admin_username = "azureuser"
    	admin_password = "Nursling18jp"
    }
 
  os_profile_windows_config {
    	enable_automatic_upgrades = true
    	provision_vm_agent = true
    }
 
  boot_diagnostics {
        enabled     = true
        storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
    }

    tags = {
        environment = "Demo"
        lab = "Terraform"
        creation = "${timestamp()}"
    }
}

# Linux (Ubuntu)

resource "azurerm_virtual_machine" "LinuxVM" {
    name                  = "Prod-LinuxVM"
    location              = "westeurope"
    resource_group_name   = "${azurerm_resource_group.TerraformDemo.name}"
    network_interface_ids = ["${azurerm_network_interface.LinuxNIC.id}"]
    vm_size               = "Standard_DS1_v2"

    storage_os_disk {
        name              = "LinuxOsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "TerraFormLinuxVM"
        admin_username = "azureuser"
        admin_password = "Nursling18jp"
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
    }

    tags = {
        environment = "Demo"
        lab = "Terraform"
        creation = "${timestamp()}"
    }

}