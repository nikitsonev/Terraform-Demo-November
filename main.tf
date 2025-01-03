terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.11.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "StorageRG"
    storage_account_name = "taskboardstorageniki"
    container_name       = "taskboardstoragenikicontainer"
    key                  = "terraform.tfstate"

  }
}

provider "azurerm" {
  # Configuration options
  subscription_id = "00899b68-f574-4ee8-8ed8-ad26f06dc149"
  features {

  }
}

resource "random_integer" "ri" {
  min = 10000
  max = 99999

}

resource "azurerm_resource_group" "dimorg" {
  name = "${var.resource_group_name}-${random_integer.ri.result}"
  //name = var.resource_group_name
  location = var.resource_group_location
}

resource "azurerm_service_plan" "dimoasp" {
  name                = "${var.app_service_plan_name}-${random_integer.ri.result}"
  resource_group_name = azurerm_resource_group.dimorg.name
  location            = azurerm_resource_group.dimorg.location
  os_type             = "Linux"
  sku_name            = "F1"
}

resource "azurerm_linux_web_app" "dimoalwa" {
  name                = "${var.app_service_name}${random_integer.ri.result}"
  resource_group_name = azurerm_resource_group.dimorg.name
  location            = azurerm_resource_group.dimorg.location
  service_plan_id     = azurerm_service_plan.dimoasp.id

  site_config {
    application_stack {
      dotnet_version = "6.0"
    }
    always_on = false
  }

  connection_string {
    name  = "DefaultConnection"
    type  = "SQLAzure"
    value = "Data Source=tcp:${azurerm_mssql_server.sqlserverniki.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.nikidatabase.name};User ID=${azurerm_mssql_server.sqlserverniki.administrator_login};Password=${azurerm_mssql_server.sqlserverniki.administrator_login_password};Trusted_Connection=False; MultipleActiveResultSets=True;"
  }

}

resource "azurerm_mssql_server" "sqlserverniki" {
  name                         = var.sql_server_name
  resource_group_name          = azurerm_resource_group.dimorg.name
  location                     = azurerm_resource_group.dimorg.location
  version                      = "12.0"
  administrator_login          = var.sql_user
  administrator_login_password = var.sql_user_pass
}

resource "azurerm_mssql_database" "nikidatabase" {
  name           = var.sql_database_name
  server_id      = azurerm_mssql_server.sqlserverniki.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 2
  zone_redundant = false
  sku_name       = "S0"
}

resource "azurerm_mssql_firewall_rule" "dimofirewall" {
  name             = var.firewall_rule
  server_id        = azurerm_mssql_server.sqlserverniki.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_app_service_source_control" "github" {
  app_id                 = azurerm_linux_web_app.dimoalwa.id
  repo_url               = var.github_repo
  branch                 = "main"
  use_manual_integration = true
}

