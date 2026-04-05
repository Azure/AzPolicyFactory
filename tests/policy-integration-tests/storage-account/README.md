# Policy Integration Test - Sample Test Cases for Storage Account

## Introduction

This folder contains a sample test case for Azure Storage Account related policies.

The test case is designed to test the following policy assignments:

| Policy Assignment Name | Policy Assignment Scope | Description |
| :--------------------- | :--------------------- | :---------- |
| `pa-d-storage` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for the Azure Storage Account initiative |
| `pa-d-pedns` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for Azure Private Endpoint DNS Records Policy Initiative (deploy DNS records for Private Endpoints) |
| `pa-d-diag-settings` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for Azure Diagnostic Settings Policy Initiative (deploy diagnostic settings for all applicable Azure resources) |
| `pa-d-tags` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for resource tags initiative |


The following policies are in scope for testing:

| Policy Assignment | Policy Reference ID | Policy Name | Policy Effect |
| :---------------- | :---------------- | :------------ | :------------ |
| `pa-d-tags` | `TAG-010` | Inherit the tag from the Resource Group to Resource if missing (dataclass) | `Modify` |
| `pa-d-tags` | `TAG-011` | Inherit the tag from the Resource Group to Resource if missing (owner) | `Modify` |
| `pa-d-storage` | `STG-006` | Storage accounts should prevent cross tenant object replication | `Deny` |
| `pa-d-storage` | `STG-007` | Storage accounts should prevent shared key access | `Audit` |
| `pa-d-storage` | `STG-008` | Secure transfer to storage accounts should be enabled | `Deny` |
| `pa-d-storage` | `STG-009` | Restrict Storage Account with public network access | `Deny` |
| `pa-d-storage` | `STG-010` | Storage accounts should have the specified minimum TLS version | `Deny` |
| `pa-d-storage` | `STG-012` | Storage accounts should prevent permitted copy scopes from any storage accounts | `Deny` |
| `pa-d-pedns` | `PEDNS-002` | Private DNS Record for Storage Blob PE must exist | `DeployIfNotExists` |
| `pa-d-diag-settings` | `DS-052` | Diagnostic Settings for Storage Account Must Be Configured | `DeployIfNotExists` |
