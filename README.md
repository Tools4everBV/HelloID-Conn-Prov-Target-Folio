
# HelloID-Conn-Prov-Target-Folio

| :information_source: Information          |
| :---------------------------------------- |
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements. |

<p align="center">
  <img src="https://folio.org/wp-content/uploads/2023/08/folio-site-general-Illustration-social-image-1200.jpg" width="500" >
</p>

## Table of contents

- [HelloID-Conn-Prov-Target-Folio](#helloid-conn-prov-target-folio)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Getting started](#getting-started)
    - [Provisioning PowerShell V2 connector](#provisioning-powershell-v2-connector)
      - [Correlation configuration](#correlation-configuration)
      - [Field mapping](#field-mapping)
    - [Connection settings](#connection-settings)
    - [Prerequisites](#prerequisites)
    - [Remarks](#remarks)
  - [Setup the connector](#setup-the-connector)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Target-Folio_ is a _target_ connector. _Folio_ provides a set of REST API's that allow you to programmatically interact with its data.

The following lifecycle actions are available:

| Action          | Description                                   |
| --------------- | --------------------------------------------- |
| create.ps1      | Create and/or correlate the Account           |
| update.ps1      | Update the Account                            |
| enable.ps1      | Enable the Account                            |
| disable.ps1     | Disable the Account                           |
| delete.ps1      | Delete the Account                            |
| permissions.ps1 | Included in the create script *(See Remarks)* |
| grant.ps1       | N/a                                           |
| revoke.ps1      | N/a                                           |

## Getting started

### Provisioning PowerShell V2 connector

#### Correlation configuration

The correlation configuration is used to specify which properties will be used to match an existing account within _Folio_ to a person in _HelloID_.

To properly set up the correlation:

1. Open the `Correlation` tab.

2. Specify the following configuration:

    | Setting                   | Value                                                  |
    | ------------------------- | ------------------------------------------------------ |
    | Enable correlation        | `True`                                                 |
    | Person correlation field  | `Person.ExternalId`                                    |
    | Account correlation field | `externalSystemID` (EmployeeNumber or StrudentNumber) |

### Connection settings

The following settings are required to connect to the API.

| Setting        | Description                               | Mandatory |
| -------------- | ----------------------------------------- | --------- |
| UserName       | The UserName to connect to the API        | Yes       |
| Password       | The Password to connect to the API        | Yes       |
| X-OKAPI-TENANT | The  X-OKAPI-TENANT to connect to the API | Yes       |
| BaseUrl        | The URL to the API                        | Yes       |

### Prerequisites

### Remarks
- The connector is created to handle two types of accounts: Staff and Patron. Distinguishing between these account types is accomplished through mapping. In the connector example, this differentiation is achieved by checking the Source System. If the system is identified as AFAS, the account is categorized as Staff; otherwise, it is categorized as a Patron.
- Additionally, a similar approach is taken for the "permission group." There are two Folio groups—one applicable to **All** employees and the other to **All** patrons. The logic is similar. The GUID of the group can be obtained from the other accounts.
- There are some encoding issues on a **Local agent (PowerShell 5.1)**. Normal diacritics pose no problem, but, for example, the letter Ł is not received correctly. This can be solved by appending the Invoke-WebRequest with:  `-OutFile '.\response.json'; (gc .\response.json -Encoding UTF8) | ConvertFrom-Json`.  However, this issue does not occur on the cloud agent.
- To enable or disable a user, there are two additional fields available, namely `enrollmentDate` and `expirationDate`, which are currently not implemented. It appears that both fields are not necessary to deactivate or activate the account. They need to be added during implementation.



## Setup the connector

> _How to setup the connector in HelloID._ Are special settings required. Like the _primary manager_ settings for a source connector.

## Getting help

> ℹ️ _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages_

> ℹ️ _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/


