# Policy Integration Test - Policy Integration Test Cases for xxx

## Introduction

This folder contains a sample test case for xxx related policies.

The test case is designed to test the following policy assignments:

| Policy Assignment Name | Policy Assignment Scope | Description |
| :--------------------- | :--------------------- | :---------- |
| `pa-d-search` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for the Azure Search Service initiative |
| `pa-d-pedns` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for Azure Private Endpoint DNS Records Policy Initiative (deploy DNS records for Private Endpoints) |
| `pa-d-diag-settings` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for Azure Diagnostic Settings Policy Initiative (deploy diagnostic settings for all applicable Azure resources) |

The following policies are in scope for testing:

| Policy Assignment | Policy Reference ID | Policy Name | Policy Effect |
| :---------------- | :---------------- | :------------ | :------------ |
| `pa-d-search` | `SRCH-001` | Azure AI Search service should use a SKU that supports private link | Deny |
| `pa-d-search` | `SRCH-002` | Configure Azure AI Search services to disable local authentication | Modify |
| `pa-d-search` | `SRCH-003` | Azure AI Search services should restrict public network access | Deny |
| `pa-d-diag-settings` | `DS-045` | Configure Diagnostic Setting for Azure Search Service | DeployIfNotExists |
| `pa-d-pedns` | `PEDNS-017` | Private DNS Record for Azure Search Service Private Endpoint must exist | DeployIfNotExists |
