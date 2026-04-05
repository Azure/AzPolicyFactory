# Policy Integration Test - Sample Test Cases for Azure Private Endpoint

## Introduction

This folder contains a sample test case for Azure Private Endpoint related policies.

The test case is designed to test the following policy assignments:

| Policy Assignment Name | Policy Assignment Scope | Description |
| :--------------------- | :--------------------- | :---------- |
| `pa-d-pe-lz` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV-LandingZones` | Policy Assignment for the Azure Private Endpoint initiative |

The following policies are in scope for testing:

| Policy Assignment | Policy Reference ID | Policy Name | Policy Effect |
| :---------------- | :---------------- | :------------ | :------------ |
| `pa-d-pe-lz` | `PE-002` | AMPLS Private Endpoints Policy violating deployment should fail | `Deny` |
