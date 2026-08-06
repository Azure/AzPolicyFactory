# Policy Integration Test - Policy Integration Test Cases for Azure Kubernetes Service

## Introduction

This folder contains a sample test case for Azure Kubernetes Service (AKS) related policies.

The test case is designed to test the following policy assignments:

| Policy Assignment Name | Policy Assignment Scope | Description |
| :--------------------- | :--------------------- | :---------- |
| `pa-d-aks-control` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for the Azure Kubernetes Service Control Plane Policy Initiative |
| `pa-d-diag-settings` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for Azure Diagnostic Settings Policy Initiative (deploy diagnostic settings for all applicable Azure resources) |

The following policies are in scope for testing:

| Policy Assignment | Policy Reference ID | Policy Name | Policy Effect |
| :---------------- | :---------------- | :------------ | :------------ |
| `pa-d-aks-control` | `AKSC-001` | Azure Policy Add-on for Kubernetes service (AKS) should be installed and enabled on your clusters | Deny |
| `pa-d-aks-control` | `AKSC-002` | Azure Kubernetes Clusters should use Azure CNI Overlay | Deny |
| `pa-d-aks-control` | `AKSC-003` | Azure Kubernetes Service Private Clusters should be enabled | Deny |
| `pa-d-aks-control` | `AKSC-004` | Azure Kubernetes Service clusters should have Defender profile enabled | Deny |
| `pa-d-aks-control` | `AKSC-005` | Temp disks and cache for agent node pools in Azure Kubernetes Service clusters should be encrypted at host | Deny |
| `pa-d-aks-control` | `AKSC-006` | Azure Kubernetes Service Clusters should have local authentication methods disabled | Deny |
| `pa-d-aks-control` | `AKSC-007` | Role-Based Access Control (RBAC) should be used on Kubernetes Services | Deny |
| `pa-d-aks-control` | `AKSC-008` | Azure Kubernetes Clusters should enable Container Storage Interface(CSI) | Deny |
| `pa-d-aks-control` | `AKSC-009` | Azure Kubernetes Service Clusters should disable Command Invoke | Deny |
| `pa-d-aks-control` | `AKSC-010` | Azure Kubernetes Service Clusters should enable Entra ID integration" | Deny |
| `pa-d-aks-control` | `AKSC-011` | Azure Kubernetes Service Clusters should use managed identities | Deny |
| `pa-d-aks-control` | `AKSC-012` | Azure Kubernetes Service Clusters must not be created using a preview ARM API version | Deny |
| `pa-d-diag-settings` | `DS-004` | Configure Diagnostic Setting for AKS | DeployIfNotExists |
