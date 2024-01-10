#################################################
# HelloID-Conn-Prov-Target-Folio-Update
# PowerShell V2
# Version: 1.0.0
#################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($actionContext.Configuration.IsDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

#region functions
function Resolve-FolioError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber
            Line             = $ErrorObject.InvocationInfo.Line
            ErrorDetails     = $ErrorObject.Exception.Message
            FriendlyMessage  = $ErrorObject.Exception.Message
        }
        if ($ErrorObject.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') {
            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails.Message
        } elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            if ($null -ne $ErrorObject.Exception.Response) {
                $streamReaderResponse = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
                if ($null -ne $streamReaderResponse) {
                    $httpErrorObj.ErrorDetails = $streamReaderResponse
                }
            }
        }
        try {
            $errorDetailsObject = ($httpErrorObj.ErrorDetails | ConvertFrom-Json)
            $httpErrorObj.FriendlyMessage = "$($errorDetailsObject.errors.message) $($errorDetailsObject.errors.parameters.key)"
        } catch {
            $httpErrorObj.FriendlyMessage = $httpErrorObj.ErrorDetails
        }
        Write-Output $httpErrorObj
    }
}

function Get-AuthorizationToken {
    [CmdletBinding()]
    param()
    try {
        $tokenHeaders = @{
            'Content-Type'   = 'application/json'
            'x-okapi-tenant' = $actionContext.Configuration.XOkApiTenant
        }
        $tokenBody = @{
            username = $actionContext.Configuration.UserName
            password = $actionContext.Configuration.Password
        }
        $splatGetTokenParams = @{
            Uri         = "$($actionContext.Configuration.baseUrl)/authn/login"
            Method      = 'POST'
            Headers     = $tokenHeaders
            Body        = $tokenBody | ConvertTo-Json
            ContentType = 'application/json'
        }
        $token = Invoke-RestMethod @splatGetTokenParams -Verbose:$false
        Write-Output $token.okapiToken
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
function Confirm-UpdateIsRequired {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        [PSCustomObject]
        $CurrentAccount,

        [parameter(Mandatory)]
        [PSCustomObject]
        $DesiredAccount
    )
    try {
        $updateRequired = $false
        $propertiesChanged = [System.Collections.Generic.list[string]]::new()
        foreach ($prop in  $DesiredAccount.PsObject.Properties) {
            if ($prop.TypeNameOfValue -match 'PSCustomObject') {
                if ( -not $CurrentAccount.PSObject.Properties[$prop.name]) {
                    $CurrentAccount | Add-Member -MemberType NoteProperty -Name $prop.name -Value ([PSCustomObject]@{})
                }
                $updateRequired , $subPropertiesChanged = Confirm-UpdateIsRequired -CurrentAccount $CurrentAccount.$($prop.name) -DesiredAccount $DesiredAccount.$($prop.name)
                foreach ($sub in  $subPropertiesChanged) {
                    $propertiesChanged.Add("$($prop.name).$($sub)" )
                }
            } elseif ($CurrentAccount.$($prop.name) -ne $DesiredAccount.$($prop.name)) {
                $propertiesChanged.Add($($prop.name))
                $updateRequired = $true
            }
        }
        Write-Output $updateRequired, $propertiesChanged
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function ConvertTo-AccountObject {
    param(
        [parameter(Mandatory)]
        [PSCustomObject]
        $AccountModel,

        [parameter()]
        [PSCustomObject]
        $TargetObject
    )
    try {
        $modifiedObject = [PSCustomObject]@{}
        foreach ($property in $AccountModel.PSObject.Properties) {
            if ($property.Value -is [PSCustomObject]) {
                $modifiedObject | Add-Member @{ $($property.Name) = ConvertTo-AccountObject -AccountModel $property.Value -TargetObject $TargetObject.$($property.Name) }
            } else {
                $modifiedObject | Add-Member @{ $($property.Name) = $TargetObject.$($property.Name) }
            }
        }
        Write-Output $modifiedObject
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Set-AccountPropertiesToCurrentAccount {
    param(
        [parameter(Mandatory)]
        [PSCustomObject]
        $AccountObject,

        [parameter()]
        [PSCustomObject]
        $CurrentAccount
    )
    try {
        if ($null -eq $CurrentAccount) {
            $modifiedObject = [PSCustomObject]@{}
        } else {
            $modifiedObject = $CurrentAccount | Select-Object *
        }
        foreach ($property in $AccountObject.PSObject.Properties) {
            if ($property.Value -is [PSCustomObject] -and ($null -eq $modifiedObject.$($property.Name))) {
                $modifiedObject | Add-Member @{
                    $($property.Name) = (Set-AccountPropertiesToCurrentAccount -AccountObject $property.Value)
                }

            } elseif ($property.Value -is [PSCustomObject]) {
                $modifiedObject.$($property.Name) = Set-AccountPropertiesToCurrentAccount -CurrentAccount $modifiedObject.$($property.Name) -AccountObject $property.Value

            } elseif ($modifiedObject.PSObject.Properties[$($property.Name)]) {
                $modifiedObject.$($property.Name) = $property.Value

            } else {
                $modifiedObject | Add-Member -MemberType NoteProperty -Name $($property.Name) -Value $property.Value
            }
        }
        Write-Output $modifiedObject
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
#endregion

try {
    # Verify if [aRef] has a value
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        throw 'The account reference could not be found'
    }

    Write-Verbose "Verifying if a Folio account for [$($personContext.Person.DisplayName)] exists"
    $headers = @{
        'x-okapi-tenant' = "$($actionContext.Configuration.XOkApiTenant)"
        'x-okapi-token'  = "$(Get-AuthorizationToken)"
    }
    $splatParams = @{
        Uri     = "$($actionContext.Configuration.baseUrl)/users/$($actionContext.References.Account)"
        Method  = 'GET'
        Headers = $headers
    }
    try {
        $webResponse = Invoke-WebRequest @splatParams -Verbose:$false
        $currentAccount = ([System.Text.Encoding]::utf8.GetString([System.Text.Encoding]::Default.GetBytes(($webResponse.content))) | ConvertFrom-Json)
        $outputContext.PreviousData = ConvertTo-AccountObject -AccountModel $actionContext.data -TargetObject $currentAccount
    } catch {
        # 404 Indicates that the account is not Found!
        if (-not $_.Exception.Response.StatusCode -eq 404) {
            throw $_
        }
    }

    $action = 'UpdateAccount'
    if ($null -ne $currentAccount) {
        $splatCompareProperties = @{
            CurrentAccount = $outputContext.PreviousData
            DesiredAccount = $actionContext.Data
        }
        $updateRequired , $propertiesChanged = Confirm-UpdateIsRequired @splatCompareProperties
        if ($updateRequired) {
            $action = 'UpdateAccount'
            $dryRunMessage = "Account property(s) required to update: $($propertiesChanged -join ', ')"
        } else {
            $action = 'NoChanges'
            $dryRunMessage = 'No changes will be made to the account during enforcement'
        }
    } else {
        $dryRunMessage = 'Folio account could not be found, indicating that it may have been deleted.'
        $action = 'NotFound'
    }

    # Add a message and the result of each of the validations showing what will happen during enforcement
    if ($actionContext.DryRun -eq $true) {
        Write-Verbose "[DryRun] $dryRunMessage"  -Verbose
    }

    # Process
    if (-not($actionContext.DryRun -eq $true)) {
        switch ($action) {
            'UpdateAccount' {
                Write-Verbose "Updating Folio account with accountReference: [$($actionContext.References.Account)]"
                $account = Set-AccountPropertiesToCurrentAccount -AccountObject $actionContext.data -CurrentAccount $currentAccount
                $splatParams = @{
                    Uri         = "$($actionContext.Configuration.BaseUrl)/users/$($actionContext.References.Account)"
                    Method      = 'PUT'
                    Headers     = $headers
                    ContentType = 'application/json;charset=utf-8'
                    Body        = ([System.Text.Encoding]::UTF8.GetBytes(($account | ConvertTo-Json -Depth 10)))
                }
                $null = Invoke-RestMethod @splatParams -Verbose:$false

                $outputContext.Success = $true
                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        Message = "Update account was successful, Account property(s) updated: [$($propertiesChanged -join ',')]"
                        IsError = $false
                    })
                break
            }

            'NoChanges' {
                Write-Verbose "No changes to Folio account with accountReference: [$($actionContext.References.Account)]"
                $outputContext.Success = $true
                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        Message = 'No changes required for Folio account'
                        IsError = $false
                    })
                break
            }

            'NotFound' {
                $outputContext.Success = $false
                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        Message = "Folio account for: [$($personContext.Person.DisplayName)] could not be found, indicating that it may have been deleted."
                        IsError = $true
                    })
                break
            }
        }
    }
} catch {
    $outputContext.Success = $false
    $outputContext.AccountReference = 'Error'
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-FolioError -ErrorObject $ex
        $auditMessage = "Could not update Folio account. Error: $($errorObj.FriendlyMessage)"
        Write-Verbose "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditMessage = "Could not update Folio account. Error: $($ex.Exception.Message)"
        Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage.substring(0, [System.Math]::Min(200, $auditMessage.Length))
            IsError = $true
        })
}
