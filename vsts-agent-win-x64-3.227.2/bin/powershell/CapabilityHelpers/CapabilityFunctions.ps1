function Add-CapabilityFromApplication {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$ApplicationName)

    Write-Host "Checking for application: '$ApplicationName'"
    $application =
        Get-Command -Name $ApplicationName -CommandType Application -ErrorAction Ignore |
        Select-Object -First 1
    if (!$application) {
        Write-Host "Not found."
        return
    }

    Write-Capability -Name $Name -Value $application.Path
}

function Add-CapabilityFromEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$VariableName,

        [ref]$Value)

    $path = "env:$VariableName"
    Write-Host "Checking: '$path'"
    $val = (Get-Item -LiteralPath $path -ErrorAction Ignore).Value
    if (!$val) {
        Write-Host "Value not found or is empty."
        return
    }

    Write-Capability -Name $Name -Value $val
    if ($Value) {
        $Value.Value = $val
    }
}

function Add-CapabilityFromRegistry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateSet('CurrentUser', 'LocalMachine')]
        [string]$Hive,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Default', 'Registry32', 'Registry64')]
        [string]$View,

        [Parameter(Mandatory = $true)]
        [string]$KeyName,

        [Parameter(Mandatory = $true)]
        [string]$ValueName,

        [ref]$Value)

    $val = Get-RegistryValue -Hive $Hive -View $View -KeyName $KeyName -ValueName $ValueName
    if ($val -eq $null) {
        return $false
    }

    if ($val -is [string] -and $val -eq '') {
        return $false
    }

    Write-Capability -Name $Name -Value $val
    if ($Value) {
        $Value.Value = $val
    }

    return $true
}


function Add-CapabilityFromRegistryWithLastVersionAvailableForSubkey {
    <#
        .SYNOPSIS
            Retrieves capability from registry for specified key and subkey. Considers that subkey has semver format
    #>
    [CmdletBinding()]
    param(
        # Prefix name of capability
        [Parameter(Mandatory = $true)]
        [string]$PrefixName,
        # Postfix name of capability
        [Parameter(Mandatory = $false)]
        [string]$PostfixName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('CurrentUser', 'LocalMachine')]
        [string]$Hive,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Default', 'Registry32', 'Registry64')]
        [string]$View,
        # Registry key
        [Parameter(Mandatory = $true)]
        [string]$KeyName,

        [Parameter(Mandatory = $true)]
        [string]$ValueName,
        
        # Registry subkey
        [Parameter(Mandatory = $true)]
        [string]$Subkey,
        
        # Regkey subdirectory inside particular version
        [Parameter(Mandatory = $false)]
        [string]$VersionSubdirectory,

        # Major version of tool to be added as capability
        [Parameter(Mandatory = $true)]
        [int]$MajorVersion,
        
        # Minimum major version of tool to be added as capability. All versions detected less than this version - will be ignored. 
        # This is helpful for backward compatibility with already existing logic for previous versions
        [Parameter(Mandatory = $false)]
        [int]$MinimumMajorVersion,

        [ref]$Value)
    try {
        Write-Host $MajorVersion $MinimumMajorVersion
        if ($MajorVersion -lt $MinimumMajorVersion) {
            return $false
        }

        $wholeKey = ""
        if ( -not [string]::IsNullOrEmpty($VersionSubdirectory)) {
            $versionDir = Join-Path -Path $KeyName -ChildPath $Subkey
            $wholeKey = Join-Path -Path $versionDir -ChildPath $VersionSubdirectory
        } else {
            $wholeKey = Join-Path -Path $KeyName -ChildPath $Subkey
        }
 
        $capabilityValue = Get-RegistryValue -Hive $Hive -View $View -KeyName $wholeKey -ValueName $ValueName

        if ([string]::IsNullOrEmpty($capabilityValue)) {
            return $false
        }
   
        $capabilityName = $PrefixName + $MajorVersion + $PostfixName

        Write-Capability -Name $capabilityName -Value $capabilityValue
        if ($Value) {
            $Value.Value = $capabilityValue
        }

        return $true
    } catch {
        return $false
    }
}

