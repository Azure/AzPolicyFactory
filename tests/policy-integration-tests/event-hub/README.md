# Policy Integration Test - Sample Test Cases for Azure Event Hub

## Introduction

This folder contains a sample test case for Azure Event Hub related policies.

The test case is designed to test the following policy assignments:

| Policy Assignment Name | Policy Assignment Scope | Description |
| :--------------------- | :--------------------- | :---------- |
| `pa-d-eh` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for the Azure Event Hub initiative |
| `pa-d-pedns` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for Azure Private Endpoint DNS Records Policy Initiative (deploy DNS records for Private Endpoints) |
| `pa-d-diag-settings` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for Azure Diagnostic Settings Policy Initiative (deploy diagnostic settings for all applicable Azure resources) |


The following policies are in scope for testing:

| Policy Assignment | Policy Reference ID | Policy Name | Policy Effect |
| :---------------- | :---------------- | :------------ | :------------ |
| `pa-d-eh` | `EH-001` | Restrict Event Hub Local Authentication | `Deny` |
| `pa-d-eh` | `EH-002` | Restrict Event Hub Minimum TLS version | `Deny` |
| `pa-d-eh` | `EH-003` | Event Hub Event Hub Restrict Public Network Access | `Deny` |
| `pa-d-eh` | `EH-004` | Event Hub Namespace should use CMK encryption | `Audit` |
| `pa-d-eh` | `EH-005` | Event Hub Namespace should use Private Endpoint | `AuditIfNotExists` |
| `pa-d-pedns` | `PEDNS-007` | Private DNS Record for Event Hub PE must exist | `DeployIfNotExists` |
| `pa-d-diag-settings` | `DS-022` | Diagnostic Settings for Event Hub Must Be Configured | `DeployIfNotExists` |
