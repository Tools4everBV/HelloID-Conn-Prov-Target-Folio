
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

#### Field mapping

| _Field_                           | _Type_              | _Mapped to value_         | Create     | Update       | Enable     | Disable    | Delete       | _Options:_                                                            | _Description_                                  |
| --------------------------------- | ------------------- | ------------------------- | ---------- | ------------ | ---------- | ---------- | ------------ | --------------------------------------------------------------------- | ---------------------------------------------- |
| _active_                          | `Fixed` <br> `None` | False    <br> ` `         | x <br> ` ` | ` ` <br> ` ` | ` ` <br> x | ` ` <br> x | ` ` <br> ` ` | - Use in notifications: `false` <br> - Store in account data:  `true` | To show the state also in the account overview |
| _barcode_                         | `Field`             | `Person.ExternalId`       | x          | x            |            |            |              | - Use in notifications: `false` <br> - Store in account data: `false` |                                                |
| _externalSystemId_                | `Field`             | `Person.ExternalId`       | x          | x            |            |            |              | - Use in notifications: `false` <br> - Store in account data: `true`  |                                                |
| id                                | `None`              |                           | x          |              |            |            |              | - Use in notifications: `false` <br> - Store in account data: `true`  |                                                |
| _patronGroup_                     | `Complex`           | `See Below`               | x          | x            |            |            |              | - Use in notifications: `false` <br> - Store in account data: `false` |                                                |
| _personal.email_                  | `Complex`           | `See Below`               | x          | x            |            |            |              | - Use in notifications: `false` <br> - Store in account data: `false` |                                                |
| _personal.firstName_              | `Field`             | `Person.Name.GivenName`   | x          | x            |            |            |              | - Use in notifications: `false` <br> - Store in account data: `false` |                                                |
| _personal.lastName_               | `Complex`           | `See Below`               | x          | x            |            |            |              | - Use in notifications: `false` <br> - Store in account data: `false` |                                                |
| _personal.middleName_             | `Field`             | `Person.FamilyNamePrefix` | x          | x            |            |            |              | - Use in notifications: `false` <br> - Store in account data: `false` |                                                |
| _personal.preferredContactTypeId_ | `Fixed`             | 002                       | x          | x            |            |            |              | - Use in notifications: `false` <br> - Store in account data: `false` | Example Type of Email                          |
| _personal.preferredFirstName      | `Field`             | `Person.Name.NickName`    | x          | x            |            |            |              | - Use in notifications: `false` <br> - Store in account data: `false` |                                                |
| _type_                            | `Complex`           | `See Below`               | x          | x            |            |            |              | - Use in notifications: `false` <br> - Store in account data: `false` |                                                |
| _username_                        | `Complex`           | `See Below`               | x          | x            |            |            |              | - Use in notifications: `false` <br> - Store in account data: `false` |                                                |


**_PatronGroup_**
```javascript
function getValue() {
    if (Person.Source.DisplayName == "AFAS") {
        return "xxxxxxxxxxxxxxx"
    } else {
        return "xxxxxxxxxxxxxxx"
    }
}
getValue();
```

**_Personal.Email_**
```javascript
function getValue() {
    return Person.Accounts.MicrosoftActiveDirectory.mail
}
getValue();
```
**_Type_**
```javascript
function getValue() {
    if (Person.Source.DisplayName == "AFAS") {
        return "staff"
    } else {
        return "patron"
    }
}
getValue();
```
**_Username_**
```javascript
function getValue() {
    return Person.Accounts.MicrosoftActiveDirectory.userPrincipalName
}
getValue();
```

**_LastName_**
Examples can be found [here](https://github.com/Tools4everBV/HelloID-Lib-Prov-HelperFunctions/tree/master/Javascript/Algorithms)
```javascript
// Please enter the mapping logic to generate the lastName based on name convention.
function generatelastName() {
    let middleName = Person.Name.FamilyNamePrefix;
    let lastName = Person.Name.FamilyName;
    let middleNamePartner = Person.Name.FamilyNamePartnerPrefix;
    let lastNamePartner = Person.Name.FamilyNamePartner;
    let convention = Person.Name.Convention;

    // B	    van den Boele
    // BP	    van den Boele - de Vries
    // P	    de Vries
    // PB	    de Vries - van den Boele

    switch (convention) {
        case "B":
            nameFormatted = '';
            if (typeof middleName !== 'undefined' && middleName) { nameFormatted = nameFormatted + ' ' + middleName }
            nameFormatted = nameFormatted + ' ' + lastName;
            break;
        case "BP":
            nameFormatted = '';
            if (typeof middleName !== 'undefined' && middleName) { nameFormatted = nameFormatted + ' ' + middleName }
            nameFormatted = nameFormatted + ' ' + lastName;

            nameFormatted = nameFormatted + ' - ';

            if (typeof middleNamePartner !== 'undefined' && middleNamePartner) { nameFormatted = nameFormatted + middleNamePartner + ' ' }
            nameFormatted = nameFormatted + lastNamePartner;
            break;
        case "P":
            nameFormatted = '';
            if (typeof middleNamePartner !== 'undefined' && middleNamePartner) { nameFormatted = nameFormatted + ' ' + middleNamePartner }
            nameFormatted = nameFormatted + ' ' + lastNamePartner;
            break;
        case "PB":
            nameFormatted = '';
            if (typeof middleNamePartner !== 'undefined' && middleNamePartner) { nameFormatted = nameFormatted + ' ' + middleNamePartner }
            nameFormatted = nameFormatted + ' ' + lastNamePartner;

            nameFormatted = nameFormatted + ' - ';

            if (typeof middleName !== 'undefined' && middleName) { nameFormatted = nameFormatted + middleName + ' ' }
            nameFormatted = nameFormatted + lastName;
            break;
        default:
            nameFormatted = '';
            if (typeof middleName !== 'undefined' && middleName) { nameFormatted = nameFormatted + ' ' + middleName }
            nameFormatted = nameFormatted + ' ' + lastName;
            break;
    }
    const lastNameFormatted = nameFormatted.trim();

    return lastNameFormatted;
}

generateLastName();
```


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


