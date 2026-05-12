# Policy Integration Test - Policy Integration Test Cases for Cognitive Service

## Introduction

This folder contains a sample test case for Cognitive Service related policies.

The test case is designed to test the following policy assignments:

| Policy Assignment Name | Policy Assignment Scope | Description |
| :--------------------- | :--------------------- | :---------- |
| `pa-d-cog-service` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for the Azure Cognitive Service initiative |
| `pa-d-pedns` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for Azure Private Endpoint DNS Records Policy Initiative (deploy DNS records for Private Endpoints) |
| `pa-d-diag-settings` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for Azure Diagnostic Settings Policy Initiative (deploy diagnostic settings for all applicable Azure resources) |

The following policies are in scope for testing:

| Policy Assignment | Policy Reference ID | Policy Name | Policy Effect |
| :---------------- | :---------------- | :------------ | :------------ |
| `pa-d-cog-service` | `COG-001` | Cognitive Service accounts should have local authentication disabled | Deny |
| `pa-d-cog-service` | `COG-002` | Cognitive Services accounts should restrict public network access | Deny |
| `pa-d-cog-service` | `COG-003` | Cognitive Services accounts should use a managed identity | Deny |
| `pa-d-cog-service` | `COG-004` | Cognitive Services accounts should use customer owned storage | Deny |
| `pa-d-cog-service` | `COG-005` | Cognitive Services Deployments allowed model formats | Deny |
| `pa-d-cog-service` | `COG-006` | Cognitive Services Deployments should only use approved Models from OpenAI | Deny |
| `pa-d-cog-service` | `COG-007` | Cognitive Services Deployments should only use approved Models from xAI | Deny |
| `pa-d-diag-settings` | `DS-013` | Configure Diagnostic Setting for Azure Cognitive Services | DeployIfNotExists |
| `pa-d-pedns` | `PEDNS-016` | Private DNS Record for Azure Cognitive Services PE must exist | DeployIfNotExists |
