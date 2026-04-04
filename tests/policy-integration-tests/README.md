# Azure Policy Integration Tests

## Overview

This directory contains integration tests for Azure Policy assignments. Each subfolder (except `.shared` and `test-template`) represents a test case targeting specific policy definitions or initiatives.

The `test-template` folder provides a starting point for creating new tests. Copy it, customise the configuration and templates, then define your test assertions.

## Developing a New Test

### 1. Copy the test template

Copy the `test-template` folder and rename it to reflect the policy or scenario being tested (e.g. `storage-account`, `key-vault`).

### 2. Update the local configuration (`config.json`)

Edit `config.json` in the new folder. The file supports the following properties:

| Property | Required | Description |
| :------- | :------: | :---------- |
| `policyAssignmentIds` | Yes | Array of policy assignment resource IDs to evaluate during testing. These policy assignments are the pre-requisites for the test. Test will not start until they have been initially evaluated after creation. |
| `testName` | Yes | A short name for the test case. Used in test titles and output filenames. |
| `assignmentName` | No | The name of the primary policy assignment being tested. |
| `testSubscription` | Yes | The name of the subscription (as defined in the global config `subscriptions` map) to deploy test resources into. |
| `testResourceGroup` | No | The resource group name for testing. If specified, a `$script:testResourceGroupId` variable is calculated. |
| `testManagementGroup` | No | The management group name that are used to form the policy assignment scope in the `tests.ps1` script. |
| `location` | No | Azure region for resource deployments. |
| `tagsForResourceGroup` | No | Boolean. Whether to apply tags to the test resource group. Defaults to `false`. |
| `removeTestResourceGroup` | Yes | Boolean. Whether to remove the test resource group after the test run. Defaults to `true`. |

You can also add custom properties (e.g. `diagSettingsAssignmentName`) and access them in `tests.ps1` as `$script:LocalConfig_<propertyName>`.

### 3. Define Bicep and/or Terraform templates

Depending on the policy effects you intend to test, create one or more of the following:

| File / Directory | Purpose |
|---|---|
| `main.test.bicep` | Bicep template that deploys test resources for `Audit`, `AuditIfNotExists`, `Append`, `Modify`, or `DeployIfNotExists` policies. |
| `main.bad.bicep` | Bicep template for What-If deployments that are **expected to violate** `Deny` policies. |
| `main.good.bicep` | Bicep template for What-If deployments that are **expected to comply** with policies. |
| `main-test-terraform/` | Terraform configuration that deploys test resources (equivalent to `main.test.bicep`). |
| `main-bad-terraform/` | Terraform configuration **expected to violate** `Deny` or `Audit` policies via the Policy Violation API. |
| `main-good-terraform/` | Terraform configuration **expected to comply** with policies via the Policy Violation API. |

Templates can load configuration values from the global config (`../.shared/policy_integration_test_config.jsonc`) and the local config (`config.json`). See the template files in `test-template` for examples.

### 4. Write the test script (`tests.ps1`)

The `tests.ps1` template has a pre-populated generic section (`#region generic sections for all tests`) that loads configuration and sets up variables. **Do not modify this section.**

Populate the `#region test specific configuration and tests` section with your test assertions. Build an array of test configuration objects using the helper functions from the `AzResourceTest` module (e.g. `New-ARTPropertyCountTestConfig`, `New-ARTResourceExistenceTestConfig`, `New-ARTPolicyStateTestConfig`), then pass them to `Test-ARTResourceConfiguration`.

### 5. Delete the `.testignore` file

Remove the `.testignore` file from your new test folder so the test pipeline includes it in automated runs.

## Variables Available to Tests

After the generic initialisation section in `tests.ps1` runs, the following script-scoped variables are available for use in the `#region test specific configuration and tests` section.

### Configuration Variables

All properties from the global and local config files are loaded as script-scoped variables with a prefix:

- **Global config** properties are prefixed with `GlobalConfig_`, e.g. `$script:GlobalConfig_deploymentPrefix`
- **Local config** properties are prefixed with `LocalConfig_`, e.g. `$script:LocalConfig_testResourceGroup`

### Pre-calculated Variables

