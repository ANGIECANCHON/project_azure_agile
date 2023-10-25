[CmdletBinding()]
param()

function Get-MaxInfoFromSqlServer {
    [CmdletBinding()]
    param()

    $sqlServerKeyName = 'Software\Microsoft\Microsoft SQL Server'
    foreach ($view in @( 'Registry32', 'Registry64' )) {
        $versions =
            Get-RegistrySubKeyNames -Hive 'LocalMachine' -View $view -KeyName $sqlServerKeyName |
            # Filter to include integer key names only.
            ForEach-Object {
                $i = 0
                if (([int]::TryParse($_, [ref]$i))) {
                    $i
                }
            } |
            Sort-Object -Descending
        foreach ($version in $versions) {
            # Get the install directory.
            $verSpecificRootDir = Get-RegistryValue -Hive 'LocalMachine' -View $view -KeyName "$sqlServerKeyName\$version" -Value 'VerSpecificRootDir'
            if (!$verSpecificRootDir) {
                continue
            }

            # Test for SqlPackage.exe.
            $file = [System.IO.Path]::Combine($verSpecificRootDir, 'Dac', 'bin', 'SqlPackage.exe')
            if (!(Test-Leaf -LiteralPath $file)) {
                continue
            }

            # Return the info as an object with properties (for sorting).
            return New-Object psobject -Property @{
                File = $file
                Version = $version
            }
        }
    }
}

function Get-MaxInfoFromSqlServerDtaf {
    [CmdletBinding()]
    param()

    $dtafKeyName = 'Software\Microsoft\Microsoft SQL Server\Data-Tier Application Framework'
    foreach ($view in @( 'Registry32', 'Registry64' )) {
        $versions =
            Get-RegistrySubKeyNames -Hive 'LocalMachine' -View $view -KeyName $dtafKeyName |
            # Filter to include integer key names only.
            ForEach-Object {
                $i = 0
                if (([int]::TryParse($_, [ref]$i))) {
                    $i
                }
            } |
            Sort-Object -Descending
       foreach ($version in $versions) {
            # Get the install directory.
            $installDir = Get-RegistryValue -Hive 'LocalMachine' -View $view -KeyName "$dtafKeyName\$version" -Value 'InstallDir'
            if (!$installDir) {
                continue
            }

            # Test for SqlPackage.exe.
            $file = [System.IO.Path]::Combine($installDir, 'SqlPackage.exe')
            if (!(Test-Leaf -LiteralPath $file)) {
                continue
            }

            # Return the info as an object with properties (for sorting).
            return New-Object psobject -Property @{
                File = $file
                Version = $version
            }
        }
    }
}

