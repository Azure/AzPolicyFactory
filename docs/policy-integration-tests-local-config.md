# Policy Integration Tests - Local Configuration

## Overview

The local configuration file is used to store variables that are specific to each test case. This file is created during the test execution based on the `testLocalConfigFileName` variable defined in the global configuration file.

The Local Configuration file stores test-specific settings required for the tests to run. In addition to the mandatory configurations, users can also add additional variables to the local configuration file as needed for their specific test cases.

The purpose of using a local configuration file is to allow users to define test-specific variables that are accessible in all the Azure Bicep / Terraform templates as well as the test scripts for that test case. This provides flexibility and allows users to customize the test execution based on their specific requirements.

The global configuration file is loaded at the beginning of the test execution, and the variables defined in it are available for use in all test scripts.

>:exclamation: **IMPORTANT**: All the variables are made available in the test scripts as script-based variables with the prefix `$Script:LocalConfig_`. For example, a variable named `testName` in the local configuration file can be accessed in the test scripts as `$script:LocalConfig_testName`.

## Mandatory Variables

The following mandatory variables are defined in the local configuration file:

| Name | Expected Data Type | Description | Example |
| :--- | :----------------- | :---------- | :------ |
| `policyAssignmentIds` | Yes | Array of pre-requisites policy assignment resource IDs for the test. Test will not start until they have been initially evaluated after creation. | `["/providers/Microsoft.Management/managementGroups/CONTOSO-DEV/providers/Microsoft.Authorization/policyAssignments/pa-d-pedns", "/providers/Microsoft.Management/managementGroups/CONTOSO-DEV/providers/Microsoft.Authorization/policyAssignments/pa-d-diag-settings"]` |
| `testName` | String | Name of the test case. This is used for to form the Pester test container | `storageAccount` |
| `testSubscription` | String | Name of the subscription used for testing. This should be one of the subscriptions defined in the global configuration file. | `sub-d-lz-corp-01` |
| `location` | String | Azure region where the test resources will be deployed. | `australiaeast` |

>:exclamation: **IMPORTANT**: Please ensure all above listed mandatory variables are accurately defined for each test case.

## Optional Variables

The following optional variables are defined in the local configuration file to support the sample test cases provided in this repository. These variables may not be necessary for all test cases, and users can choose to include or exclude them as needed for their specific test cases.

| Name | Expected Data Type | Description | Example |
| :--- | :----------------- | :---------- | :------ |
| `testManagementGroup` | String | Name of the management group where the policy assignment for testing is located. This is needed to construct the resource ID of the policy assignment for testing. | `CONTOSO-DEV` |
| `assignmentName` | String | Name of the policy assignment for testing. This is needed to construct the resource ID of the policy assignment for testing. | `pa-d-storage` |
| `testResourceGroup` | String | Name of the resource group to be created for testing. This resource group will be used to deploy resources during the tests. This may not be necessary for all test cases. | `rg-policy-integration-test` |
| `tagsForResourceGroup` | Boolean | Indicates whether tags should be applied to the resource group created for testing. If set to true, the tags defined in the global configuration file will be applied to the resource group. | `true` |

> :memo: **NOTE**: You may add or remove optional properties in each local configuration file as needed for your specific test cases.

## Self-defined Variables

In addition to the mandatory and optional variables listed above, you can also define your own variables in the local configuration file as needed for your specific test cases. These self-defined variables can be used to store any additional information or settings that are relevant to your test case.
