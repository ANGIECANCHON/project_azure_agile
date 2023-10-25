[CmdletBinding()]
param()

function Add-TestCapability {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        $ShellPath,

        [Parameter(Mandatory = $true)]
        [ref]$Value)

    $directory = [System.IO.Path]::Combine($ShellPath, 'Common7\IDE\CommonExtensions\Microsoft\TestWindow')
    if (!(Test-Container -LiteralPath $directory)) {
        return
    }

    [string]$file = [System.IO.Path]::Combine($directory, 'vstest.console.exe')
    if (!(Test-Leaf -LiteralPath $file)) {
        return
    }

    Write-Capability -Name $Name -Value $directory
    $Value.Value = $directory
}

function Get-VSCapabilities {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet(15, 16, 17)]
        [int]$MajorVersion,

        [Parameter(Mandatory = $true)]
        [string]$keyName
    )
    $vs = Get-VisualStudio -MajorVersion $MajorVersion
    if ($vs -and $vs.installationPath) {
        # Add VisualStudio_$($MajorVersion).0.
        # End with "\" for consistency with old ShellFolder values.
        $shellFolder = $vs.installationPath.TrimEnd('\'[0]) + "\"
        Write-Capability -Name "VisualStudio_$($MajorVersion).0" -Value $shellFolder
        $latestVS = $shellFolder
        # Add VisualStudio_IDE_$($MajorVersion).0.
        # End with "\" for consistency with old InstallDir values.
        $installDir = ([System.IO.Path]::Combine($shellFolder, 'Common7', 'IDE')) + '\'
        if ((Test-Container -LiteralPath $installDir)) {
            Write-Capability -Name "VisualStudio_IDE_$($MajorVersion).0" -Value $installDir
            $latestIde = $installDir
        }
    
        # Add VSTest_$($MajorVersion).0.
        $testWindowDir = [System.IO.Path]::Combine($installDir, 'CommonExtensions\Microsoft\TestWindow')
        $vstestConsole = [System.IO.Path]::Combine($testWindowDir, 'vstest.console.exe')
        if ((Test-Leaf -LiteralPath $vstestConsole)) {
            Write-Capability -Name "VSTest_$($MajorVersion).0" -Value $testWindowDir
            $latestTest = $testWindowDir
        }
    }
    else {
        if ((Add-CapabilityFromRegistry -Name "VisualStudio_$($MajorVersion).0" -Hive 'LocalMachine' -View 'Registry32' -KeyName $keyName -ValueName 'ShellFolder' -Value ([ref]$latestVS))) {
            $null = Add-CapabilityFromRegistry -Name "VisualStudio_IDE_$($MajorVersion).0" -Hive 'LocalMachine' -View 'Registry32' -KeyName $keyName -ValueName 'InstallDir' -Value ([ref]$latestIde)
            Add-TestCapability -Name "VSTest_$($MajorVersion).0" -ShellPath $latestVS -Value ([ref]$latestTest)
        }
    }

    if ($latestVS) {
        Write-Capability -Name 'VisualStudio' -Value $latestVS
    }

    if ($latestIde) {
        Write-Capability -Name 'VisualStudio_IDE' -Value $latestIde
    }

    if ($latestTest) {
        Write-Capability -Name 'VSTest' -Value $latestTest
    }
}

# Define the key names.
$keyName10 = 'Software\Microsoft\VisualStudio\10.0'
$keyName11 = 'Software\Microsoft\VisualStudio\11.0'
$keyName12 = 'Software\Microsoft\VisualStudio\12.0'
$keyName14 = 'Software\Microsoft\VisualStudio\14.0'
$keyName15 = 'Software\Microsoft\VisualStudio\15.0'
$keyName16 = 'Software\Microsoft\VisualStudio\16.0'
$keyName17 = 'Software\Microsoft\VisualStudio\17.0'