function Add-CapabilityFromRegistryWithLastVersionAvailable {
    <#
        .SYNOPSIS
            Retrieves capability from registry with last version. Considers that subkeys for specified key name are versions (in semver format like 1.2.3)
            This is useful to detect last version of tools as agent capabilities

        .EXAMPLE
            If KeyName = 'SOFTWARE\JavaSoft\JDK', and this registry key contains subkeys: 14.0.1, 16.0 - it will write the last one as specified capability
    #>
    [CmdletBinding()]
    param(
        # Prefix name of capability
        [Parameter(Mandatory = $true)]
        [string]$PrefixName,
        # Postfix name of capability
        [Parameter(Mandatory = $false)]
        [string]$PostfixName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('CurrentUser', 'LocalMachine')]
        [string]$Hive,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Default', 'Registry32', 'Registry64')]
        [string]$View,
        # Registry key
        [Parameter(Mandatory = $true)]
        [string]$KeyName,

        # Regkey subdirectory inside particular version
        [Parameter(Mandatory = $false)]
        [string]$VersionSubdirectory,

        [Parameter(Mandatory = $true)]
        [string]$ValueName,
        # Minimum major version of tool to be added as capability. All versions detected less than this version - will be ignored. 
        # This is helpful for backward compatibility with already existing logic for previous versions
        [Parameter(Mandatory = $false)]
        [string]$MinimumMajorVersion,

        [ref]$Value)

    try {
        $subkeys = Get-RegistrySubKeyNames -Hive $Hive -View $View -KeyName $KeyName | Sort-Object

        $versionSubkeys = $subkeys | ForEach {[tuple]::Create((Parse-Version -Version $_), $_)} | Where { ![string]::IsNullOrEmpty($_.Item1)}

        $sortedVersionSubkeys = $versionSubkeys | Sort-Object -Property @{Expression = {$_.Item1}; Descending = $False}
        Write-Host $sortedVersionSubkeys[-1].Item1.Major
        $res = Add-CapabilityFromRegistryWithLastVersionAvailableForSubkey -PrefixName $PrefixName -PostfixName $PostfixName -Hive $Hive -View $View -KeyName $KeyName -ValueName $ValueName -Subkey $sortedVersionSubkeys[-1].Item2 -VersionSubdirectory $VersionSubdirectory -MajorVersion $sortedVersionSubkeys[-1].Item1.Major -Value $Value  -MinimumMajorVersion $MinimumMajorVersion

        if (!$res) {
            Write-Host "An error occured while trying to get last available version for capability: " $PrefixName + "<version>" + $PostfixName
            Write-Host $_ 

            $major = (Parse-Version -Version $subkeys[-1]).Major

            $res = Add-CapabilityFromRegistryWithLastVersionAvailableForSubkey -PrefixName $PrefixName -PostfixName $PostfixName -Hive $Hive -View $View -KeyName $KeyName -ValueName $ValueName -Subkey $subkeys[-1] -MajorVersion $major -Value $Value -MinimumMajorVersion $MinimumMajorVersion

            if(!$res) {
                Write-Host "An error occured while trying to set capability for first found subkey: " $subkeys[-1]
                Write-Host $_

                return $false
            }
        }

        return $true
    } catch {
        Write-Host "An error occured while trying to sort subkeys for capability as versions: " $PrefixName + "<version>" + $PostfixName
        Write-Host $_ 

        return $false
    }
}


