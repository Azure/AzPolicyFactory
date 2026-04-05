# Policy Integration Test - Sample Test Cases for Azure Database for PostgreSQL

## Introduction

This folder contains a sample test case for Azure Database for PostgreSQL related policies.

The test case is designed to test the following policy assignments:

| Policy Assignment Name | Policy Assignment Scope | Description |
| :--------------------- | :--------------------- | :---------- |
| `pa-d-postgresql` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for the Azure Database for PostgreSQL initiative |

The following policies are in scope for testing:

| Policy Assignment | Policy Reference ID | Policy Name | Policy Effect |
| :---------------- | :---------------- | :------------ | :------------ |
| `pa-d-postgresql` | `PGS-001` | Azure PostgreSQL flexible server should have Microsoft Entra Only Authentication enabled | `Deny` |
| `pa-d-postgresql` | `PGS-002` | Public network access should be disabled for PostgreSQL flexible servers | `Deny` |
