locals {
  externalIp = split(",",azurerm_app_service.app_service.outbound_ip_addresses)
}

data "azurerm_key_vault" "madriddotnet_key_vault" {
  name                = "terraformMadridDotNet"
  resource_group_name = "keyvault"
}

resource "azurerm_app_service_plan" "app_service_plan" {
  name                = var.app_service_plan_name
  location            = var.location
  resource_group_name = var.resource_group

  sku {
    tier = var.serviceplan_sku_tier
    size = var.serviceplan_sku_size
  }

   tags = var.tags
}

resource "azurerm_app_service" "app_service" {
  name                = var.webapp_url_site
  location            = var.location
  resource_group_name = var.resource_group
  app_service_plan_id = azurerm_app_service_plan.app_service_plan.id
  https_only = var.webapp_enablehttps

  site_config {
    dotnet_framework_version = "v4.0"
    scm_type                 = "LocalGit"
    default_documents = ["hostingstart.html"]
  }

  app_settings = {
    "SOME_KEY" = "some-value"
  }

  connection_string {
    name  = "Database"
    type  = "SQLServer"
    value = var.connection_string
  }
  
   identity {
    type = "SystemAssigned"
  }

   tags = var.tags
}


resource "azurerm_app_service_custom_hostname_binding" "hostname_binding" {
  hostname            = var.complete_url_site
  app_service_name    = azurerm_app_service.app_service.name
  resource_group_name = var.resource_group
  ssl_state           = var.ssl_state
  thumbprint          = var.cert_thumbprint
  
  depends_on = [dnsimple_record.simpledns_record_cname,dnsimple_record.simpledns_record_a]
}

#msi

module "eg_key_vault_access_policies_fn_apps" {
  source     = "git::https://github.com/recetasdevops/terraform-azurerm-app-service-key-vault-access-policy.git?ref=master"

  access_policy_count = 1

  identities              = azurerm_app_service.app_service.identity
  key_permissions         = ["get","list"]
  secret_permissions      = ["get","list"]
  certificate_permissions = ["get","list"]

  key_vault_name   = data.azurerm_key_vault.madriddotnet_key_vault.name
  key_vault_resource_group_name = data.azurerm_key_vault.madriddotnet_key_vault.resource_group_name
}

#certificate
resource "azurerm_app_service_certificate" "app_service_certificate" {
  name                = "pasionporlosbits-certificate"
  resource_group_name = var.resource_group
  location            = var.location
  pfx_blob            =  var.cert_pfx_base64
  password            =  var.cert_pfx_password

     depends_on = [azurerm_app_service.app_service]
}

#DNS 

resource "dnsimple_record" "simpledns_record_cname" {
  domain = var.dns_simple_domain
  name   = var.dns_simple_cname_record_name
  value  = var.url_site
  type   = "CNAME"
  ttl    = 60
}

resource "dnsimple_record" "simpledns_record_a" {
  domain = var.dns_simple_domain
  name   = ""
  value  = element(local.externalIp,0)
  type   = "A"
  ttl    = 3600
}