| Variable | Description |
| :------- | :---------- |
| `$script:token` | Azure OAuth token for the Azure control plane API endpoint (`https://management.azure.com/`). |
| `$script:testSubscriptionId` | The subscription ID for testing, resolved from the subscription name in the local config against the global config. |
| `$script:testSubscriptionConfig` | The full subscription configuration object for the test subscription as defined in the global config. |
| `$script:testResourceGroupId` | The resource group resource ID for testing. Set only if `testResourceGroup` is defined in the local config. |
| `$script:bicepDeploymentResult` | The result object from the test Bicep template deployment (see below for schema). |
| `$script:bicepDeploymentOutputs` | The outputs from the Bicep template deployment. Empty `PSCustomObject` if no Bicep template was deployed. |
| `$script:bicepProvisioningState` | The provisioning state from the Bicep template deployment. `$null` if no Bicep template was deployed. |
| `$script:terraformDeploymentResult` | The result object from the test Terraform template deployment (see below for schema). |
| `$script:terraformDeploymentOutputs` | The outputs from the Terraform template deployment. Empty `PSCustomObject` if no Terraform template was deployed. |
| `$script:terraformProvisioningState` | The provisioning state from the Terraform template deployment. `$null` if no Terraform template was deployed. |
| `$script:testTitle` | Pester test title, set to `"<testName> Configuration Test"`. |
| `$script:contextTitle` | Pester context title, set to `"<testName> Configuration"`. |
| `$script:testSuiteName` | Test suite name for output, set to the `testName` from the local config. |
| `$script:outputFilePath` | File path for the test result output XML file. |
| `$script:whatIfComplyBicepTemplatePath` | Absolute path to the Bicep template for What-If deployments expected to **comply** with the policy. |
| `$script:whatIfViolateBicepTemplatePath` | Absolute path to the Bicep template for What-If deployments expected to **violate** the policy. |
| `$script:testTerraformDirectoryPath` | Absolute path to the directory containing the Terraform configuration used for testing. |
| `$script:terraformBackendStateFileDirectory` | Directory path for the Terraform backend state file (`<testDir>/tf-state`). |
| `$script:terraformViolateDirectoryPath` | Absolute path to the Terraform configuration expected to **violate** deny or audit policies. |
| `$script:terraformComplyDirectoryPath` | Absolute path to the Terraform configuration expected to **comply** with the policy. |
| `$env:ARM_SUBSCRIPTION_ID` | Environment variable for Terraform authentication, set to the test subscription ID. |

### `$script:bicepDeploymentResult` Schema

When **no** Bicep templates were deployed:

| Property | Description |
|---|---|
| `bicepRemoveTestResourceGroup` | Boolean indicating whether to remove the test resource group. |
| `bicepTestSubscriptionId` | The subscription ID for testing. |
| `bicepTestResourceGroup` | The resource group name for testing. |

When a Bicep template **is** deployed, the object also includes:

| Property | Description |
|---|---|
| `bicepDeploymentOutputs` | The outputs from the Bicep template deployment. |
| `bicepProvisioningState` | The provisioning state from the Bicep template deployment. |
| `bicepDeploymentTarget` | The deployment target, usable for policy evaluation via the Policy Insights API or Policy Violation API. |

### `$script:terraformDeploymentResult` Schema

When **no** Terraform templates were deployed:

| Property | Description |
|---|---|
| `terraformDeployment` | `false` — no Terraform deployment was performed. |

When a Terraform template **is** deployed:

| Property | Description |
|---|---|
| `terraformDeployment` | `true` — Terraform deployment was performed. |
| `terraformDeploymentOutputs` | The outputs from the Terraform template deployment. |
| `terraformProvisioningState` | The provisioning state from the Terraform template deployment. |

## Prerequisites

- Policy assignments under test are already created and have completed initial evaluation in the target Azure environment.
- Azure PowerShell modules installed: `Az.Accounts`, `Az.PolicyInsights`, `Az.Resources`.
- PowerShell 7.0 or later.
- The `AzResourceTest` PowerShell module installed.
- Bicep CLI installed (if using Bicep templates).
- Terraform installed (if using Terraform templates).
- Azure CLI installed and signed in (if using Terraform templates).
- Signed in to Azure via `Connect-AzAccount`.
- The executing identity has permissions to deploy resources in the target subscription and at least `Reader` on the tenant root management group.

## Running the Tests

Tests are executed automatically by the Azure Policy integration test pipelines in Azure DevOps. Each test folder (that does not contain a `.testignore` file) is picked up and run as part of the pipeline.

## Folder Structure

```text
tests/policy-integration-tests/
├── .shared/                           # Shared config and initiation script
│   ├── policy_integration_test_config.jsonc   # Global test configuration
│   └── initiate-test.ps1              # Test initialisation script
├── test-template/                     # Template for new tests — copy this
│   ├── .testignore                    # Marker to exclude from pipeline runs
│   ├── config.json                    # Local test configuration
│   ├── main.test.bicep                # Bicep template for resource deployment
│   ├── main.good.bicep                # Bicep template expected to comply
│   ├── main.bad.bicep                 # Bicep template expected to violate
│   ├── main-test-terraform/           # Terraform config for resource deployment
│   ├── main-bad-terraform/            # Terraform config expected to violate
│   └── tests.ps1                      # Test script
├── acr/                               # Example: ACR policy tests
├── ...                                # Other test cases
└── README.md                          # This file
```
