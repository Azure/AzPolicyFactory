# Policy Integration Test - Sample Test Cases for Network Security Group

## Introduction

This folder contains a sample test case for Azure Network Security Group related policies.

The test case is designed to test the following policy assignments:

| Policy Assignment Name | Policy Assignment Scope | Description |
| :--------------------- | :--------------------- | :---------- |
| `pa-d-nsg` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for the Network Security Group initiative |
| `pa-d-diag-settings` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for Azure Diagnostic Settings Policy Initiative (deploy diagnostic settings for all applicable Azure resources) |


The following policies are in scope for testing:

| Policy Assignment | Policy Reference ID | Policy Name | Policy Effect |
| :---------------- | :---------------- | :------------ | :------------ |
| `pa-d-nsg` | `NSG-003` | Allowed list of Service Tags in Network Security Group Inbound Security Rules | `Deny` |
| `pa-d-nsg` | `NSG-004` | Allowed list of Service Tags in Network Security Group Outbound Security Rules | `Deny` |
| `pa-d-diag-settings` | `DS-038` | Diagnostic Settings for Network Security Group Must Be Configured | `DeployIfNotExists` |
