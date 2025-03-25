# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.22.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = ""
  client_id       = ""
  client_secret   = ""
  tenant_id       = ""
}

resource "azurerm_resource_group" "rg" {
  name     = "terra-rg-v2"
  location = "centralindia"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "tf_mssvnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  address_space       = ["10.0.0.0/16"]
}
resource "azurerm_subnet" "subnet" {
  name                 = "tf_subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "pip" {
  name                = "PublicIPForLB"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  domain_name_label   = "mikkyfqdn3"
}

resource "azurerm_lb" "lb" {
  name                = "FlexLoadBalancer"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "bpepool" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "BackEndAddressPool"
}

resource "azurerm_lb_probe" "lbprobe" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "ssh-running-probe"
  port            = var.backend_port
}

resource "azurerm_lb_rule" "lbnatrule" {
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "lbrule1"
  protocol                       = "Tcp"
  frontend_port                  = var.frontend_port
  backend_port                   = var.backend_port
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.bpepool.id]
  frontend_ip_configuration_name = "PublicIPAddress"
  probe_id                       = azurerm_lb_probe.lbprobe.id
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_nat_rule

 resource "azurerm_lb_nat_rule" "inboundnatrulev2" {
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.lb.id
  backend_ip_configuration_id    = null
  backend_address_pool_id = azurerm_lb_backend_address_pool.bpepool.id
  name                           = "RDPAccess"
  protocol                       = "Tcp"
  backend_port                   = 3389 
  enable_floating_ip             = false
  frontend_port_end              = 2605
  frontend_port_start            = 2500
  enable_tcp_reset               = false
  idle_timeout_in_minutes        = 4
  frontend_ip_configuration_name = "PublicIPAddress"
}

resource "azurerm_orchestrated_virtual_machine_scale_set" "vmss" {
  name                = "mikkyvmss"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku_name            = "Mix"
  instances           = 3
  platform_fault_domain_count =3

  sku_profile {
    allocation_strategy = "CapacityOptimized"
    vm_sizes            = ["Standard_D4s_v3"]
    
  }

  os_profile {
    windows_configuration {
      admin_username           = var.admin_username
      admin_password           = var.admin_password
      computer_name_prefix     = "mikkyflex"
      enable_automatic_updates = true
    }
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-datacenter-gensecond"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Premium_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name                          = "flex_networkinterface"
    primary                       = true
    enable_accelerated_networking = true

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.subnet.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bpepool.id]
      
      # load_balancer_inbound_nat_rule_ids = [azurerm_lb_nat_rule.rule.id]

      version = "IPv4"
    }
  }
}
