# Policy Integration Test - Sample Test Cases for Virtual Network

## Introduction

This folder contains a sample test case for Virtual Network related policies.

The test case is designed to test the following policy assignments:

| Policy Assignment Name | Policy Assignment Scope | Description |
| :--------------------- | :--------------------- | :---------- |
| `pa-d-vnet` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for the Azure Virtual Network initiative |
| `pa-d-diag-settings` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for Azure Diagnostic Settings Policy Initiative (deploy diagnostic settings for all applicable Azure resources) |


The following policies are in scope for testing:

| Policy Assignment | Policy Reference ID | Policy Name | Policy Effect |
| :---------------- | :---------------- | :------------ | :------------ |
| `pa-d-vnet` | `VNET-001` | Gateway Subnet should not have Network Security Group associated | `Deny` |
| `pa-d-vnet` | `VNET-002` | Subnets should be associated with a Network Security Group | `Deny` |
| `pa-d-vnet` | `VNET-003` | VNet Flow Log must be enabled in Australia East | `DeployIfNotExists` |
| `pa-d-vnet` | `VNET-004` | VNet Flow Log must be enabled in Australia Southeast| `DeployIfNotExists` |
| `pa-d-diag-settings` | `DS-058` | Diagnostic Settings for Virtual Network Must Be Configured | `DeployIfNotExists` |
