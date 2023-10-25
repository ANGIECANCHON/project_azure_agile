<#
    Microsoft.TeamFoundation.DistributedTask.Task.Deployment.RemoteDeployment.psm1
#>

function Invoke-RemoteDeployment
{    
    [CmdletBinding()]
    Param
    (
        [parameter(Mandatory=$true)]
        [string]$environmentName,
        [string]$adminUserName,
        [string]$adminPassword,
        [string]$protocol,
        [string]$testCertificate,
        [Parameter(ParameterSetName='TagsPath')]
        [Parameter(ParameterSetName='TagsBlock')]
        [string]$tags,
        [Parameter(ParameterSetName='MachinesPath')]
        [Parameter(ParameterSetName='MachinesBlock')]
        [string]$machineNames,
        [Parameter(Mandatory=$true, ParameterSetName='TagsPath')]
        [Parameter(Mandatory=$true, ParameterSetName='MachinesPath')]
        [string]$scriptPath,
        [Parameter(Mandatory=$true, ParameterSetName='TagsBlock')]
        [Parameter(Mandatory=$true, ParameterSetName='MachinesBlock')]
        [string]$scriptBlockContent,
        [string]$scriptArguments,
        [Parameter(ParameterSetName='TagsPath')]
        [Parameter(ParameterSetName='MachinesPath')]
        [string]$initializationScriptPath,
        [string]$runPowershellInParallel,
        [Parameter(ParameterSetName='TagsPath')]
        [Parameter(ParameterSetName='MachinesPath')]
        [string]$sessionVariables
    )

    Write-Verbose "Entering Remote-Deployment block"
        
    $machineFilter = $machineNames

    # Getting resource tag key name for corresponding tag
    $resourceFQDNKeyName = Get-ResourceFQDNTagKey
    $resourceWinRMHttpPortKeyName = Get-ResourceHttpTagKey
    $resourceWinRMHttpsPortKeyName = Get-ResourceHttpsTagKey

    # Constants #
    $useHttpProtocolOption = '-UseHttp'
    $useHttpsProtocolOption = ''

    $doSkipCACheckOption = '-SkipCACheck'
    $doNotSkipCACheckOption = ''
    $ErrorActionPreference = 'Stop'
    $deploymentOperation = 'Deployment'

    $envOperationStatus = "Passed"

    # enabling detailed logging only when system.debug is true
    $enableDetailedLoggingString = $env:system_debug
    if ($enableDetailedLoggingString -ne "true")
    {
        $enableDetailedLoggingString = "false"
    }

    function Get-ResourceWinRmConfig
    {
        param
        (
            [string]$resourceName,
            [int]$resourceId
        )

        $resourceProperties = @{}

        $winrmPortToUse = ''
        $protocolToUse = ''


        if($protocol -eq "HTTPS")
        {
            $protocolToUse = $useHttpsProtocolOption
        
            Write-Verbose "Starting Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpsPortKeyName"
            $winrmPortToUse = Get-EnvironmentProperty -Environment $environment -Key $resourceWinRMHttpsPortKeyName -ResourceId $resourceId
            Write-Verbose "Completed Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId (Name : $resourceName) and key: $resourceWinRMHttpsPortKeyName"
        
            if([string]::IsNullOrWhiteSpace($winrmPortToUse))
            {
                throw(Get-LocalizedString -Key "{0} port was not provided for resource '{1}'" -ArgumentList "WinRM HTTPS", $resourceName)
            }
        }
        elseif($protocol -eq "HTTP")
        {
            $protocolToUse = $useHttpProtocolOption
            
            Write-Verbose "Starting Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpPortKeyName"
            $winrmPortToUse = Get-EnvironmentProperty -Environment $environment -Key $resourceWinRMHttpPortKeyName -ResourceId $resourceId
            Write-Verbose "Completed Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpPortKeyName"
        
            if([string]::IsNullOrWhiteSpace($winrmPortToUse))
            {
                throw(Get-LocalizedString -Key "{0} port was not provided for resource '{1}'" -ArgumentList "WinRM HTTP", $resourceName)
            }
        }

        elseif($environment.Provider -ne $null)      #  For standerd environment provider will be null
        {
            Write-Verbose "`t Environment is not standerd environment. Https port has higher precedence"

            Write-Verbose "Starting Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpsPortKeyName"
            $winrmHttpsPort = Get-EnvironmentProperty -Environment $environment -Key $resourceWinRMHttpsPortKeyName -ResourceId $resourceId
            Write-Verbose "Completed Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId (Name : $resourceName) and key: $resourceWinRMHttpsPortKeyName"

            if ([string]::IsNullOrEmpty($winrmHttpsPort))
            {
                Write-Verbose "`t Resource: $resourceName does not have any winrm https port defined, checking for winrm http port"
                    
                   Write-Verbose "Starting Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpPortKeyName"
                   $winrmHttpPort = Get-EnvironmentProperty -Environment $environment -Key $resourceWinRMHttpPortKeyName -ResourceId $resourceId 
                   Write-Verbose "Completed Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpPortKeyName"

                if ([string]::IsNullOrEmpty($winrmHttpPort))
                {
                    throw(Get-LocalizedString -Key "Resource: '{0}' does not have WinRM service configured. Configure WinRM service on the Azure VM Resources. Refer for more details '{1}'" -ArgumentList $resourceName, "https://aka.ms/azuresetup" )
                }
                else
                {
                    # if resource has winrm http port defined
                    $winrmPortToUse = $winrmHttpPort
                    $protocolToUse = $useHttpProtocolOption
                }
            }
            else
            {
                # if resource has winrm https port opened
                $winrmPortToUse = $winrmHttpsPort
                $protocolToUse = $useHttpsProtocolOption
            }
        }
        else
        {
            Write-Verbose "`t Environment is standerd environment. Http port has higher precedence"

            Write-Verbose "Starting Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpPortKeyName"
            $winrmHttpPort = Get-EnvironmentProperty -Environment $environment -Key $resourceWinRMHttpPortKeyName -ResourceId $resourceId
            Write-Verbose "Completed Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpPortKeyName"

            if ([string]::IsNullOrEmpty($winrmHttpPort))
            {
                Write-Verbose "`t Resource: $resourceName does not have any winrm http port defined, checking for winrm https port"

                   Write-Verbose "Starting Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpsPortKeyName"
                   $winrmHttpsPort = Get-EnvironmentProperty -Environment $environment -Key $resourceWinRMHttpsPortKeyName -ResourceId $resourceId
                   Write-Verbose "Completed Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpsPortKeyName"

                if ([string]::IsNullOrEmpty($winrmHttpsPort))
                {
                    throw(Get-LocalizedString -Key "Resource: '{0}' does not have WinRM service configured. Configure WinRM service on the Azure VM Resources. Refer for more details '{1}'" -ArgumentList $resourceName, "https://aka.ms/azuresetup" )
                }
                else
                {
                    # if resource has winrm https port defined
                    $winrmPortToUse = $winrmHttpsPort
                    $protocolToUse = $useHttpsProtocolOption
                }
            }
            else
            {
                # if resource has winrm http port opened
                $winrmPortToUse = $winrmHttpPort
                $protocolToUse = $useHttpProtocolOption
            }
        }

        $resourceProperties.protocolOption = $protocolToUse
        $resourceProperties.winrmPort = $winrmPortToUse

        return $resourceProperties;
    }

    function Get-SkipCACheckOption
    {
        [CmdletBinding()]
        Param
        (
            [string]$environmentName
        )

        $skipCACheckOption = $doNotSkipCACheckOption
        $skipCACheckKeyName = Get-SkipCACheckTagKey

        # get skipCACheck option from environment
        Write-Verbose "Starting Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with key: $skipCACheckKeyName"
        $skipCACheckBool = Get-EnvironmentProperty -Environment $environment -Key $skipCACheckKeyName 
        Write-Verbose "Completed Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with key: $skipCACheckKeyName"

        if ($skipCACheckBool -eq "true")
        {
            $skipCACheckOption = $doSkipCACheckOption
        }

        return $skipCACheckOption
    }

    function Get-ResourceConnectionDetails
    {
        param([object]$resource)

        $resourceProperties = @{}
        $resourceName = $resource.Name
        $resourceId = $resource.Id

        Write-Verbose "Starting Get-EnvironmentProperty cmdlet call on environment name: $environmentName with resource id: $resourceId(Name : $resourceName) and key: $resourceFQDNKeyName"
        $fqdn = Get-EnvironmentProperty -Environment $environment -Key $resourceFQDNKeyName -ResourceId $resourceId 
        Write-Verbose "Completed Get-EnvironmentProperty cmdlet call on environment name: $environmentName with resource id: $resourceId(Name : $resourceName) and key: $resourceFQDNKeyName"

        $winrmconfig = Get-ResourceWinRmConfig -resourceName $resourceName -resourceId $resourceId
        $resourceProperties.fqdn = $fqdn
        $resourceProperties.winrmPort = $winrmconfig.winrmPort
        $resourceProperties.protocolOption = $winrmconfig.protocolOption
        $resourceProperties.credential = Get-ResourceCredentials -resource $resource	
        $resourceProperties.displayName = $fqdn + ":" + $winrmconfig.winrmPort

        return $resourceProperties
    }

    function Get-ResourcesProperties
    {
        param([object]$resources)

        $skipCACheckOption = Get-SkipCACheckOption -environmentName $environmentName
        [hashtable]$resourcesPropertyBag = @{}

        foreach ($resource in $resources)
        {
            $resourceName = $resource.Name
            $resourceId = $resource.Id
            Write-Verbose "Get Resource properties for $resourceName (ResourceId = $resourceId)"
            $resourceProperties = Get-ResourceConnectionDetails -resource $resource
            $resourceProperties.skipCACheckOption = $skipCACheckOption
            $resourcesPropertyBag.add($resourceId, $resourceProperties)
        }

        return $resourcesPropertyBag
    }

    $RunPowershellJobInitializationScript = {
        function Load-AgentAssemblies
        {
            
            if(Test-Path "$env:AGENT_HOMEDIRECTORY\Agent\Worker")
            {
                Get-ChildItem $env:AGENT_HOMEDIRECTORY\Agent\Worker\*.dll | % {
                [void][reflection.assembly]::LoadFrom( $_.FullName )
                Write-Verbose "Loading .NET assembly:`t$($_.name)"
                }

                Get-ChildItem $env:AGENT_HOMEDIRECTORY\Agent\Worker\Modules\Microsoft.TeamFoundation.DistributedTask.Task.DevTestLabs\*.dll | % {
                [void][reflection.assembly]::LoadFrom( $_.FullName )
                Write-Verbose "Loading .NET assembly:`t$($_.name)"
                }
            }
            else
            {
                if(Test-Path "$env:AGENT_HOMEDIRECTORY\externals\vstshost")
                {
                    [void][reflection.assembly]::LoadFrom("$env:AGENT_HOMEDIRECTORY\externals\vstshost\Microsoft.TeamFoundation.DistributedTask.Task.LegacySDK.dll")
                }
            }
        }

        function Get-EnableDetailedLoggingOption
        {
            param ([string]$enableDetailedLogging)

            if ($enableDetailedLogging -eq "true")
            {
                return '-EnableDetailedLogging'
            }

            return '';
        }
    }

    $RunPowershellJobForScriptPath = {
        param (
        [string]$fqdn, 
        [string]$scriptPath,
        [string]$port,
        [string]$scriptArguments,
        [string]$initializationScriptPath,
        [object]$credential,
        [string]$httpProtocolOption,
        [string]$skipCACheckOption,
        [string]$enableDetailedLogging,
        [object]$sessionVariables
        )

        Write-Verbose "fqdn = $fqdn"
        Write-Verbose "scriptPath = $scriptPath"
        Write-Verbose "port = $port"
        Write-Verbose "scriptArguments = $scriptArguments"
        Write-Verbose "initializationScriptPath = $initializationScriptPath"
        Write-Verbose "protocolOption = $httpProtocolOption"
        Write-Verbose "skipCACheckOption = $skipCACheckOption"
        Write-Verbose "enableDetailedLogging = $enableDetailedLogging"

        Load-AgentAssemblies

        $enableDetailedLoggingOption = Get-EnableDetailedLoggingOption $enableDetailedLogging
    
        Write-Verbose "Initiating deployment on $fqdn"
        [String]$psOnRemoteScriptBlockString = "Invoke-PsOnRemote -MachineDnsName $fqdn -ScriptPath `$scriptPath -WinRMPort $port -Credential `$credential -ScriptArguments `$scriptArguments -InitializationScriptPath `$initializationScriptPath -SessionVariables `$sessionVariables $skipCACheckOption $httpProtocolOption $enableDetailedLoggingOption"
        [scriptblock]$psOnRemoteScriptBlock = [scriptblock]::Create($psOnRemoteScriptBlockString)
        $deploymentResponse = Invoke-Command -ScriptBlock $psOnRemoteScriptBlock
    
        Write-Output $deploymentResponse
    }

    $RunPowershellJobForScriptBlock = {
    param (
        [string]$fqdn, 
        [string]$scriptBlockContent,
        [string]$port,
        [string]$scriptArguments,    
        [object]$credential,
        [string]$httpProtocolOption,
        [string]$skipCACheckOption,
        [string]$enableDetailedLogging    
        )

        Write-Verbose "fqdn = $fqdn"
        Write-Verbose "port = $port"
        Write-Verbose "scriptArguments = $scriptArguments"
        Write-Verbose "protocolOption = $httpProtocolOption"
        Write-Verbose "skipCACheckOption = $skipCACheckOption"
        Write-Verbose "enableDetailedLogging = $enableDetailedLogging"

        Load-AgentAssemblies

        $enableDetailedLoggingOption = Get-EnableDetailedLoggingOption $enableDetailedLogging
   
        Write-Verbose "Initiating deployment on $fqdn"
        [String]$psOnRemoteScriptBlockString = "Invoke-PsOnRemote -MachineDnsName $fqdn -ScriptBlockContent `$scriptBlockContent -WinRMPort $port -Credential `$credential -ScriptArguments `$scriptArguments $skipCACheckOption $httpProtocolOption $enableDetailedLoggingOption"
        [scriptblock]$psOnRemoteScriptBlock = [scriptblock]::Create($psOnRemoteScriptBlockString)
        $deploymentResponse = Invoke-Command -ScriptBlock $psOnRemoteScriptBlock
    
        Write-Output $deploymentResponse
    }

    $connection = Get-VssConnection -TaskContext $distributedTaskContext

    # This is temporary fix for filtering 
    if([string]::IsNullOrEmpty($machineNames))
    {
       $machineNames  = $tags
    }

    Write-Verbose "Starting Register-Environment cmdlet call for environment : $environmentName with filter $machineNames"
    $environment = Register-Environment -EnvironmentName $environmentName -EnvironmentSpecification $environmentName -UserName $adminUserName -Password $adminPassword -WinRmProtocol $protocol -TestCertificate ($testCertificate -eq "true")  -Connection $connection -TaskContext $distributedTaskContext -ResourceFilter $machineNames
	Write-Verbose "Completed Register-Environment cmdlet call for environment : $environmentName"
	
    Write-Verbose "Starting Get-EnvironmentResources cmdlet call on environment name: $environmentName"
    $resources = Get-EnvironmentResources -Environment $environment

    if ($resources.Count -eq 0)
    {
      throw (Get-LocalizedString -Key "No machine exists under environment: '{0}' for deployment" -ArgumentList $environmentName)
    }

    $resourcesPropertyBag = Get-ResourcesProperties -resources $resources

    $parsedSessionVariables = Get-ParsedSessionVariables -inputSessionVariables $sessionVariables

    if($runPowershellInParallel -eq "false" -or  ( $resources.Count -eq 1 ) )
    {
        foreach($resource in $resources)
        {
            $resourceProperties = $resourcesPropertyBag.Item($resource.Id)
            $machine = $resourceProperties.fqdn
            $displayName = $resourceProperties.displayName
            Write-Host (Get-LocalizedString -Key "Deployment started for machine: '{0}'" -ArgumentList $displayName)

            . $RunPowershellJobInitializationScript
            if($PsCmdlet.ParameterSetName.EndsWith("Path"))
            {
                $deploymentResponse = Invoke-Command -ScriptBlock $RunPowershellJobForScriptPath -ArgumentList $machine, $scriptPath, $resourceProperties.winrmPort, $scriptArguments, $initializationScriptPath, $resourceProperties.credential, $resourceProperties.protocolOption, $resourceProperties.skipCACheckOption, $enableDetailedLoggingString, $parsedSessionVariables
            }
            else
            {
                $deploymentResponse = Invoke-Command -ScriptBlock $RunPowershellJobForScriptBlock -ArgumentList $machine, $scriptBlockContent, $resourceProperties.winrmPort, $scriptArguments, $resourceProperties.credential, $resourceProperties.protocolOption, $resourceProperties.skipCACheckOption, $enableDetailedLoggingString 
            }

            Write-ResponseLogs -operationName $deploymentOperation -fqdn $displayName -deploymentResponse $deploymentResponse
            $status = $deploymentResponse.Status
				
			if ($status -ne "Passed")
			{             
			    if($deploymentResponse.Error -ne $null)
                {
					Write-Verbose (Get-LocalizedString -Key "Deployment failed on machine '{0}' with following message : '{1}'" -ArgumentList $displayName, $deploymentResponse.Error.ToString())
                    $errorMessage = $deploymentResponse.Error.Message
					return $errorMessage					
                }
				else
				{
					$errorMessage = (Get-LocalizedString -Key 'Deployment on one or more machines failed.')
					return $errorMessage
				}
           }
		   
		    Write-Host (Get-LocalizedString -Key "Deployment status for machine '{0}' : '{1}'" -ArgumentList $displayName, $status)
        }
    }
    else
    {
        [hashtable]$Jobs = @{} 

        foreach($resource in $resources)
        {
            $resourceProperties = $resourcesPropertyBag.Item($resource.Id)
            $machine = $resourceProperties.fqdn
            $displayName = $resourceProperties.displayName
            Write-Host (Get-LocalizedString -Key "Deployment started for machine: '{0}'" -ArgumentList $displayName)

            if($PsCmdlet.ParameterSetName.EndsWith("Path"))
            {
                $job = Start-Job -InitializationScript $RunPowershellJobInitializationScript -ScriptBlock $RunPowershellJobForScriptPath -ArgumentList $machine, $scriptPath, $resourceProperties.winrmPort, $scriptArguments, $initializationScriptPath, $resourceProperties.credential, $resourceProperties.protocolOption, $resourceProperties.skipCACheckOption, $enableDetailedLoggingString, $parsedSessionVariables
            }
            else
            {
                $job = Start-Job -InitializationScript $RunPowershellJobInitializationScript -ScriptBlock $RunPowershellJobForScriptBlock -ArgumentList $machine, $scriptBlockContent, $resourceProperties.winrmPort, $scriptArguments, $resourceProperties.credential, $resourceProperties.protocolOption, $resourceProperties.skipCACheckOption, $enableDetailedLoggingString                 
            }
            
            $Jobs.Add($job.Id, $resourceProperties)
        }
        While (Get-Job)
        {
            Start-Sleep 10 
            foreach($job in Get-Job)
            {
                 if($job.State -ne "Running")
                {
                    $output = Receive-Job -Id $job.Id
                    Remove-Job $Job
                    $status = $output.Status
                    $displayName = $Jobs.Item($job.Id).displayName
                    $resOperationId = $Jobs.Item($job.Id).resOperationId

                    Write-ResponseLogs -operationName $deploymentOperation -fqdn $displayName -deploymentResponse $output
                    Write-Host (Get-LocalizedString -Key "Deployment status for machine '{0}' : '{1}'" -ArgumentList $displayName, $status)
                    if($status -ne "Passed")
                    {
                        $envOperationStatus = "Failed"
                        $errorMessage = ""
                        if($output.Error -ne $null)
                        {
                            $errorMessage = $output.Error.Message
                        }
                        Write-Host (Get-LocalizedString -Key "Deployment failed on machine '{0}' with following message : '{1}'" -ArgumentList $displayName, $errorMessage)
                    }
                }
            }
        }
    }

    if($envOperationStatus -ne "Passed")
    {
         $errorMessage = (Get-LocalizedString -Key 'Deployment on one or more machines failed.')
         return $errorMessage
    }

}
# SIG # Begin signature block
# MIInwgYJKoZIhvcNAQcCoIInszCCJ68CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDvZ3uXMKhqjxqP
# pD9BYnyXygrXbhnvSUzwcypxeAztfKCCDXYwggX0MIID3KADAgECAhMzAAADTrU8
# esGEb+srAAAAAANOMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjMwMzE2MTg0MzI5WhcNMjQwMzE0MTg0MzI5WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDdCKiNI6IBFWuvJUmf6WdOJqZmIwYs5G7AJD5UbcL6tsC+EBPDbr36pFGo1bsU
# p53nRyFYnncoMg8FK0d8jLlw0lgexDDr7gicf2zOBFWqfv/nSLwzJFNP5W03DF/1
# 1oZ12rSFqGlm+O46cRjTDFBpMRCZZGddZlRBjivby0eI1VgTD1TvAdfBYQe82fhm
# WQkYR/lWmAK+vW/1+bO7jHaxXTNCxLIBW07F8PBjUcwFxxyfbe2mHB4h1L4U0Ofa
# +HX/aREQ7SqYZz59sXM2ySOfvYyIjnqSO80NGBaz5DvzIG88J0+BNhOu2jl6Dfcq
# jYQs1H/PMSQIK6E7lXDXSpXzAgMBAAGjggFzMIIBbzAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUnMc7Zn/ukKBsBiWkwdNfsN5pdwAw
# RQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEW
# MBQGA1UEBRMNMjMwMDEyKzUwMDUxNjAfBgNVHSMEGDAWgBRIbmTlUAXTgqoXNzci
# tW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3JsMGEG
# CCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3J0
# MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIBAD21v9pHoLdBSNlFAjmk
# mx4XxOZAPsVxxXbDyQv1+kGDe9XpgBnT1lXnx7JDpFMKBwAyIwdInmvhK9pGBa31
# TyeL3p7R2s0L8SABPPRJHAEk4NHpBXxHjm4TKjezAbSqqbgsy10Y7KApy+9UrKa2
# kGmsuASsk95PVm5vem7OmTs42vm0BJUU+JPQLg8Y/sdj3TtSfLYYZAaJwTAIgi7d
# hzn5hatLo7Dhz+4T+MrFd+6LUa2U3zr97QwzDthx+RP9/RZnur4inzSQsG5DCVIM
# pA1l2NWEA3KAca0tI2l6hQNYsaKL1kefdfHCrPxEry8onJjyGGv9YKoLv6AOO7Oh
# JEmbQlz/xksYG2N/JSOJ+QqYpGTEuYFYVWain7He6jgb41JbpOGKDdE/b+V2q/gX
# UgFe2gdwTpCDsvh8SMRoq1/BNXcr7iTAU38Vgr83iVtPYmFhZOVM0ULp/kKTVoir
# IpP2KCxT4OekOctt8grYnhJ16QMjmMv5o53hjNFXOxigkQWYzUO+6w50g0FAeFa8
# 5ugCCB6lXEk21FFB1FdIHpjSQf+LP/W2OV/HfhC3uTPgKbRtXo83TZYEudooyZ/A
# Vu08sibZ3MkGOJORLERNwKm2G7oqdOv4Qj8Z0JrGgMzj46NFKAxkLSpE5oHQYP1H
# tPx1lPfD7iNSbJsP6LiUHXH1MIIHejCCBWKgAwIBAgIKYQ6Q0gAAAAAAAzANBgkq
# hkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5
# IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEwOTA5WjB+MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQg
# Q29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+laUKq4BjgaBEm6f8MMHt03
# a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc6Whe0t+bU7IKLMOv2akr
# rnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4Ddato88tt8zpcoRb0Rrrg
# OGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+lD3v++MrWhAfTVYoonpy
# 4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nkkDstrjNYxbc+/jLTswM9
# sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6A4aN91/w0FK/jJSHvMAh
# dCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmdX4jiJV3TIUs+UsS1Vz8k
# A/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL5zmhD+kjSbwYuER8ReTB
# w3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zdsGbiwZeBe+3W7UvnSSmn
# Eyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3T8HhhUSJxAlMxdSlQy90
# lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS4NaIjAsCAwEAAaOCAe0w
# ggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRIbmTlUAXTgqoXNzcitW2o
# ynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYD
# VR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBDuRQFTuHqp8cx0SOJNDBa
# BgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2Ny
# bC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3JsMF4GCCsG
# AQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3J0MIGfBgNV
# HSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEFBQcCARYzaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1hcnljcHMuaHRtMEAGCCsG
# AQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkAYwB5AF8AcwB0AGEAdABl
# AG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn8oalmOBUeRou09h0ZyKb
# C5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7v0epo/Np22O/IjWll11l
# hJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0bpdS1HXeUOeLpZMlEPXh6
# I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/KmtYSWMfCWluWpiW5IP0
# wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvyCInWH8MyGOLwxS3OW560
# STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBpmLJZiWhub6e3dMNABQam
# ASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJihsMdYzaXht/a8/jyFqGa
# J+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYbBL7fQccOKO7eZS/sl/ah
# XJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbSoqKfenoi+kiVH6v7RyOA
# 9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sLgOppO6/8MO0ETI7f33Vt
# Y5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtXcVZOSEXAQsmbdlsKgEhr
# /Xmfwb1tbWrJUnMTDXpQzTGCGaIwghmeAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAANOtTx6wYRv6ysAAAAAA04wDQYJYIZIAWUDBAIB
# BQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIPvd2aSF2Ep37PuCnFW7e2ox
# 0cizuB8VazPk++vL6yf0MEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAdW/lH7eS9d9LYPP7I0cfDei2FjYMQziQLsdyecdRhYKO53utxbfCGK6a
# gQZe0UP1Hhv/NjRakTmNmgJvbzwFu/tWNOkq1tD6FxFBm3XKarNClGmXSXd3mL56
# fppBpb5lUGKu4Ygt5kg7XM3bfuGEtBfjTzHsE3T6fl2x3OQTSrW56A1hTZB2tGZW
# GlZKVehgLcUGALqesvQfLxhH05XdGNQR8R9U+l5mAnVTsUHoN6H9LOdEpP2NQXjN
# ZIXvDh+C0kUi4jm9j0cMOowZ/O8sXkuWaxBr6e1wQzoYuNAp4pc8yubSj8ax1/I6
# mzbnmRW1MJRQNqCJ0BLzjljiI4j+cKGCFywwghcoBgorBgEEAYI3AwMBMYIXGDCC
# FxQGCSqGSIb3DQEHAqCCFwUwghcBAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFZBgsq
# hkiG9w0BCRABBKCCAUgEggFEMIIBQAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCDEo/2KY0ozOXyKIGS2l7k68JyDZRknMOVLI7SpxthbywIGZQuWdD9b
# GBMyMDIzMTAxMjE0MzMxNS43NTFaMASAAgH0oIHYpIHVMIHSMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJl
# bGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNO
# OkZDNDEtNEJENC1EMjIwMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBT
# ZXJ2aWNloIIRezCCBycwggUPoAMCAQICEzMAAAG59gANZVRPvAMAAQAAAbkwDQYJ
# KoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMjIw
# OTIwMjAyMjE3WhcNMjMxMjE0MjAyMjE3WjCB0jELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0IElyZWxhbmQgT3Bl
# cmF0aW9ucyBMaW1pdGVkMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpGQzQxLTRC
# RDQtRDIyMDElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCC
# AiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAONJPslh9RbHyQECbUIINxMF
# 5uQkyN07VIShITXubLpWnANgBCLvCcJl7o/2HHORnsRcmSINJ/qclAmLIrOjnYnr
# bocAnixiMEXC+a1sZ84qxYWtEVY7VYw0LCczY+86U/8shgxqsaezKpWriPOcpV1S
# h8SsOxf30yO7jvld/IBA3T6lHM2pT/HRjWk/r9uyx0Q4atx0mkLVYS9y55/oTlKL
# E00h792S+maadAdy3VgTweiwoEOXD785wv3h+fwH/wTQtC9lhAxhMO4p+OP9888W
# xkbl6BqRWXud54RTzqp2Vr+yen1Q1A6umyMB7Xq0snIYG5B1Acc4UgJlPQ/ZiMkq
# gxQNFCWQvz0G9oLgSPD8Ky0AkX22PcDOboPuNT4RceWPX0UVZUsX9IUgs7QF41Hi
# QSwEeOOHGyrfQdmSslATrbmH/18M5QrsTM5JINjct9G42xqN8VF9Z8WOiGMjNbvl
# pcEmmysYl5QyhrEDoFnQTU7bFrD3JX0fIfu1sbLWeBqXwbp4Z8yACTtphK2VbzOv
# i4vc0RCmRNzvYQQ2PjZ7NaTXE4Gu3vggAJ+rtzUTAfJotvOSqcMgNwLZa1Y+ET/l
# b0VyjrYwFuHtg0QWyQjP5350LTpv086pyVUh4A3w/Os5hTGFZgFe5bCyMnpY09M0
# yPdHaQ/56oYUsSIcyKyVAgMBAAGjggFJMIIBRTAdBgNVHQ4EFgQUt7A4cdtYQ5oJ
# jE1ZqrSonp41RFIwHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXwYD
# VR0fBFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9j
# cmwvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3JsMGwG
# CCsGAQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIw
# MjAxMCgxKS5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcD
# CDAOBgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQADggIBAM3cZ7NFUHRMsLKz
# jl7rJPIkv7oJ+s9kkut0hZif9WSt60SzYGULp1zmdPqc+w8eHTkhqX0GKCp2TTqS
# zBXBhwHOm8+p6hUxNlDewGMZUos952aTXblAT3OKBnfVBLQyUavrSjuJGZAW30cN
# Y3rjVDUlGD+VygQHySaDaviJQbK6/6fQvUUFoqIk3ldGfjnAtnebsVlqh6WWamVc
# 5AZdpWR1jSzN/oxKYqc1BG4SxxlPtcfrAdBz/cU4bxVXqAAf02NZscvJNpRnOALf
# 5kVo2HupJXCsk9TzP5PNW2sTS3TmwhIQmPxr0E0UqOojUrBJUOhbITAxcnSa/IMl
# uL1HXRtLQZI+xs2eRtuPOUsKUW71/1YeqsYCLHLvu82ceDVQQvP7GHEEkp2kEjio
# fbjYErBo2iCEaxxeX4Z9HvAgA4MsQkbn6e4EFQf13sP+Kn3XgMIvJbqLJeFcQja+
# SUeOXu5cfkxe0GzTNojdyIwzaHlhOflVRZNrxee3B+yZwd3JHDIvv71uSI/SIzzt
# 9cU2GyHQVqxBSrRtKW6W8Vw7zpVvoVsIv3ljxg+7NiGSlXX1s7zbBNDMUj9OnzOl
# HK/3mrOU8YEuRf6RwakW5UCeGamy5MiKu2YuyKiGBCv4OGhPstNe7ALkEOh8BX12
# t4ntuYu+gw9L6yCPY0jWYaQtzAP9MIIHcTCCBVmgAwIBAgITMwAAABXF52ueAptJ
# mQAAAAAAFTANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNh
# dGUgQXV0aG9yaXR5IDIwMTAwHhcNMjEwOTMwMTgyMjI1WhcNMzAwOTMwMTgzMjI1
# WjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDCCAiIwDQYJKoZIhvcNAQEB
# BQADggIPADCCAgoCggIBAOThpkzntHIhC3miy9ckeb0O1YLT/e6cBwfSqWxOdcjK
# NVf2AX9sSuDivbk+F2Az/1xPx2b3lVNxWuJ+Slr+uDZnhUYjDLWNE893MsAQGOhg
# fWpSg0S3po5GawcU88V29YZQ3MFEyHFcUTE3oAo4bo3t1w/YJlN8OWECesSq/XJp
# rx2rrPY2vjUmZNqYO7oaezOtgFt+jBAcnVL+tuhiJdxqD89d9P6OU8/W7IVWTe/d
# vI2k45GPsjksUZzpcGkNyjYtcI4xyDUoveO0hyTD4MmPfrVUj9z6BVWYbWg7mka9
# 7aSueik3rMvrg0XnRm7KMtXAhjBcTyziYrLNueKNiOSWrAFKu75xqRdbZ2De+JKR
# Hh09/SDPc31BmkZ1zcRfNN0Sidb9pSB9fvzZnkXftnIv231fgLrbqn427DZM9itu
# qBJR6L8FA6PRc6ZNN3SUHDSCD/AQ8rdHGO2n6Jl8P0zbr17C89XYcz1DTsEzOUyO
# ArxCaC4Q6oRRRuLRvWoYWmEBc8pnol7XKHYC4jMYctenIPDC+hIK12NvDMk2ZItb
# oKaDIV1fMHSRlJTYuVD5C4lh8zYGNRiER9vcG9H9stQcxWv2XFJRXRLbJbqvUAV6
# bMURHXLvjflSxIUXk8A8FdsaN8cIFRg/eKtFtvUeh17aj54WcmnGrnu3tz5q4i6t
# AgMBAAGjggHdMIIB2TASBgkrBgEEAYI3FQEEBQIDAQABMCMGCSsGAQQBgjcVAgQW
# BBQqp1L+ZMSavoKRPEY1Kc8Q/y8E7jAdBgNVHQ4EFgQUn6cVXQBeYl2D9OXSZacb
# UzUZ6XIwXAYDVR0gBFUwUzBRBgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYz
# aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnku
# aHRtMBMGA1UdJQQMMAoGCCsGAQUFBwMIMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIA
# QwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFNX2
# VsuP6KJcYmjRPZSQW9fOmhjEMFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6Ly9jcmwu
# bWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dF8yMDEw
# LTA2LTIzLmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYt
# MjMuY3J0MA0GCSqGSIb3DQEBCwUAA4ICAQCdVX38Kq3hLB9nATEkW+Geckv8qW/q
# XBS2Pk5HZHixBpOXPTEztTnXwnE2P9pkbHzQdTltuw8x5MKP+2zRoZQYIu7pZmc6
# U03dmLq2HnjYNi6cqYJWAAOwBb6J6Gngugnue99qb74py27YP0h1AdkY3m2CDPVt
# I1TkeFN1JFe53Z/zjj3G82jfZfakVqr3lbYoVSfQJL1AoL8ZthISEV09J+BAljis
# 9/kpicO8F7BUhUKz/AyeixmJ5/ALaoHCgRlCGVJ1ijbCHcNhcy4sa3tuPywJeBTp
# kbKpW99Jo3QMvOyRgNI95ko+ZjtPu4b6MhrZlvSP9pEB9s7GdP32THJvEKt1MMU0
# sHrYUP4KWN1APMdUbZ1jdEgssU5HLcEUBHG/ZPkkvnNtyo4JvbMBV0lUZNlz138e
# W0QBjloZkWsNn6Qo3GcZKCS6OEuabvshVGtqRRFHqfG3rsjoiV5PndLQTHa1V1QJ
# sWkBRH58oWFsc/4Ku+xBZj1p/cvBQUl+fpO+y/g75LcVv7TOPqUxUYS8vwLBgqJ7
# Fx0ViY1w/ue10CgaiQuPNtq6TPmb/wrpNPgkNWcr4A245oyZ1uEi6vAnQj0llOZ0
# dFtq0Z4+7X6gMTN9vMvpe784cETRkPHIqzqKOghif9lwY1NNje6CbaUFEMFxBmoQ
# tB1VM1izoXBm8qGCAtcwggJAAgEBMIIBAKGB2KSB1TCB0jELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0IElyZWxh
# bmQgT3BlcmF0aW9ucyBMaW1pdGVkMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpG
# QzQxLTRCRDQtRDIyMDElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vy
# dmljZaIjCgEBMAcGBSsOAwIaAxUAx2IeGHhk58MQkzzSWknGcLjfgTqggYMwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQUFAAIF
# AOjSa2kwIhgPMjAyMzEwMTIyMDU2MDlaGA8yMDIzMTAxMzIwNTYwOVowdzA9Bgor
# BgEEAYRZCgQBMS8wLTAKAgUA6NJraQIBADAKAgEAAgIUtQIB/zAHAgEAAgIROjAK
# AgUA6NO86QIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIB
# AAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBBQUAA4GBAC5ScYMXBKWnXDdj
# frv7fJODZk10dd/MHw4T0wOAtPssNeF5LJsray8hNhGCcQ2YZ5/6ZE5+bkyIEK/H
# aQ7em02nmqbsbV9dRCbGxmBJAy0ahlgZcF/hgg8Y+qXxetMlDaT5EtDel2NZcBqY
# F4/58DQRUyWvCd5VexF+Wb5h6vWmMYIEDTCCBAkCAQEwgZMwfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTACEzMAAAG59gANZVRPvAMAAQAAAbkwDQYJYIZIAWUD
# BAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0B
# CQQxIgQgHG1OCZjd86WyVuEwK9se4IquhzmfQk9cQfBmScQSmWswgfoGCyqGSIb3
# DQEJEAIvMYHqMIHnMIHkMIG9BCBk60bO8W85uTAfJVEO3vX2aLaQFcgcGpdwsOoi
# +foP9DCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB
# ufYADWVUT7wDAAEAAAG5MCIEIPeAUfvDbGtJOZjYAXrtJpXQFvzfzkXEaMN7wxFn
# UbBWMA0GCSqGSIb3DQEBCwUABIICAA2K0TTwZElDvFmbD/eubN7lsJUEqdM8N8DW
# 802RXv8CA0fpWesf/SFvcB9qXipJh4qmQBSysiMoxEmzTH4PvC5fm+icsPwcJ10U
# 6FXt2IUvEjpOANoK1biBbErI3lCWI/opzak47oFMDbI/PBBNlfwKxp4t1bCam8th
# fOOHJlund8DNg5hhj6tOeGlsbZOO1Y2lsVVB+GY0KWPh0A09JSOgbjurdCXyYBLm
# SQ/eNDXNrGZbws0FiRX2UbEiWMmslMiriQcO2SfTwzwwqEBpUe75Z+4FoO/LxYty
# Lep7IZG0H2TZ798pGbd8aCPXBxyxC9k/VJ8bu2iMWmWZw66/Z64t4rt2Q+P8KeBI
# tbplPYFnad0RrNthddbJeYmSldOhc11tDftbynh7ufyNPd59L+9dXqDCebyHzy/+
# funqxfCYfz7pGLZAEqimBEA/wKeR7q6Z+4xGo1XJBVvD8cqtS8kcjGFo63l0kogF
# rMrvWhTibpCIix/wxs2lr+i9CQnUjTMPUt4MxMK1D4m3jPen+UQeu5uaHVPG2+no
# CUaDPFdjfBAcu/xTTqsleH/duUCtpcsIppvPLmlkujonrh3QS3VzkIdc7+pcRVvS
# mJhS1oQGQnNM2nJNb9OuAeIHuMySS6AKveOLdbQ8+YQ9c9VyvsJekMAx8MXIL6tC
# 2cdVKmlC
# SIG # End signature block
