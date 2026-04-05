# Tests for Azure Policy

## Introduction

To follow the shift-left testing approach advocated by this solution, we have implemented comprehensive tests for Azure Policy resources at different stages of the CI/CD pipelines. These tests are designed to ensure the quality and correctness of the Azure Policy resources being deployed, and to provide confidence that the policies will work as expected in the target Azure environment.

## Tests

The following tests are included in the `AzPolicyFactory` solution:

### Policy Definitions and Initiatives Syntax Tests

These tests are embedded in the `Policy Definition Test` stages in the Policy Definitions and Policy Initiatives Azure DevOps pipelines and GitHub Action workflows. They perform static validation of the syntax of the policy definitions and initiatives using the open-source PowerShell Module [`AzPolicyTest`](https://www.powershellgallery.com/packages/AzPolicyTest).

These tests ensures the policy definitions and initiatives are correctly defined and follow the required schema and best practices before they are built into Bicep templates and deployed to Azure.

### Policy Assignments and Exemptions Syntax Tests

These tests are embedded in the Policy Assignments and Policy Exemptions Azure DevOps pipelines and GitHub Action workflows. They perform static validation of the syntax of the configuration files for policy assignments and exemptions using custom built Pester tests.

### Bicep Template PSRule Tests

After the bicep templates are built for each policy resource types, [PSRule for Azure](https://azure.github.io/PSRule.Rules.Azure/). are used to validate the Bicep templates ensuring they follow the best practices for Azure resources defined in PSRule.

### Bicep Template Test Deployments

After the Bicep templates are validated by PSRule, they are validated against the Azure deployment engine to ensure they can be successfully deployed.

### Policy Assignments Environment Consistency Tests

The Policy Assignments Environment Consistency Tests ADO pipeline and GitHub Action workflow validate that the policy assignments defined for production and development environments are consistent with each other to ensure the policies being tested in the development environment are the same as those being deployed to production. Any deviations between the assignments for the two environments must be explicitly defined in the configuration file.

For example, if the effect for a policy definition is set to `Deny` in development, you cannot set it to `DeployIfNotExists` in production because these 2 effects are not interchangeable.

Another Example, if you are referencing an Azure resource in the development environment, you must define the co-responding resource for production and reference it in the configuration file. if the reference of the resource in the production environment does not match what's defined in the configuration file, the test will fail.

### Policy Integration Tests

The Policy Integration Tests are designed to collectively validate each individual assigned policy in a real Azure environment where all the required policies are assigned and fully effective.

The tests work by leverage multiple Azure REST APIs to validate the resource configurations against desired state defined by the assigned policies. It supports the two most popular Infrastructure as Code languages used in Azure: Azure Bicep and Terraform.

For more information on the Policy Integration Tests, please refer to the [Policy Integration Tests ](./policy-integration-tests.md).
