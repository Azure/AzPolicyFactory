# Policy Integration Test - Sample Test Cases for Azure App Services and Function Apps

## Introduction

This folder contains a sample test case for Azure App Services and Function Apps related policies.

The test case is designed to test the following policy assignments:

| Policy Assignment Name | Policy Assignment Scope | Description |
| :--------------------- | :--------------------- | :---------- |
| `pa-d-web` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for the Azure App Services and Function Apps initiative |
| `pa-d-pedns` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for Azure Private Endpoint DNS Records Policy Initiative (deploy DNS records for Private Endpoints) |
| `pa-d-diag-settings` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for Azure Diagnostic Settings Policy Initiative (deploy diagnostic settings for all applicable Azure resources) |

The following policies are in scope for testing:

| Policy Assignment | Policy Reference ID | Policy Name | Policy Effect |
| :---------------- | :---------------- | :------------ | :------------ |
| `pa-d-diag-settings` | `DS-026` | Configure Diagnostic Settings for Function App | `DeployIfNotExists` |
| `pa-d-diag-settings` | `DS-062` | Configure Diagnostic Settings for App Services | `DeployIfNotExists` |
| `pa-d-pedns` | `PEDNS-006` | Configure Private DNS Record for Web App Private Endpoint | `DeployIfNotExists` |
| `pa-d-pedns` | `PEDNS-015` | Configure Private DNS Record for Web App Slots Private Endpoint | `DeployIfNotExists` |
| `pa-d-web` | `WEB-001` | App Service and function app slots should only be accessible over HTTPS | `Deny` |
| `pa-d-web` | `WEB-002` | App Service and Function apps should only be accessible over HTTPS | `Deny` |
| `pa-d-web` | `WEB-003` | Function apps should only use approved identity providers for authentication | `Deny` |
| `pa-d-web` | `WEB-004` | Prevent cross-subscription Private Link for App Services and Function Apps | `Audit` |
| `pa-d-web` | `WEB-005` | Function apps should route application traffic over the virtual network | `Deny` |
| `pa-d-web` | `WEB-006` | App Service and Function apps should route configuration traffic over the virtual network | `Deny` |
| `pa-d-web` | `WEB-007` | Function apps should route configuration traffic over the virtual network | `Deny` |
| `pa-d-web` | `WEB-008` | Function app slots should route configuration traffic over the virtual network | `Deny` |
| `pa-d-web` | `WEB-009` | App Service apps should use a SKU that supports private link | `Deny` |
| `pa-d-web` | `WEB-010` | Public network access should be disabled for App Services and Function Apps | `Deny` |
| `pa-d-web` | `WEB-011` | Public network access should be disabled for App Service and Function App slots | `Deny` |