# Add the capabilities.
$latestVS = $null
$latestIde = $null
$latestTest = $null
$null = Add-CapabilityFromRegistry -Name 'VisualStudio_10.0' -Hive 'LocalMachine' -View 'Registry32' -KeyName $keyName10 -ValueName 'ShellFolder' -Value ([ref]$latestVS)
$null = Add-CapabilityFromRegistry -Name 'VisualStudio_IDE_10.0' -Hive 'LocalMachine' -View 'Registry32' -KeyName $keyName10 -ValueName 'InstallDir' -Value ([ref]$latestIde)
$null = Add-CapabilityFromRegistry -Name 'VisualStudio_11.0' -Hive 'LocalMachine' -View 'Registry32' -KeyName $keyName11 -ValueName 'ShellFolder' -Value ([ref]$latestVS)
$null = Add-CapabilityFromRegistry -Name 'VisualStudio_IDE_11.0' -Hive 'LocalMachine' -View 'Registry32' -KeyName $keyName11 -ValueName 'InstallDir' -Value ([ref]$latestIde)
if ((Add-CapabilityFromRegistry -Name 'VisualStudio_12.0' -Hive 'LocalMachine' -View 'Registry32' -KeyName $keyName12 -ValueName 'ShellFolder' -Value ([ref]$latestVS))) {
    $null = Add-CapabilityFromRegistry -Name 'VisualStudio_IDE_12.0' -Hive 'LocalMachine' -View 'Registry32' -KeyName $keyName12 -ValueName 'InstallDir' -Value ([ref]$latestIde)
    Add-TestCapability -Name 'VSTest_12.0' -ShellPath $latestVS -Value ([ref]$latestTest)
}

if ((Add-CapabilityFromRegistry -Name 'VisualStudio_14.0' -Hive 'LocalMachine' -View 'Registry32' -KeyName $keyName14 -ValueName 'ShellFolder' -Value ([ref]$latestVS))) {
    $null = Add-CapabilityFromRegistry -Name 'VisualStudio_IDE_14.0' -Hive 'LocalMachine' -View 'Registry32' -KeyName $keyName14 -ValueName 'InstallDir' -Value ([ref]$latestIde)
    Add-TestCapability -Name 'VSTest_14.0' -ShellPath $latestVS -Value ([ref]$latestTest)
}

Get-VSCapabilities -MajorVersion 15 -keyName $keyName15

Get-VSCapabilities -MajorVersion 16 -keyName $keyName16

Get-VSCapabilities -MajorVersion 17 -keyName $keyName17