function Write-Capability {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [string]$Value)

    $escapeMappings = @( # TODO: WHAT ABOUT "="? WHAT ABOUT "%"?
        New-Object psobject -Property @{ Token = ';' ; Replacement = '%3B' }
        New-Object psobject -Property @{ Token = "`r" ; Replacement = '%0D' }
        New-Object psobject -Property @{ Token = "`n" ; Replacement = '%0A' }
    )
    $formattedName = "$Name"
    $formattedValue = "$Value"
    foreach ($mapping in $escapeMappings) {
        $formattedName = $formattedName.Replace($mapping.Token, $mapping.Replacement)
        $formattedValue = $formattedValue.Replace($mapping.Token, $mapping.Replacement)
    }

    Write-Host "##vso[agent.capability name=$formattedName]$formattedValue"
}

# SIG # Begin signature block
# MIIoOQYJKoZIhvcNAQcCoIIoKjCCKCYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDzNUrisGwK99/6
# TUFr64joWmjYL/zvXBLbCNaHVyUMmqCCDYUwggYDMIID66ADAgECAhMzAAADTU6R
# phoosHiPAAAAAANNMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjMwMzE2MTg0MzI4WhcNMjQwMzE0MTg0MzI4WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDUKPcKGVa6cboGQU03ONbUKyl4WpH6Q2Xo9cP3RhXTOa6C6THltd2RfnjlUQG+
# Mwoy93iGmGKEMF/jyO2XdiwMP427j90C/PMY/d5vY31sx+udtbif7GCJ7jJ1vLzd
# j28zV4r0FGG6yEv+tUNelTIsFmmSb0FUiJtU4r5sfCThvg8dI/F9Hh6xMZoVti+k
# bVla+hlG8bf4s00VTw4uAZhjGTFCYFRytKJ3/mteg2qnwvHDOgV7QSdV5dWdd0+x
# zcuG0qgd3oCCAjH8ZmjmowkHUe4dUmbcZfXsgWlOfc6DG7JS+DeJak1DvabamYqH
# g1AUeZ0+skpkwrKwXTFwBRltAgMBAAGjggGCMIIBfjAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUId2Img2Sp05U6XI04jli2KohL+8w
# VAYDVR0RBE0wS6RJMEcxLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJh
# dGlvbnMgTGltaXRlZDEWMBQGA1UEBRMNMjMwMDEyKzUwMDUxNzAfBgNVHSMEGDAW
# gBRIbmTlUAXTgqoXNzcitW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIw
# MTEtMDctMDguY3JsMGEGCCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDEx
# XzIwMTEtMDctMDguY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIB
# ACMET8WuzLrDwexuTUZe9v2xrW8WGUPRQVmyJ1b/BzKYBZ5aU4Qvh5LzZe9jOExD
# YUlKb/Y73lqIIfUcEO/6W3b+7t1P9m9M1xPrZv5cfnSCguooPDq4rQe/iCdNDwHT
# 6XYW6yetxTJMOo4tUDbSS0YiZr7Mab2wkjgNFa0jRFheS9daTS1oJ/z5bNlGinxq
# 2v8azSP/GcH/t8eTrHQfcax3WbPELoGHIbryrSUaOCphsnCNUqUN5FbEMlat5MuY
# 94rGMJnq1IEd6S8ngK6C8E9SWpGEO3NDa0NlAViorpGfI0NYIbdynyOB846aWAjN
# fgThIcdzdWFvAl/6ktWXLETn8u/lYQyWGmul3yz+w06puIPD9p4KPiWBkCesKDHv
# XLrT3BbLZ8dKqSOV8DtzLFAfc9qAsNiG8EoathluJBsbyFbpebadKlErFidAX8KE
# usk8htHqiSkNxydamL/tKfx3V/vDAoQE59ysv4r3pE+zdyfMairvkFNNw7cPn1kH
# Gcww9dFSY2QwAxhMzmoM0G+M+YvBnBu5wjfxNrMRilRbxM6Cj9hKFh0YTwba6M7z
# ntHHpX3d+nabjFm/TnMRROOgIXJzYbzKKaO2g1kWeyG2QtvIR147zlrbQD4X10Ab
# rRg9CpwW7xYxywezj+iNAc+QmFzR94dzJkEPUSCJPsTFMIIHejCCBWKgAwIBAgIK
# YQ6Q0gAAAAAAAzANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlm
# aWNhdGUgQXV0aG9yaXR5IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEw
# OTA5WjB+MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYD
# VQQDEx9NaWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG
# 9w0BAQEFAAOCAg8AMIICCgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+la
# UKq4BjgaBEm6f8MMHt03a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc
# 6Whe0t+bU7IKLMOv2akrrnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4D
# dato88tt8zpcoRb0RrrgOGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+
# lD3v++MrWhAfTVYoonpy4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nk
# kDstrjNYxbc+/jLTswM9sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6
# A4aN91/w0FK/jJSHvMAhdCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmd
# X4jiJV3TIUs+UsS1Vz8kA/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL
# 5zmhD+kjSbwYuER8ReTBw3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zd
# sGbiwZeBe+3W7UvnSSmnEyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3
# T8HhhUSJxAlMxdSlQy90lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS
# 4NaIjAsCAwEAAaOCAe0wggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRI
# bmTlUAXTgqoXNzcitW2oynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAL
# BgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBD
# uRQFTuHqp8cx0SOJNDBaBgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jv
# c29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3JsMF4GCCsGAQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3J0MIGfBgNVHSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEF
# BQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1h
# cnljcHMuaHRtMEAGCCsGAQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkA
# YwB5AF8AcwB0AGEAdABlAG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn
# 8oalmOBUeRou09h0ZyKbC5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7
# v0epo/Np22O/IjWll11lhJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0b
# pdS1HXeUOeLpZMlEPXh6I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/
# KmtYSWMfCWluWpiW5IP0wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvy
# CInWH8MyGOLwxS3OW560STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBp
# mLJZiWhub6e3dMNABQamASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJi
# hsMdYzaXht/a8/jyFqGaJ+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYb
# BL7fQccOKO7eZS/sl/ahXJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbS
# oqKfenoi+kiVH6v7RyOA9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sL
# gOppO6/8MO0ETI7f33VtY5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtX
# cVZOSEXAQsmbdlsKgEhr/Xmfwb1tbWrJUnMTDXpQzTGCGgowghoGAgEBMIGVMH4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01p
# Y3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTECEzMAAANNTpGmGiiweI8AAAAA
# A00wDQYJYIZIAWUDBAIBBQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIBsH
# P5SgCrHA3qhdJnOgYMVLFgS5FPbnhIgUJ3qdIcT0MEIGCisGAQQBgjcCAQwxNDAy
# oBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20wDQYJKoZIhvcNAQEBBQAEggEAazS3zKa85/w2q2MxvcM2T9gsilKT6DiA+gT5
# yE1RDCaGpfuCbzbHMEpk/9OGPnMitPQ0gGB8Rk8kMfClXsz+02GqQDCGyv3x53eo
# csruchTvbZtLEV6cVNC4oUqt0UIRYkq1K4iJ33GCPIIB2/Q+gspbbaAZA1zbKAx6
# iO6iX5vBEFEAwD/fsuV5R6kPFvuW5l9Jr+cZmLaD+wupbsEtLr7zi2FSxMe9PR6Q
# IuX2nhfYchoAs1qTD586zrFtHXhKkYdwX4EcCCLij65zJq31xHP+24UDC/pHIcq3
# QUIoWbK61sX4dufki5YFdlaM0P28vSHmmOSuQE2AdX4S5d8HnKGCF5QwgheQBgor
# BgEEAYI3AwMBMYIXgDCCF3wGCSqGSIb3DQEHAqCCF20wghdpAgEDMQ8wDQYJYIZI
# AWUDBAIBBQAwggFSBgsqhkiG9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGE
# WQoDATAxMA0GCWCGSAFlAwQCAQUABCA+MqKTQINKbXODhmmZOvQ6R6fSA8yJtSh3
# fc8hhZYwzQIGZQP36e13GBMyMDIzMTAxMjE0MzMxNi42NDRaMASAAgH0oIHRpIHO
# MIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQL
# ExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxk
# IFRTUyBFU046OEQwMC0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFNlcnZpY2WgghHqMIIHIDCCBQigAwIBAgITMwAAAc1VByrnysGZHQAB
# AAABzTANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAx
# MDAeFw0yMzA1MjUxOTEyMDVaFw0yNDAyMDExOTEyMDVaMIHLMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1l
# cmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046OEQwMC0w
# NUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2Uw
# ggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDTOCLVS2jmEWOqxzygW7s6
# YLmm29pjvA+Ch6VL7HlTL8yUt3Z0KIzTa2O/Hvr/aJza1qEVklq7NPiOrpBAIz65
# 7LVxwEc4BxJiv6B68a8DQiF6WAFFNaK3WHi7TfxRnqLohgNz7vZPylZQX795r8MQ
# vX56uwjj/R4hXnR7Na4Llu4mWsml/wp6VJqCuxZnu9jX4qaUxngcrfFT7+zvlXCl
# wLah2n0eGKna1dOjOgyK00jYq5vtzr5NZ+qVxqaw9DmEsj9vfqYkfQZry2JO5wmg
# XX79Ox7PLMUfqT4+8w5JkdSMoX32b1D6cDKWRUv5qjiYh4o/a9ehE/KAkUWlSPbb
# DR/aGnPJLAGPy2qA97YCBeeIJjRKURgdPlhE5O46kOju8nYJnIvxbuC2Qp2jxwc6
# rD9M6Pvc8sZIcQ10YKZVYKs94YPSlkhwXwttbRY+jZnQiDm2ZFjH8SPe1I6ERcfe
# YX1zCYjEzdwWcm+fFZmlJA9HQW7ZJAmOECONtfK28EREEE5yzq+T3QMVPhiEfEhg
# cYsh0DeoWiYGsDiKEuS+FElMMyT456+U2ZRa2hbRQ97QcbvaAd6OVQLp3TQqNEu0
# es5Zq0wg2CADf+QKQR/Y6+fGgk9qJNJW3Mu771KthuPlNfKss0B1zh0xa1yN4qC3
# zoE9Uq6T8r7G3/OtSFms4wIDAQABo4IBSTCCAUUwHQYDVR0OBBYEFKGT+aY2aZrB
# AJVIZh5kicokfNWaMB8GA1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8G
# A1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMv
# Y3JsL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBs
# BggrBgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUy
# MDIwMTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUH
# AwgwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4ICAQBSqG3ppKIU+i/E
# MwwtotoxnKfw0SX/3T16EPbjwsAImWOZ5nLAbatopl8zFY841gb5eiL1j81h4DiE
# iXt+BJgHIA2LIhKhSscd79oMbr631DiEqf9X5LZR3V3KIYstU3K7f5Dk7tbobuHu
# +6fYM/gOx44sgRU7YQ+YTYHvv8k4mMnuiahJRlU/F2vavcHU5uhXi078K4nSRAPn
# WyX7gVi6iVMBBUF4823oPFznEcHup7VNGRtGe1xvnlMd1CuyxctM8d/oqyTsxwlJ
# AM5F/lDxnEWoSzAkad1nWvkaAeMV7+39IpXhuf9G3xbffKiyBnj3cQeiA4SxSwCd
# nx00RBlXS6r9tGDa/o9RS01FOABzKkP5CBDpm4wpKdIU74KtBH2sE5QYYn7liYWZ
# r2f/U+ghTmdOEOPkXEcX81H4dRJU28Tj/gUZdwL81xah8Kn+cB7vM/Hs3/J8tF13
# ZPP+8NtX3vu4NrchHDJYgjOi+1JuSf+4jpF/pEEPXp9AusizmSmkBK4iVT7NwVtR
# nS1ts8qAGHGPg2HPa4b2u9meueUoqNVtMhbumI1y+d9ZkThNXBXz2aItT2C99DM3
# T3qYqAUmvKUryVSpMLVpse4je5WN6VVlCDFKWFRH202YxEVWsZ5baN9CaqCbCS0E
# a7s9OFLaEM5fNn9m5s69lD/ekcW2qTCCB3EwggVZoAMCAQICEzMAAAAVxedrngKb
# SZkAAAAAABUwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmlj
# YXRlIEF1dGhvcml0eSAyMDEwMB4XDTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4MzIy
# NVowfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcT
# B1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UE
# AxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQDk4aZM57RyIQt5osvXJHm9DtWC0/3unAcH0qlsTnXI
# yjVX9gF/bErg4r25PhdgM/9cT8dm95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLAEBjo
# YH1qUoNEt6aORmsHFPPFdvWGUNzBRMhxXFExN6AKOG6N7dcP2CZTfDlhAnrEqv1y
# aa8dq6z2Nr41JmTamDu6GnszrYBbfowQHJ1S/rboYiXcag/PXfT+jlPP1uyFVk3v
# 3byNpOORj7I5LFGc6XBpDco2LXCOMcg1KL3jtIckw+DJj361VI/c+gVVmG1oO5pG
# ve2krnopN6zL64NF50ZuyjLVwIYwXE8s4mKyzbnijYjklqwBSru+cakXW2dg3viS
# kR4dPf0gz3N9QZpGdc3EXzTdEonW/aUgfX782Z5F37ZyL9t9X4C626p+Nuw2TPYr
# bqgSUei/BQOj0XOmTTd0lBw0gg/wEPK3Rxjtp+iZfD9M269ewvPV2HM9Q07BMzlM
# jgK8QmguEOqEUUbi0b1qGFphAXPKZ6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJNmSL
# W6CmgyFdXzB0kZSU2LlQ+QuJYfM2BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6r1AF
# emzFER1y7435UsSFF5PAPBXbGjfHCBUYP3irRbb1Hode2o+eFnJpxq57t7c+auIu
# rQIDAQABo4IB3TCCAdkwEgYJKwYBBAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIE
# FgQUKqdS/mTEmr6CkTxGNSnPEP8vBO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl0mWn
# G1M1GelyMFwGA1UdIARVMFMwUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEW
# M2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5
# Lmh0bTATBgNVHSUEDDAKBggrBgEFBQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBi
# AEMAQTALBgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV
# 9lbLj+iiXGJo0T2UkFvXzpoYxDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3Js
# Lm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAx
# MC0wNi0yMy5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2
# LTIzLmNydDANBgkqhkiG9w0BAQsFAAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL/Klv
# 6lwUtj5OR2R4sQaTlz0xM7U518JxNj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu6WZn
# OlNN3Zi6th542DYunKmCVgADsAW+iehp4LoJ7nvfam++Kctu2D9IdQHZGN5tggz1
# bSNU5HhTdSRXud2f8449xvNo32X2pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfgQJY4
# rPf5KYnDvBewVIVCs/wMnosZiefwC2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8sCXgU
# 6ZGyqVvfSaN0DLzskYDSPeZKPmY7T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCrdTDF
# NLB62FD+CljdQDzHVG2dY3RILLFORy3BFARxv2T5JL5zbcqOCb2zAVdJVGTZc9d/
# HltEAY5aGZFrDZ+kKNxnGSgkujhLmm77IVRrakURR6nxt67I6IleT53S0Ex2tVdU
# CbFpAUR+fKFhbHP+CrvsQWY9af3LwUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8CwYKi
# excdFYmNcP7ntdAoGokLjzbaukz5m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9JZTm
# dHRbatGePu1+oDEzfbzL6Xu/OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZq
# ELQdVTNYs6FwZvKhggNNMIICNQIBATCB+aGB0aSBzjCByzELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJp
# Y2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjhEMDAtMDVF
# MC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMK
# AQEwBwYFKw4DAhoDFQBoqfem2KKzuRZjISYifGolVOdyBKCBgzCBgKR+MHwxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jv
# c29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA6NIMzzAi
# GA8yMDIzMTAxMjA2MTIzMVoYDzIwMjMxMDEzMDYxMjMxWjB0MDoGCisGAQQBhFkK
# BAExLDAqMAoCBQDo0gzPAgEAMAcCAQACAgxeMAcCAQACAhPHMAoCBQDo015PAgEA
# MDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAI
# AgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBAMiQFbWkCJ1VQg5PO65ppY5HZOXa
# b3GV3/relDl2tp9e4QfxPL469xi2lwcn707Su0TtpCrfHuG9dXmnNQ+NWgW8n0mF
# yL9mbwjbm+pO6IdjxET8xATiX7ngCdijkKeUofvLL6knVVoxh696ovITDY446lQ/
# RMF2BnUDJBt/QlQnKXR23vIkjpqmWxnEGn+8TK7WXQECHW9LRZD3JKee6Y917C/Q
# +3gozg5lSjH+K9wLIWjNmR0sCRWne8Boey06Knte7YO/u+haZY8JQgWWAlw4i+5s
# TkRg9Bh+Ht244CyrmYvD04qC2oRdPvD4rAkm570xXTLZ0Aw8x5U6r9JL/ooxggQN
# MIIECQIBATCBkzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAc1V
# ByrnysGZHQABAAABzTANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0G
# CyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCBMwo9wuH2n1tB7lzTTi0E0Cn1M
# 9lYjtQRa/6LhRXVX8jCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIOJmpfit
# Vr1PZGgvTEdTpStUc6GNh7LNroQBKwpURpkKMIGYMIGApH4wfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTACEzMAAAHNVQcq58rBmR0AAQAAAc0wIgQg5im+UEVp
# 0gfZ4rvL4Q+8L7R0EbfUzBmVus4xH/1OHBwwDQYJKoZIhvcNAQELBQAEggIABVXr
# zE/+HEkirZmWuhY1Qhf2oBms6CcLpjM9LN2ssXVddnwvQePrhlFqOxiGAmMTV4hI
# vRfnJhH/2ia1q3tUSTtmldSpmYsHWMGVeaqyErtXDNQiIZJu4IQqik+bYS3kpgrN
# QJWK5muZ4tS2/rfiU0qZwnXnkT7VpBAgsU5Y00EU9Rm1zEvZwfwwyXrp2EBFjI36
# neLEE+aE+yZ4V4ZGX74kM6VR2nV/mtDvlISRL2JyJYPBqi1FGTfHPBVhtXpKroeV
# VOhabjoysBVkj19bzDGmckzxFNsOQxTYC8o27jkn74kN12ES/9G+J8LpYTOrR4RH
# oc1dcPc5NCVPFA90ywYWZQcbWwGHjVZhiuuBqbdjx1+/fhCcs6k1LvSRhTY3afb9
# 8lhnegJK+kfAYiaycFurmK2Ba4qZ+ttKSlJJiuY65cSzNZ7TAEaCG50ZCg+EjAJb
# wo6TxFkSvfyc25epa/bJstgfh62MLy3RkKLHKgAik1SXnyqYgznoKZ/+qY6KKrFe
# 7isBqo/zabmNEEfA8Y6VORjXHT4LmjQUEHiNCop9WGRbzyEoEwg4WxuvAXKd6Uea
# rWhC0eKJjhwt6swpXXFixffZV5VeSW9Au6BhE8M0E9ut8ok/Hm/vpwHFai+HkJ3s
# JdNSKZUKbgDL+mjmnS2Mvow0xnb+csgh50Ex70g=
# SIG # End signature block
