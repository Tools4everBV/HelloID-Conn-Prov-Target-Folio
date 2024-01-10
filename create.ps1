#################################################
# HelloID-Conn-Prov-Target-Folio-Create
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
#endregion

try {
    # Verify if a user must be either [created and correlated] or just [correlated]
    if ($actionContext.CorrelationConfiguration.Enabled) {
        $correlationField = $actionContext.CorrelationConfiguration.accountField
        $correlationValue = $actionContext.CorrelationConfiguration.accountFieldValue
        if ([string]::IsNullOrEmpty($($correlationField))) {
            throw 'Correlation is enabled but not configured correctly'
        }
        if ([string]::IsNullOrEmpty($($correlationValue))) {
            throw 'Mandatory attribute [CorrelationConfiguration.accountFieldValue] is empty. Please make sure it is correctly mapped'
        }
        $headers = @{
            'Accept'         = 'application/json;charset=utf-8'
            'x-okapi-tenant' = "$($actionContext.Configuration.XOkApiTenant)"
            'x-okapi-token'  = "$(Get-AuthorizationToken)"
        }

        $splatParams = @{
            Uri     = "$($actionContext.Configuration.baseUrl)/users?query=($($correlationField) ==`"$($correlationValue)*`")"
            Method  = 'GET'
            Headers = $headers
        }
        $webResponse = Invoke-WebRequest @splatParams -Verbose:$false
        $correlationResult = ([System.Text.Encoding]::utf8.GetString([System.Text.Encoding]::Default.GetBytes(($webResponse.content))) | ConvertFrom-Json)
    } else {
        throw 'The Correlation configuration has not been specified, Please make sure to correctly configure correlation on the [Correlation] tab within HelloID'
    }

    if ($correlationResult.totalRecords -eq 1) {
        $action = 'CorrelateAccount'
        $correlatedAccount = $correlationResult.Users | Select-Object -First 1
    } elseif ($correlationResult.totalRecords -gt 1) {
        throw "Multiple accounts found with Correlation: $correlationField - $correlationValue"
    } else {
        $action = 'CreateAccount'
    }

    # Add a message and the result of each of the validations showing what will happen during enforcement
    if ($actionContext.DryRun -eq $true) {
        Write-Verbose  "[DryRun] $action Folio account for: [$($personContext.Person.DisplayName)], will be executed during enforcement" -Verbose
        $outputContext.AccountReference = '<DryRun>'
    }

    # Process
    if (-not($actionContext.DryRun -eq $true)) {
        switch ($action) {
            'CreateAccount' {
                Write-Verbose 'Creating and correlating Folio account'
                $splatParams = @{
                    Uri         = "$($actionContext.Configuration.baseUrl)/users"
                    Method      = 'POST'
                    Headers     = $headers
                    ContentType = 'application/json;charset=utf-8'
                    Body        = ([System.Text.Encoding]::UTF8.GetBytes(($actionContext.Data | ConvertTo-Json)))
                }
                $createdAccount = Invoke-RestMethod @splatParams -Verbose:$false

                $outputContext.Data = ConvertTo-AccountObject -AccountModel $actionContext.data -TargetObject $createdAccount
                $outputContext.AccountReference = $createdAccount.id
                $outputContext.success = $true
                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        Message = "Create account was successful. AccountReference is: [$($outputContext.AccountReference)]"
                        IsError = $false
                    })
                break
            }

            'CorrelateAccount' {
                Write-Verbose 'Correlating Folio account'
                $outputContext.AccountCorrelated = $true
                $outputContext.Data =   ConvertTo-AccountObject -AccountModel $actionContext.data -TargetObject $correlatedAccount
                $outputContext.AccountReference = $correlatedAccount.id
                $outputContext.success = $true
                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        Action  = 'CorrelateAccount'
                        Message = "Correlated account on field: [$($correlationField)] with value: [$($correlationValue)]"
                        IsError = $false
                    })
                break
            }
        }
    }
} catch {
    $outputContext.success = $false
    $outputContext.AccountReference = 'UnSpecified'
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-FolioError -ErrorObject $ex
        $auditMessage = "Could not $action Folio account. Error: $($errorObj.FriendlyMessage)"
        Write-Verbose "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditMessage = "Could not $action Folio account. Error: $($ex.Exception.Message)"
        Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage.substring(0, [System.Math]::Min(200, $auditMessage.Length))
            IsError = $true
        })
}