# SIG # Begin signature block
# MIInwgYJKoZIhvcNAQcCoIInszCCJ68CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCC4KT2MPv6xHU9N
# wzoteAmgv9uAtNe8rwJbCXlJOHgUf6CCDXYwggX0MIID3KADAgECAhMzAAADTrU8
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
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIA8ipCeOijy8puNboe8XGoFj
# G4GVtDERNiy6ui2nN6pgMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAHlKQ4HdeyUvWM7uCMIKQLNM5ovAhWfKVufCZkTEiuDUpF5ITXiRbMDp1
# 1k6pde6xlhS8yxnOEhauX9DIbjm1diuO7Q9inYTfoGzSouMKQzzHLL6PIJAu0zTg
# GmxLo04XACEF4iYHcZ8s6rRdgjRh2iT6JEDbpyKiVvnP2oHp7s9+ucs0gQdp9bHS
# AI0PPkiwlQOaQLErNnd4SsjhV5Pap3bgbskq8ouM6DgmALvlwW7Io7mmrOWWMYGw
# GnAvP+vKlp42cDUnWf6WLZ5HpKxjrIJIre2O0lAxXouwRg5zoLQix9lRG9m7eyY9
# kZcLqEAVInrTsVQvzAvFyxn2dwqYMaGCFywwghcoBgorBgEEAYI3AwMBMYIXGDCC
# FxQGCSqGSIb3DQEHAqCCFwUwghcBAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFZBgsq
# hkiG9w0BCRABBKCCAUgEggFEMIIBQAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCCoVgjGL6vq2MAdl5evK6pJpbp2Ml3+LDUKG8X5+ddK9QIGZQta7uUb
# GBMyMDIzMTAxMjE0MzMxNi43OTVaMASAAgH0oIHYpIHVMIHSMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJl
# bGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNO
# Ojg2REYtNEJCQy05MzM1MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBT
# ZXJ2aWNloIIRezCCBycwggUPoAMCAQICEzMAAAG3IScaB6IqhkYAAQAAAbcwDQYJ
# KoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMjIw
# OTIwMjAyMjE0WhcNMjMxMjE0MjAyMjE0WjCB0jELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0IElyZWxhbmQgT3Bl
# cmF0aW9ucyBMaW1pdGVkMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjo4NkRGLTRC
# QkMtOTMzNTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCC
# AiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMf9z1dQNBNkTBq3HJclypjQ
# cJIlDAgpvsw4vHJe06n532RKGkcn0V7p65OeA1wOoO+8NsopnjPpVZ8+4s/RhdMC
# MNPQJXoWdkWOp/3puIEs1fzPBgTJrdmzdyUYzrAloICYx722gmdpbNf3P0y5Z2gR
# O48sWIYyYeNJYch+ZfJzXqqvuvq7G8Nm8IMQi8Zayvx+5dSGBM5VYHBxCEjXF9EN
# 6Qw7A60SaXjKjojSpUmpaM4FmVec985PNdSh8hOeP2tL781SBan92DT19tfNHv9H
# 0FAmE2HGRwizHkJ//mAZdS0s6bi/UwPMksAia5bpnIDBOoaYdWkV0lVG5rN0+ltR
# z9zjlaH9uhdGTJ+WiNKOr7mRnlzYQA53ftSSJBqsEpTzCv7c673fdvltx3y48Per
# 6vc6UR5e4kSZsH141IhxhmRR2SmEabuYKOTdO7Q/vlvAfQxuEnJ93NL4LYV1IWw8
# O+xNO6gljrBpCOfOOTQgWJF+M6/IPyuYrcv79Lu7lc67S+U9MEu2dog0MuJIoYCM
# iuVaXS5+FmOJiyfiCZm0VJsJ570y9k/tEQe6aQR9MxDW1p2F3HWebolXj9su7zrr
# ElNlHAEvpFhcgoMniylNTiTZzLwUj7TH83gnugw1FCEVVh5U9lwNMPL1IGuz/3U+
# RT9wZCBJYIrFJPd6k8UtAgMBAAGjggFJMIIBRTAdBgNVHQ4EFgQUs/I5Pgw0JAVh
# DdYB2yPII8l4tOwwHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXwYD
# VR0fBFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9j
# cmwvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3JsMGwG
# CCsGAQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIw
# MjAxMCgxKS5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcD
# CDAOBgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQADggIBAA2dZMybhVxSXTbJ
# zFgvNiMCV5/Ayn5UuzJU495YDtcefold0ehR9QBGBhHmAMt10WYCHz2WQUyM3mQD
# 4IsHfEL1JEwgG9tGq71ucn9dknLBHD30JvbQRhIKcvFSnvRCCpVpilM8F/YaWXC9
# VibSef/PU2GWA+1zs64VFxJqHeuy8KqrQyfF20SCnd8zRZl4YYBcjh9G0GjhJHUP
# AYEx0r8jSWjyi2o2WAHD6CppBtkwnZSf7A68DL4OwwBpmFB3+vubjgNwaICS+fkG
# VvRnP2ZgmlfnaAas8Mx7igJqciqq0Q6An+0rHj1kxisNdIiTzFlu5Gw2ehXpLrl5
# 9kvsmONVAJHhndpx3n/0r76TH+3WNS9UT9jbxQkE+t2thif6MK5krFMnkBICCR/D
# VcV1qw9sg6sMEo0wWSXlQYXvcQWA65eVzSkosylhIlIZZLL3GHZD1LQtAjp2A5F7
# C3Iw4Nt7C7aDCfpFxom3ZulRnFJollPHb3unj9hA9xvRiKnWMAMpS4MZAoiV4O29
# zWKZdUzygp7gD4WjKK115KCJ0ovEcf92AnwMAXMnNs1o0LCszg+uDmiQZs5eR7jz
# dKzVfF1z7bfDYNPAJvm5pSQdby3wIOsN/stYjM+EkaPtUzr8OyMwrG+jpFMbsB4c
# fN6tvIeGtrtklMJFtnF68CcZZ5IAMIIHcTCCBVmgAwIBAgITMwAAABXF52ueAptJ
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
# bmQgT3BlcmF0aW9ucyBMaW1pdGVkMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjo4
# NkRGLTRCQkMtOTMzNTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vy
# dmljZaIjCgEBMAcGBSsOAwIaAxUAyGdBGMObODlsGBZmSUX2oWgfqcaggYMwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQUFAAIF
# AOjSL2IwIhgPMjAyMzEwMTIxNjQwMDJaGA8yMDIzMTAxMzE2NDAwMlowdzA9Bgor
# BgEEAYRZCgQBMS8wLTAKAgUA6NIvYgIBADAKAgEAAgIIDwIB/zAHAgEAAgIRUjAK
# AgUA6NOA4gIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIB
# AAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBBQUAA4GBABna7Abs1Z3E+Iah
# p/Er6On7WwOmXg312R5dfwJs6Dt5Gaeeu/gKcExOUWQCkpfhJBYQKynVBW+kpSa8
# Bo8iraFvGavq4cuPUlfRzDYTnRFlWgGlAhNseToFzzY94HtinVTs11cJWpDKzl1b
# 2JpJxAcmUFWeg7S6H5deEx7sSQX9MYIEDTCCBAkCAQEwgZMwfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTACEzMAAAG3IScaB6IqhkYAAQAAAbcwDQYJYIZIAWUD
# BAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0B
# CQQxIgQgPcVDBptPeHvXuZsgXHbAl2bPVNkspYJwdlQLLXguq5kwgfoGCyqGSIb3
# DQEJEAIvMYHqMIHnMIHkMIG9BCBsJ3jTsh7aL8hNeiYGL5/8IBn8zUfr7/Q7rkM8
# ic1wQTCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB
# tyEnGgeiKoZGAAEAAAG3MCIEIAh06Jz0UJf72/Oi1fNXKxWlSxKETj9s5mog/zOm
# dIXsMA0GCSqGSIb3DQEBCwUABIICADqFwKMgD4NJHSwR0auGv8611byiKte922OB
# FiFoN/JpXZS3My1v1aVTiX2Yzd/XH53WPG1VJzBeBmpWujCspxqeo2CYWb24FcZT
# oJJowTlqtwqfnsCmFMBJy0VW0AyHQT5ITjEhnZm1DD/ahZxkD8GYiFoLHk/cHmJu
# K4lpgPkLVCUJnUgsopXN2NFvZBOqlqeMaQXCfy6uDujxy3AUCpCzuQHzB8oLCWP9
# TqyRFRylV7/hyXQWV5oyQKfZl8cuKiQuhm+yHND7Vuq0jqAl9TKWwrHzVIkXte5C
# Q6j6+zG/z4Zw1Y7+9w78nuxjohvcHUdJff/E/rsXGBpbbxUjb3khWcIcrK1idskj
# nupLcGBZT3OMbLbzTZblsQzUcDayz5wL3gvYmKD7Qo7YOWMayC/xXJigEjiwIxWJ
# eT8DFs6f30SB5xNgUzWFK8vM6q/DLVqMAUKa+C0FkqpPS5L1AYAbzeM2X8kNwzU2
# xWaT1rc3QGMtfvEU5/0Kr1MStq743yxfLd4qEXGlXGPAsavIIlORa6LaA0rbmwAi
# xSdxHBmbSTPJj/zG19Zwc7EH4WoxAA06y8tCSwuDjlnJ4weaeBQQBKbr7+IjGK/m
# V6YNnrXzfxp3MNX3rmN+Frw8eKfQ/wC4jv108sWNV457M3/069ua+47GWh+iJjPQ
# NCF4EmKg
# SIG # End signature block