function Get-MaxInfoFromVisualStudio_15_0 {
    [CmdletBinding()]
    param()

    $vs15 = Get-VisualStudio -MajorVersion 15
    if ($vs15 -and $vs15.installationPath) {
        # End with "\" for consistency with old ShellFolder values.
        $shellFolder15 = $vs15.installationPath.TrimEnd('\'[0]) + "\"

        # Test for the DAC directory.
        $dacDirectory = [System.IO.Path]::Combine($shellFolder15, 'Common7', 'IDE', 'Extensions', 'Microsoft', 'SQLDB', 'DAC')
        $sqlPacakgeInfo = Get-SqlPacakgeFromDacDirectory -dacDirectory $dacDirectory

        if($sqlPacakgeInfo -and $sqlPacakgeInfo.File) {
            return $sqlPacakgeInfo
        }
    }
}

function Get-MaxInfoFromVisualStudio_16_0 {
    [CmdletBinding()]
    param()

    $vs16 = Get-VisualStudio -MajorVersion 16
    if ($vs16 -and $vs16.installationPath) {
        # End with "\" for consistency with old ShellFolder values.
        $shellFolder16 = $vs16.installationPath.TrimEnd('\'[0]) + "\"

        # Test for the DAC directory.
        $dacDirectory = [System.IO.Path]::Combine($shellFolder16, 'Common7', 'IDE', 'Extensions', 'Microsoft', 'SQLDB', 'DAC')
        $sqlPacakgeInfo = Get-SqlPacakgeFromDacDirectory -dacDirectory $dacDirectory

        if($sqlPacakgeInfo -and $sqlPacakgeInfo.File) {
            return $sqlPacakgeInfo
        }
    }
}

function Get-MaxInfoFromVisualStudio {
    [CmdletBinding()]
    param()

    $visualStudioKeyName = 'Software\Microsoft\VisualStudio'
    foreach ($view in @( 'Registry32', 'Registry64' )) {
        $versions =
            Get-RegistrySubKeyNames -Hive 'LocalMachine' -View $view -KeyName $visualStudioKeyName |
            # Filter to include integer key names only.
            ForEach-Object {
                $d = 0
                if (([decimal]::TryParse($_, [ref]$d))) {
                    $d
                }
            } |
            Sort-Object -Descending
        foreach ($version in $versions) {
            # Get the install directory.
            $installDir = Get-RegistryValue -Hive 'LocalMachine' -View $view -KeyName "$visualStudioKeyName\$version" -Value 'InstallDir'
            if (!$installDir) {
                continue
            }

            # Test for the DAC directory.
            $dacDirectory = [System.IO.Path]::Combine($installDir, 'Extensions', 'Microsoft', 'SQLDB', 'DAC')
            $sqlPacakgeInfo = Get-SqlPacakgeFromDacDirectory -dacDirectory $dacDirectory

            if($sqlPacakgeInfo -and $sqlPacakgeInfo.File)
           {
                return $sqlPacakgeInfo
            }
        }
    }
}

function Get-SqlPacakgeFromDacDirectory {
    [CmdletBinding()]
    param([string] $dacDirectory)


    if (!(Test-Container -LiteralPath $dacDirectory)) {
        return
    }

    # Get the DAC version folders.
    $dacVersions =
        Get-ChildItem -LiteralPath $dacDirectory |
        Where-Object { $_ -is [System.IO.DirectoryInfo] }
        # Filter to include integer key names only.
        ForEach-Object {
            $i = 0
            if (([int]::TryParse($_.Name, [ref]$i))) {
                $i
            }
        } |
        Sort-Object -Descending
    foreach ($dacVersion in $dacVersions) {
        # Test for SqlPackage.exe.
        $file = [System.IO.Path]::Combine($dacDirectory, $dacVersion, 'SqlPackage.exe')
        if (!(Test-Leaf -LiteralPath $file)) {
            continue
        }

        # Return the info as an object with properties (for sorting).
        return New-Object psobject -Property @{
            File = $file
            Version = $dacVersion
        }
    }
}

$sqlPackageInfo = @( )
$sqlPackageInfo += (Get-MaxInfoFromSqlServer)
$sqlPackageInfo += (Get-MaxInfoFromSqlServerDtaf)
$sqlPackageInfo += (Get-MaxInfoFromVisualStudio)
$sqlPackageInfo += (Get-MaxInfoFromVisualStudio_15_0)
$sqlPackageInfo += (Get-MaxInfoFromVisualStudio_16_0)
$sqlPackageInfo |
    Sort-Object -Property Version -Descending |
    Select -First 1 |
    ForEach-Object { Write-Capability -Name 'SqlPackage' -Value $_.File }

# SIG # Begin signature block
# MIInwQYJKoZIhvcNAQcCoIInsjCCJ64CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCOjTE62sJdoUmq
# k9HIKV1rPBftv+AAM5QuYfoYjKNCpKCCDXYwggX0MIID3KADAgECAhMzAAADTrU8
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
# /Xmfwb1tbWrJUnMTDXpQzTGCGaEwghmdAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAANOtTx6wYRv6ysAAAAAA04wDQYJYIZIAWUDBAIB
# BQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIAcAYT1LTbAZxyxGLKTg1nm/
# vR7uqCERjyR4QaLcAfKfMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAtfG7tZV5zXG4tZ3AX2xpbQbovdohe6Z0t0l1t9gBuw83IKMXxUXRgcVE
# RUwKZRddfIhepcG90bMZrzf2ov+vCN5FDhbBvL3y22k2C/3pWcLVjbTv9Smcbphh
# ZMsoPAPV208hix0cGcUxyQDWVYigyWYJPnLPlSt0EmUK7KzNORbAvZ2a5pvIDq4v
# fdNbXdleKQHK8HCZGZWDyKLC8HCOBI3aEZmWlWoLy4ZmeSlmoviWY218XKs9ZTLx
# TPEity3BekVAhGtNOJqtH16M7OqcjYV/Km7dl4V4iTJZUibgcMiDQa6boD0HPsrL
# wj07sAcenwSK58E2tMwyZ8c4Snqdc6GCFyswghcnBgorBgEEAYI3AwMBMYIXFzCC
# FxMGCSqGSIb3DQEHAqCCFwQwghcAAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFYBgsq
# hkiG9w0BCRABBKCCAUcEggFDMIIBPwIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCB8RjCrHTzZABbE6BcmAGBxK4rxMkIWawvYfUF5iAjsOAIGZQuWdD9f
# GBIyMDIzMTAxMjE0MzMxNi4wMVowBIACAfSggdikgdUwgdIxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVs
# YW5kIE9wZXJhdGlvbnMgTGltaXRlZDEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046
# RkM0MS00QkQ0LUQyMjAxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNl
# cnZpY2WgghF7MIIHJzCCBQ+gAwIBAgITMwAAAbn2AA1lVE+8AwABAAABuTANBgkq
# hkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yMjA5
# MjAyMDIyMTdaFw0yMzEyMTQyMDIyMTdaMIHSMQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVy
# YXRpb25zIExpbWl0ZWQxJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNOOkZDNDEtNEJE
# NC1EMjIwMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNlMIIC
# IjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA40k+yWH1FsfJAQJtQgg3EwXm
# 5CTI3TtUhKEhNe5sulacA2AEIu8JwmXuj/Ycc5GexFyZIg0n+pyUCYsis6Odietu
# hwCeLGIwRcL5rWxnzirFha0RVjtVjDQsJzNj7zpT/yyGDGqxp7MqlauI85ylXVKH
# xKw7F/fTI7uO+V38gEDdPqUczalP8dGNaT+v27LHRDhq3HSaQtVhL3Lnn+hOUosT
# TSHv3ZL6Zpp0B3LdWBPB6LCgQ5cPvznC/eH5/Af/BNC0L2WEDGEw7in44/3zzxbG
# RuXoGpFZe53nhFPOqnZWv7J6fVDUDq6bIwHterSychgbkHUBxzhSAmU9D9mIySqD
# FA0UJZC/PQb2guBI8PwrLQCRfbY9wM5ug+41PhFx5Y9fRRVlSxf0hSCztAXjUeJB
# LAR444cbKt9B2ZKyUBOtuYf/XwzlCuxMzkkg2Ny30bjbGo3xUX1nxY6IYyM1u+Wl
# wSabKxiXlDKGsQOgWdBNTtsWsPclfR8h+7WxstZ4GpfBunhnzIAJO2mErZVvM6+L
# i9zREKZE3O9hBDY+Nns1pNcTga7e+CAAn6u3NRMB8mi285KpwyA3AtlrVj4RP+Vv
# RXKOtjAW4e2DRBbJCM/nfnQtOm/TzqnJVSHgDfD86zmFMYVmAV7lsLIyeljT0zTI
# 90dpD/nqhhSxIhzIrJUCAwEAAaOCAUkwggFFMB0GA1UdDgQWBBS3sDhx21hDmgmM
# TVmqtKienjVEUjAfBgNVHSMEGDAWgBSfpxVdAF5iXYP05dJlpxtTNRnpcjBfBgNV
# HR8EWDBWMFSgUqBQhk5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2Ny
# bC9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcmwwbAYI
# KwYBBQUHAQEEYDBeMFwGCCsGAQUFBzAChlBodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAy
# MDEwKDEpLmNydDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMI
# MA4GA1UdDwEB/wQEAwIHgDANBgkqhkiG9w0BAQsFAAOCAgEAzdxns0VQdEywsrOO
# Xusk8iS/ugn6z2SS63SFmJ/1ZK3rRLNgZQunXOZ0+pz7Dx4dOSGpfQYoKnZNOpLM
# FcGHAc6bz6nqFTE2UN7AYxlSiz3nZpNduUBPc4oGd9UEtDJRq+tKO4kZkBbfRw1j
# euNUNSUYP5XKBAfJJoNq+IlBsrr/p9C9RQWioiTeV0Z+OcC2d5uxWWqHpZZqZVzk
# Bl2lZHWNLM3+jEpipzUEbhLHGU+1x+sB0HP9xThvFVeoAB/TY1mxy8k2lGc4At/m
# RWjYe6klcKyT1PM/k81baxNLdObCEhCY/GvQTRSo6iNSsElQ6FshMDFydJr8gyW4
# vUddG0tBkj7GzZ5G2485SwpRbvX/Vh6qxgIscu+7zZx4NVBC8/sYcQSSnaQSOKh9
# uNgSsGjaIIRrHF5fhn0e8CADgyxCRufp7gQVB/Xew/4qfdeAwi8luosl4VxCNr5J
# R45e7lx+TF7QbNM2iN3IjDNoeWE5+VVFk2vF57cH7JnB3ckcMi+/vW5Ij9IjPO31
# xTYbIdBWrEFKtG0pbpbxXDvOlW+hWwi/eWPGD7s2IZKVdfWzvNsE0MxSP06fM6Uc
# r/eas5TxgS5F/pHBqRblQJ4ZqbLkyIq7Zi7IqIYEK/g4aE+y017sAuQQ6HwFfXa3
# ie25i76DD0vrII9jSNZhpC3MA/0wggdxMIIFWaADAgECAhMzAAAAFcXna54Cm0mZ
# AAAAAAAVMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMDAeFw0yMTA5MzAxODIyMjVaFw0zMDA5MzAxODMyMjVa
# MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMT
# HU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMIICIjANBgkqhkiG9w0BAQEF
# AAOCAg8AMIICCgKCAgEA5OGmTOe0ciELeaLL1yR5vQ7VgtP97pwHB9KpbE51yMo1
# V/YBf2xK4OK9uT4XYDP/XE/HZveVU3Fa4n5KWv64NmeFRiMMtY0Tz3cywBAY6GB9
# alKDRLemjkZrBxTzxXb1hlDcwUTIcVxRMTegCjhuje3XD9gmU3w5YQJ6xKr9cmmv
# Haus9ja+NSZk2pg7uhp7M62AW36MEBydUv626GIl3GoPz130/o5Tz9bshVZN7928
# jaTjkY+yOSxRnOlwaQ3KNi1wjjHINSi947SHJMPgyY9+tVSP3PoFVZhtaDuaRr3t
# pK56KTesy+uDRedGbsoy1cCGMFxPLOJiss254o2I5JasAUq7vnGpF1tnYN74kpEe
# HT39IM9zfUGaRnXNxF803RKJ1v2lIH1+/NmeRd+2ci/bfV+AutuqfjbsNkz2K26o
# ElHovwUDo9Fzpk03dJQcNIIP8BDyt0cY7afomXw/TNuvXsLz1dhzPUNOwTM5TI4C
# vEJoLhDqhFFG4tG9ahhaYQFzymeiXtcodgLiMxhy16cg8ML6EgrXY28MyTZki1ug
# poMhXV8wdJGUlNi5UPkLiWHzNgY1GIRH29wb0f2y1BzFa/ZcUlFdEtsluq9QBXps
# xREdcu+N+VLEhReTwDwV2xo3xwgVGD94q0W29R6HXtqPnhZyacaue7e3PmriLq0C
# AwEAAaOCAd0wggHZMBIGCSsGAQQBgjcVAQQFAgMBAAEwIwYJKwYBBAGCNxUCBBYE
# FCqnUv5kxJq+gpE8RjUpzxD/LwTuMB0GA1UdDgQWBBSfpxVdAF5iXYP05dJlpxtT
# NRnpcjBcBgNVHSAEVTBTMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wEwYDVR0lBAwwCgYIKwYBBQUHAwgwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBD
# AEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU1fZW
# y4/oolxiaNE9lJBb186aGMQwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5t
# aWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIwMTAt
# MDYtMjMuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0y
# My5jcnQwDQYJKoZIhvcNAQELBQADggIBAJ1VffwqreEsH2cBMSRb4Z5yS/ypb+pc
# FLY+TkdkeLEGk5c9MTO1OdfCcTY/2mRsfNB1OW27DzHkwo/7bNGhlBgi7ulmZzpT
# Td2YurYeeNg2LpypglYAA7AFvonoaeC6Ce5732pvvinLbtg/SHUB2RjebYIM9W0j
# VOR4U3UkV7ndn/OOPcbzaN9l9qRWqveVtihVJ9AkvUCgvxm2EhIRXT0n4ECWOKz3
# +SmJw7wXsFSFQrP8DJ6LGYnn8AtqgcKBGUIZUnWKNsIdw2FzLixre24/LAl4FOmR
# sqlb30mjdAy87JGA0j3mSj5mO0+7hvoyGtmW9I/2kQH2zsZ0/fZMcm8Qq3UwxTSw
# ethQ/gpY3UA8x1RtnWN0SCyxTkctwRQEcb9k+SS+c23Kjgm9swFXSVRk2XPXfx5b
# RAGOWhmRaw2fpCjcZxkoJLo4S5pu+yFUa2pFEUep8beuyOiJXk+d0tBMdrVXVAmx
# aQFEfnyhYWxz/gq77EFmPWn9y8FBSX5+k77L+DvktxW/tM4+pTFRhLy/AsGConsX
# HRWJjXD+57XQKBqJC4822rpM+Zv/Cuk0+CQ1ZyvgDbjmjJnW4SLq8CdCPSWU5nR0
# W2rRnj7tfqAxM328y+l7vzhwRNGQ8cirOoo6CGJ/2XBjU02N7oJtpQUQwXEGahC0
# HVUzWLOhcGbyoYIC1zCCAkACAQEwggEAoYHYpIHVMIHSMQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJlbGFu
# ZCBPcGVyYXRpb25zIExpbWl0ZWQxJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNOOkZD
# NDEtNEJENC1EMjIwMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2
# aWNloiMKAQEwBwYFKw4DAhoDFQDHYh4YeGTnwxCTPNJaScZwuN+BOqCBgzCBgKR+
# MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMT
# HU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBBQUAAgUA
# 6NJraTAiGA8yMDIzMTAxMjIwNTYwOVoYDzIwMjMxMDEzMjA1NjA5WjB3MD0GCisG
# AQQBhFkKBAExLzAtMAoCBQDo0mtpAgEAMAoCAQACAhS1AgH/MAcCAQACAhE6MAoC
# BQDo07zpAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEA
# AgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQEFBQADgYEALlJxgxcEpadcN2N+
# u/t8k4NmTXR138wfDhPTA4C0+yw14XksmytrLyE2EYJxDZhnn/pkTn5uTIgQr8dp
# Dt6bTaeapuxtX11EJsbGYEkDLRqGWBlwX+GCDxj6pfF60yUNpPkS0N6XY1lwGpgX
# j/nwNBFTJa8J3lV7EX5ZvmHq9aYxggQNMIIECQIBATCBkzB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMAITMwAAAbn2AA1lVE+8AwABAAABuTANBglghkgBZQME
# AgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJ
# BDEiBCAyxViUIxf/pq06a9AohFvmRgLeph6FmagfABaiuJTowzCB+gYLKoZIhvcN
# AQkQAi8xgeowgecwgeQwgb0EIGTrRs7xbzm5MB8lUQ7e9fZotpAVyBwal3Cw6iL5
# +g/0MIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAG5
# 9gANZVRPvAMAAQAAAbkwIgQg94BR+8Nsa0k5mNgBeu0mldAW/N/ORcRow3vDEWdR
# sFYwDQYJKoZIhvcNAQELBQAEggIAJdfFSz8mYEGCOQBYpjOAIWg6eimC0TdnmGUU
# E1I+Lv3/FeyYYWNsEUM6OLs/UN/tXcmX1WsX8+qUPNJp0FN2qFfHRmF1CdehMV4y
# 38GNdkFo+Dh4MitrhabOVqnOCzHd5sJXQ21MAS/gSw/NfO5Q1x8xwFJaOd9r7eaA
# nyrob32ZqPqgYUNNwySBo/+64BcmSDbN2LTUxsHyNRBZJVa6mz4d7Y0n2P9vRDWB
# 4CG02yY/7bUpXQBJQrkNEOdWOD90zTyEH4GcfZpFjt1SNLub+eJt80kHegHH6Jak
# s2A5KrHpB/DAjzjpAKuHf2vz8EYZUC0Qxzy83evNL+ipMNg1JavE7XckFWmLvBFJ
# lHq5p5iCV3U88vL0ixQHSkQxcECCEuzMeQD8LMMqfhFeBLapIE3kKhW2clRbNone
# fQ+UWEYfp1aKepcn+wU4e0bC5iWda/Dc+glQWqRX1XZF93r9VZlUrV4Oso80GZkc
# eoEY3KjesGNJoHsZdKlmM9q3SyqLn3EdJmY5z1vRSFxbkrl2CvDlPBMS/L1Pyn9g
# HRy6mPLl7SVoVDEEVgfHzyjRHCs2V+dKQfXCt0BQTPZGPO4xJiaxwt5qsUcI4B3/
# S2Dqw8T9Hh4S7DgD76pkpolqFRwzCTrUS5q9DGdK1utZSpHjY3FORukMmAPtrBaK
# Pe1CtxY=
# SIG # End signature block
