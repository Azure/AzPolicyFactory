# Policy Integration Test - Policy Integration Test Cases for xxx

## Introduction

This folder contains a sample test case for Azure Cosmos DB related policies.

The test case is designed to test the following policy assignments:

| Policy Assignment Name | Policy Assignment Scope | Description |
| :--------------------- | :--------------------- | :---------- |
| `pa-d-cosmos` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for the Azure Cosmos DB initiative |
| `pa-d-pedns` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for Azure Private Endpoint DNS Records Policy Initiative (deploy DNS records for Private Endpoints) |
| `pa-d-diag-settings` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for Azure Diagnostic Settings Policy Initiative (deploy diagnostic settings for all applicable Azure resources) |


The following policies are in scope for testing:

| Policy Assignment | Policy Reference ID | Policy Name | Policy Effect |
| :---------------- | :---------------- | :------------ | :------------ |
| `pa-d-cosmos` | `COSMOS-001` | Azure Cosmos DB accounts should have local authentication disabled | Modify |
| `pa-d-cosmos` | `COSMOS-002` | Azure Cosmos DB accounts should have firewall rules | Deny |
| `pa-d-cosmos` | `COSMOS-003` | Azure Cosmos DB should disable public network access | Deny |
| `pa-d-cosmos` | `COSMOS-004` | Azure Cosmos DB accounts should use customer-managed keys to encrypt data at rest | Audit |
| `pa-d-cosmos` | `COSMOS-005` | Azure Cosmos DB key based metadata write access should be disabled | Deny |
| `pa-d-cosmos` | `COSMOS-006` | Azure Cosmos DB accounts should have a minimum TLS version | Deny |
| `pa-d-cosmos` | `COSMOS-007` | Azure Cosmos DB allowed locations | Deny |
| `pa-d-diag-settings` | `DS-014` | Configure Diagnostic Setting for Azure Cosmos DB | DeployIfNotExists |
| `pa-d-pedns` | `PEDNS-017` | Private DNS Record for Azure Cosmos DB SQL PE must exist | DeployIfNotExists |
