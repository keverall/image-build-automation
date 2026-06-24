##############################################################################
# AddStorageSystem_Sample.ps1
# - Example script for adding a supported Primera Storage System, creating Storage Pools
#   and Storage Volumes
#
#   VERSION 3.0
#
# (C) Copyright 2013-2024 Hewlett Packard Enterprise Development LP
##############################################################################
<#
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
#>
##############################################################################

if (-not (get-module HPEOneView.700))
{

    Import-Module HPEOneView.700

}

if (-not $ConnectedSessions)
{

    $Appliance = Read-Host 'ApplianceName'
    $Credential = Get-Credential -UserName Administrator -Message Password

    $ApplianceConnection = Connect-OVMgmt -Hostname $Appliance -Credential $Credential

}

#Connect a Storage System using OneView Expected Connectivity
$myStorageSystem      = "HPEStoreServ_1-array.contoso.com"
$myStorageSystemCreds = Get-Credential -Username 3paradm -Message "3Paradm password"


#Add Storage System specifying the Virtual Domain and Storage Host Ports
$params = @{

    hostname   = $myStorageSystem;
    credential = $myStorageSystemCreds;
    domain     = "NODOMAIN"
    Ports = @{

        "0:1:1" = "3PAR SAN DA A";
        "0:1:2" = "3PAR SAN Fabric A";
        "1:1:1" = "3PAR SAN Fabric B";
        "1:1:2" = "3PAR SAN DA B"

    };
    PortGroups = @{

        "0:1:1" = "PG_1";
        "0:1:2" = "PG_2";
        "1:1:1" = "PG_1";
        "1:1:2" = "PG_2"

    }

}

"Importing POD storage array: {0}" -f $params.hostname | Write-Host

Try
{

    Add-OVStorageSystem @params | Wait-OVTaskComplete

    Add-OVStoragePool HP-P7400-1 -poolName R1_FC_CPG | Wait-OVTaskComplete

}

Catch
{

    $PSCMdlet.ThrowTerminatingError($_)

}

#Add a second Storage System specifying the Virtual Domain and Storage Host Ports
$myStorageSystem       = "HP3Par_2-array.contoso.com"
$myStorageSystemAdmin  = "3paradm"
$myStorageSystemPass   = "3pardata"
$myStorageSystemDomain = "VirtualDomain1" #NOTE: The value is case sensitive.
$myStorageSystemPorts  = @{

    "1:1:1" = "Fabric A";
    "2:1:1" = "FabricA";
    "1:1:2" = "Fabric B";
    "2:1:2" = "Fabric B"
}

$myStorageSystemPG     = @{

    "0:1:1" = "PG_1";
    "0:1:2" = "PG_2";
    "1:1:1" = "PG_1";
    "1:1:2" = "PG_2"

}

$params = @{

    hostname   = $myStorageSystem;
    username   = $myStorageSystemAdmin;
    password   = $myStorageSystemPass;
    domain     = $myStorageSystemDomain;
    Ports      = $myStorageSystemPorts;
    PortGroups = $myStorageSystemPG

}

"Importing POD storage array: {0}" -f $params.hostname | Write-Host

Try
{

    Add-OVStorageSystem @params | Wait-OVTaskComplete

    Add-OVStoragePool -StorageSystem $myStorageSystem -PoolName R1_FC_CPG | Wait-OVTaskComplete

}

Catch
{

    $PSCMdlet.ThrowTerminatingError($_)

}

Get-OVStorageSystem

#Get Storage System Details
$myStorageSystem1 = Get-OVStorageSystem -Name HP3Par_1
$myStorageSystem2 = Get-OVStorageSystem -Name HP3Par_2


#Add Storage Pools in order to provision Storage Volumes
#HP3Par_1

Try
{

    $myStorageSystem1 | New-OVStoragePool -PoolName "FST_CPG1"
    $myStorageSystem1 | New-OVStoragePool -PoolName "FST_CPG2"

}

Catch
{

    Write-Error -ErrorRecord $_

}


#HP3Par_2

Try
{

    $myPools = @("FST_CPG3","FST_CPG4")
    $myStorageSystem2 | New-OVStoragePool -PoolName $myPools

}

Catch
{

    Write-Error -ErrorRecord $_

}

Get-OVStoragePool

$StroagePool1 = Get-OVStoragePool -Name FST_CPG1

#Create some volumes

Try
{

    1..10 | % { New-OVStorageVolume -name Vol$_ -Pool $StroagePool1 -Size 60 }

}

Catch
{

    Write-Error -ErrorRecord $_

}

Try
{

    1..5 | % { New-OVStorageVolume -name SharedVol$_ -StoragePool FST_CPG2 -Size 250 -shared }

}

Catch
{

    Write-Error -ErrorRecord $_

}

Get-OVStorageVolume
# SIG # Begin signature block
# MIIsFwYJKoZIhvcNAQcCoIIsCDCCLAQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB4WWWQfdiPp93z
# U0KpeV2+ukajWo8qaITpZvpZd6P8SKCCEXYwggVvMIIEV6ADAgECAhBI/JO0YFWU
# jTanyYqJ1pQWMA0GCSqGSIb3DQEBDAUAMHsxCzAJBgNVBAYTAkdCMRswGQYDVQQI
# DBJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcMB1NhbGZvcmQxGjAYBgNVBAoM
# EUNvbW9kbyBDQSBMaW1pdGVkMSEwHwYDVQQDDBhBQUEgQ2VydGlmaWNhdGUgU2Vy
# dmljZXMwHhcNMjEwNTI1MDAwMDAwWhcNMjgxMjMxMjM1OTU5WjBWMQswCQYDVQQG
# EwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMS0wKwYDVQQDEyRTZWN0aWdv
# IFB1YmxpYyBDb2RlIFNpZ25pbmcgUm9vdCBSNDYwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQCN55QSIgQkdC7/FiMCkoq2rjaFrEfUI5ErPtx94jGgUW+s
# hJHjUoq14pbe0IdjJImK/+8Skzt9u7aKvb0Ffyeba2XTpQxpsbxJOZrxbW6q5KCD
# J9qaDStQ6Utbs7hkNqR+Sj2pcaths3OzPAsM79szV+W+NDfjlxtd/R8SPYIDdub7
# P2bSlDFp+m2zNKzBenjcklDyZMeqLQSrw2rq4C+np9xu1+j/2iGrQL+57g2extme
# me/G3h+pDHazJyCh1rr9gOcB0u/rgimVcI3/uxXP/tEPNqIuTzKQdEZrRzUTdwUz
# T2MuuC3hv2WnBGsY2HH6zAjybYmZELGt2z4s5KoYsMYHAXVn3m3pY2MeNn9pib6q
# RT5uWl+PoVvLnTCGMOgDs0DGDQ84zWeoU4j6uDBl+m/H5x2xg3RpPqzEaDux5mcz
# mrYI4IAFSEDu9oJkRqj1c7AGlfJsZZ+/VVscnFcax3hGfHCqlBuCF6yH6bbJDoEc
# QNYWFyn8XJwYK+pF9e+91WdPKF4F7pBMeufG9ND8+s0+MkYTIDaKBOq3qgdGnA2T
# OglmmVhcKaO5DKYwODzQRjY1fJy67sPV+Qp2+n4FG0DKkjXp1XrRtX8ArqmQqsV/
# AZwQsRb8zG4Y3G9i/qZQp7h7uJ0VP/4gDHXIIloTlRmQAOka1cKG8eOO7F/05QID
# AQABo4IBEjCCAQ4wHwYDVR0jBBgwFoAUoBEKIz6W8Qfs4q8p74Klf9AwpLQwHQYD
# VR0OBBYEFDLrkpr/NZZILyhAQnAgNpFcF4XmMA4GA1UdDwEB/wQEAwIBhjAPBgNV
# HRMBAf8EBTADAQH/MBMGA1UdJQQMMAoGCCsGAQUFBwMDMBsGA1UdIAQUMBIwBgYE
# VR0gADAIBgZngQwBBAEwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2NybC5jb21v
# ZG9jYS5jb20vQUFBQ2VydGlmaWNhdGVTZXJ2aWNlcy5jcmwwNAYIKwYBBQUHAQEE
# KDAmMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5jb21vZG9jYS5jb20wDQYJKoZI
# hvcNAQEMBQADggEBABK/oe+LdJqYRLhpRrWrJAoMpIpnuDqBv0WKfVIHqI0fTiGF
# OaNrXi0ghr8QuK55O1PNtPvYRL4G2VxjZ9RAFodEhnIq1jIV9RKDwvnhXRFAZ/ZC
# J3LFI+ICOBpMIOLbAffNRk8monxmwFE2tokCVMf8WPtsAO7+mKYulaEMUykfb9gZ
# pk+e96wJ6l2CxouvgKe9gUhShDHaMuwV5KZMPWw5c9QLhTkg4IUaaOGnSDip0TYl
# d8GNGRbFiExmfS9jzpjoad+sPKhdnckcW67Y8y90z7h+9teDnRGWYpquRRPaf9xH
# +9/DUp/mBlXpnYzyOmJRvOwkDynUWICE5EV7WtgwggXhMIIESaADAgECAhEA83w3
# gf2o8H0GHWXSUybisjANBgkqhkiG9w0BAQwFADBUMQswCQYDVQQGEwJHQjEYMBYG
# A1UEChMPU2VjdGlnbyBMaW1pdGVkMSswKQYDVQQDEyJTZWN0aWdvIFB1YmxpYyBD
# b2RlIFNpZ25pbmcgQ0EgUjM2MB4XDTIyMDYwNzAwMDAwMFoXDTI1MDYwNjIzNTk1
# OVowdzELMAkGA1UEBhMCVVMxDjAMBgNVBAgMBVRleGFzMSswKQYDVQQKDCJIZXds
# ZXR0IFBhY2thcmQgRW50ZXJwcmlzZSBDb21wYW55MSswKQYDVQQDDCJIZXdsZXR0
# IFBhY2thcmQgRW50ZXJwcmlzZSBDb21wYW55MIIBojANBgkqhkiG9w0BAQEFAAOC
# AY8AMIIBigKCAYEA3nXTSeo4pVdKrf7RlSd2tDEbwbNsAuOo9sKzn6H1kVFshc5b
# ALe9NHmnAsdDFhmcriSrlCPsKekOpmBzUY+hjMTv7eF99bR1rA5tvQQvEdkGkzyN
# 2ZpFc2h7WiImjuGapcXXu8YpSm9seDgSbKnLtS/WAer5K/x30t4BBXm4j7nScY6E
# 0V3ZwkueiVNq0uiUjmGXxqzDgPQmP4H9Gt5mfrQdmpFMccfv9KC4TbbT0m0WHZte
# ebUIBJCWyJQHNJZES9oytn10QoSeBxclInXGzG7q6PIkyXSds7RsBm25gmBRvrm8
# Uf33JnfBEyyd6AH0nfSUVylOYlrLexniH5Kdrq96spk9Wj+7pq5fSXcjULZSunMN
# 6gIrQG+d7NvxuaUkjwDx+3k/A0daJc4hiHcOJa4kjK2SmQ3e27Z4FsiTUWk88C+t
# 1yya6Q/KmT8DcTfHOBpyF0mDEPJYsU5X/jquFRNrG6fzDuKkse3MEbc641HDap/n
# Ldwm7gztHt/IFc4JAgMBAAGjggGJMIIBhTAfBgNVHSMEGDAWgBQPKssghyi47G9I
# ritUpimqF6TNDDAdBgNVHQ4EFgQU9ol95gfMeTfyaXeTTny+MR/YG/UwDgYDVR0P
# AQH/BAQDAgeAMAwGA1UdEwEB/wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUHAwMwSgYD
# VR0gBEMwQTA1BgwrBgEEAbIxAQIBAwIwJTAjBggrBgEFBQcCARYXaHR0cHM6Ly9z
# ZWN0aWdvLmNvbS9DUFMwCAYGZ4EMAQQBMEkGA1UdHwRCMEAwPqA8oDqGOGh0dHA6
# Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY0NvZGVTaWduaW5nQ0FSMzYu
# Y3JsMHkGCCsGAQUFBwEBBG0wazBEBggrBgEFBQcwAoY4aHR0cDovL2NydC5zZWN0
# aWdvLmNvbS9TZWN0aWdvUHVibGljQ29kZVNpZ25pbmdDQVIzNi5jcnQwIwYIKwYB
# BQUHMAGGF2h0dHA6Ly9vY3NwLnNlY3RpZ28uY29tMA0GCSqGSIb3DQEBDAUAA4IB
# gQAdJNlWSujYBAZ1mdIy0Q66db+4YWP+FbaUiQWNqbfi30s7Ctg70/2t0n1QDDkg
# hWHFM2kcdy1PGh4fOMeRSfIhsTre54YcsNe5wELSJQbvN8lfPYXMThb3n4/BXxoD
# 1zx5rmcwGPXVF5oIZJub5FzMNVpECjy8C42skTFXv4eB/yEHKI/BWsjvnkldkNEG
# 3v8Y/23gGHruFy2qVW50xyH8zsjd+gIStVojyhPJ0jgtZvXgxwVJYwBGJwgYOO+q
# pRnuUp4Bse+KlA8Ttm+Q4Nx8qOJYBE44Qi8BUXwoEDs26pFIyNuszBFuzeyL4Wkx
# y7srdCWYCIyLbD5b7WFbhd2ieK2Mg+WtZJNB3t8ZpdLLkH4vPmZGIo4FkeAST1I1
# XtKp5PqLhzPEZbsY9JL8i6XvedCL8cHe1zVX3eM9EPL/jxw9kLcFrFN+DQ1wIHCc
# gEH7/RYXc9abuGcC2XpP4YbzSMWbff8X/Pgw8HA8aSRhctF+bz7dI+/REmlDJtdP
# T6wwggYaMIIEAqADAgECAhBiHW0MUgGeO5B5FSCJIRwKMA0GCSqGSIb3DQEBDAUA
# MFYxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLTArBgNV
# BAMTJFNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBSb290IFI0NjAeFw0yMTAz
# MjIwMDAwMDBaFw0zNjAzMjEyMzU5NTlaMFQxCzAJBgNVBAYTAkdCMRgwFgYDVQQK
# Ew9TZWN0aWdvIExpbWl0ZWQxKzApBgNVBAMTIlNlY3RpZ28gUHVibGljIENvZGUg
# U2lnbmluZyBDQSBSMzYwggGiMA0GCSqGSIb3DQEBAQUAA4IBjwAwggGKAoIBgQCb
# K51T+jU/jmAGQ2rAz/V/9shTUxjIztNsfvxYB5UXeWUzCxEeAEZGbEN4QMgCsJLZ
# UKhWThj/yPqy0iSZhXkZ6Pg2A2NVDgFigOMYzB2OKhdqfWGVoYW3haT29PSTahYk
# wmMv0b/83nbeECbiMXhSOtbam+/36F09fy1tsB8je/RV0mIk8XL/tfCK6cPuYHE2
# 15wzrK0h1SWHTxPbPuYkRdkP05ZwmRmTnAO5/arnY83jeNzhP06ShdnRqtZlV59+
# 8yv+KIhE5ILMqgOZYAENHNX9SJDm+qxp4VqpB3MV/h53yl41aHU5pledi9lCBbH9
# JeIkNFICiVHNkRmq4TpxtwfvjsUedyz8rNyfQJy/aOs5b4s+ac7IH60B+Ja7TVM+
# EKv1WuTGwcLmoU3FpOFMbmPj8pz44MPZ1f9+YEQIQty/NQd/2yGgW+ufflcZ/ZE9
# o1M7a5Jnqf2i2/uMSWymR8r2oQBMdlyh2n5HirY4jKnFH/9gRvd+QOfdRrJZb1sC
# AwEAAaOCAWQwggFgMB8GA1UdIwQYMBaAFDLrkpr/NZZILyhAQnAgNpFcF4XmMB0G
# A1UdDgQWBBQPKssghyi47G9IritUpimqF6TNDDAOBgNVHQ8BAf8EBAMCAYYwEgYD
# VR0TAQH/BAgwBgEB/wIBADATBgNVHSUEDDAKBggrBgEFBQcDAzAbBgNVHSAEFDAS
# MAYGBFUdIAAwCAYGZ4EMAQQBMEsGA1UdHwREMEIwQKA+oDyGOmh0dHA6Ly9jcmwu
# c2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY0NvZGVTaWduaW5nUm9vdFI0Ni5jcmww
# ewYIKwYBBQUHAQEEbzBtMEYGCCsGAQUFBzAChjpodHRwOi8vY3J0LnNlY3RpZ28u
# Y29tL1NlY3RpZ29QdWJsaWNDb2RlU2lnbmluZ1Jvb3RSNDYucDdjMCMGCCsGAQUF
# BzABhhdodHRwOi8vb2NzcC5zZWN0aWdvLmNvbTANBgkqhkiG9w0BAQwFAAOCAgEA
# Bv+C4XdjNm57oRUgmxP/BP6YdURhw1aVcdGRP4Wh60BAscjW4HL9hcpkOTz5jUug
# 2oeunbYAowbFC2AKK+cMcXIBD0ZdOaWTsyNyBBsMLHqafvIhrCymlaS98+QpoBCy
# KppP0OcxYEdU0hpsaqBBIZOtBajjcw5+w/KeFvPYfLF/ldYpmlG+vd0xqlqd099i
# ChnyIMvY5HexjO2AmtsbpVn0OhNcWbWDRF/3sBp6fWXhz7DcML4iTAWS+MVXeNLj
# 1lJziVKEoroGs9Mlizg0bUMbOalOhOfCipnx8CaLZeVme5yELg09Jlo8BMe80jO3
# 7PU8ejfkP9/uPak7VLwELKxAMcJszkyeiaerlphwoKx1uHRzNyE6bxuSKcutisqm
# KL5OTunAvtONEoteSiabkPVSZ2z76mKnzAfZxCl/3dq3dUNw4rg3sTCggkHSRqTq
# lLMS7gjrhTqBmzu1L90Y1KWN/Y5JKdGvspbOrTfOXyXvmPL6E52z1NZJ6ctuMFBQ
# ZH3pwWvqURR8AgQdULUvrxjUYbHHj95Ejza63zdrEcxWLDX6xWls/GDnVNueKjWU
# H3fTv1Y8Wdho698YADR7TNx8X8z2Bev6SivBBOHY+uqiirZtg0y9ShQoPzmCcn63
# Syatatvx157YK9hlcPmVoa1oDE5/L9Uo2bC5a4CH2Rwxghn3MIIZ8wIBATBpMFQx
# CzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxKzApBgNVBAMT
# IlNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBDQSBSMzYCEQDzfDeB/ajwfQYd
# ZdJTJuKyMA0GCWCGSAFlAwQCAQUAoHwwEAYKKwYBBAGCNwIBDDECMAAwGQYJKoZI
# hvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcC
# ARUwLwYJKoZIhvcNAQkEMSIEIBf/RpOzOVuhxSKq/Rm2PXHdSYAWiJRsQRmc9Wij
# mIEZMA0GCSqGSIb3DQEBAQUABIIBgKCfAzUDmkrJjKxM52QSQCstVxUfgoAtwEZK
# G2GITexX5J+/I1W97rZHA19rg9r03mLBU9hSRWYXiycdIlqSzWPlN+L0nTfQhCJ/
# ycZTvO94j9Va0/qKvcPTUkuV0vYAmqw6q8v0tpEIlgJIfbDrRsamHd/uqOLnl/4P
# M070i+jVIVdQzdiXNYHdXDaMIpxdRJm5HmMVvOhCa8LhsAXdWTaYMq/GcHwBYkpQ
# pH7T6V4Tr/QCJXEgKfS4BM4ztTG2C7Oma5PCZ0rVIUNtpWhdWeMVsjctZRdL2/8E
# cN1zBZoZ9Qx05HFm56KLfD3W/ids3PjwHpB0fVj0PFpXeiC20At2Tqo1hJsxpJRN
# ezH+Dzc3XnUuBHvMVY4T5344+bBwkHjgzsEkLznuScCTnEeTR9xjxxbK+yIvoGRr
# y6O3p3YEuJ/nAdMK3UWyjQK7y+gYDxBaN3FV4Oo+Ti/16BaETe/sJMTsdJiLvV7a
# 09FTNQmQZZcoXfmRW55EtpeN0ejv0qGCF2EwghddBgorBgEEAYI3AwMBMYIXTTCC
# F0kGCSqGSIb3DQEHAqCCFzowghc2AgEDMQ8wDQYJYIZIAWUDBAICBQAwgYgGCyqG
# SIb3DQEJEAEEoHkEdzB1AgEBBglghkgBhv1sBwEwQTANBglghkgBZQMEAgIFAAQw
# sQr+m1ByRR6qGLwzhSMMTYW/XnyukvQLDsh43awSfJDuGDfQfia+6WkEkHQDFqcw
# AhEAt2O8sfizg/syo5u0o/hgtRgPMjAyNDA5MTEwMTQ3NTdaoIITCTCCBsIwggSq
# oAMCAQICEAVEr/OUnQg5pr/bP1/lYRYwDQYJKoZIhvcNAQELBQAwYzELMAkGA1UE
# BhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2Vy
# dCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQTAeFw0y
# MzA3MTQwMDAwMDBaFw0zNDEwMTMyMzU5NTlaMEgxCzAJBgNVBAYTAlVTMRcwFQYD
# VQQKEw5EaWdpQ2VydCwgSW5jLjEgMB4GA1UEAxMXRGlnaUNlcnQgVGltZXN0YW1w
# IDIwMjMwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCjU0WHHYOOW6w+
# VLMj4M+f1+XS512hDgncL0ijl3o7Kpxn3GIVWMGpkxGnzaqyat0QKYoeYmNp01ic
# NXG/OpfrlFCPHCDqx5o7L5Zm42nnaf5bw9YrIBzBl5S0pVCB8s/LB6YwaMqDQtr8
# fwkklKSCGtpqutg7yl3eGRiF+0XqDWFsnf5xXsQGmjzwxS55DxtmUuPI1j5f2kPT
# hPXQx/ZILV5FdZZ1/t0QoRuDwbjmUpW1R9d4KTlr4HhZl+NEK0rVlc7vCBfqgmRN
# /yPjyobutKQhZHDr1eWg2mOzLukF7qr2JPUdvJscsrdf3/Dudn0xmWVHVZ1KJC+s
# K5e+n+T9e3M+Mu5SNPvUu+vUoCw0m+PebmQZBzcBkQ8ctVHNqkxmg4hoYru8QRt4
# GW3k2Q/gWEH72LEs4VGvtK0VBhTqYggT02kefGRNnQ/fztFejKqrUBXJs8q818Q7
# aESjpTtC/XN97t0K/3k0EH6mXApYTAA+hWl1x4Nk1nXNjxJ2VqUk+tfEayG66B80
# mC866msBsPf7Kobse1I4qZgJoXGybHGvPrhvltXhEBP+YUcKjP7wtsfVx95sJPC/
# QoLKoHE9nJKTBLRpcCcNT7e1NtHJXwikcKPsCvERLmTgyyIryvEoEyFJUX4GZtM7
# vvrrkTjYUQfKlLfiUKHzOtOKg8tAewIDAQABo4IBizCCAYcwDgYDVR0PAQH/BAQD
# AgeAMAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwIAYDVR0g
# BBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMB8GA1UdIwQYMBaAFLoW2W1NhS9z
# KXaaL3WMaiCPnshvMB0GA1UdDgQWBBSltu8T5+/N0GSh1VapZTGj3tXjSTBaBgNV
# HR8EUzBRME+gTaBLhklodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRU
# cnVzdGVkRzRSU0E0MDk2U0hBMjU2VGltZVN0YW1waW5nQ0EuY3JsMIGQBggrBgEF
# BQcBAQSBgzCBgDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29t
# MFgGCCsGAQUFBzAChkxodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNl
# cnRUcnVzdGVkRzRSU0E0MDk2U0hBMjU2VGltZVN0YW1waW5nQ0EuY3J0MA0GCSqG
# SIb3DQEBCwUAA4ICAQCBGtbeoKm1mBe8cI1PijxonNgl/8ss5M3qXSKS7IwiAqm4
# z4Co2efjxe0mgopxLxjdTrbebNfhYJwr7e09SI64a7p8Xb3CYTdoSXej65CqEtcn
# hfOOHpLawkA4n13IoC4leCWdKgV6hCmYtld5j9smViuw86e9NwzYmHZPVrlSwrad
# OKmB521BXIxp0bkrxMZ7z5z6eOKTGnaiaXXTUOREEr4gDZ6pRND45Ul3CFohxbTP
# mJUaVLq5vMFpGbrPFvKDNzRusEEm3d5al08zjdSNd311RaGlWCZqA0Xe2VC1UIyv
# Vr1MxeFGxSjTredDAHDezJieGYkD6tSRN+9NUvPJYCHEVkft2hFLjDLDiOZY4rbb
# PvlfsELWj+MXkdGqwFXjhr+sJyxB0JozSqg21Llyln6XeThIX8rC3D0y33XWNmda
# ifj2p8flTzU8AL2+nCpseQHc2kTmOt44OwdeOVj0fHMxVaCAEcsUDH6uvP6k63ll
# qmjWIso765qCNVcoFstp8jKastLYOrixRoZruhf9xHdsFWyuq69zOuhJRrfVf8y2
# OMDY7Bz1tqG4QyzfTkx9HmhwwHcK1ALgXGC7KP845VJa1qwXIiNO9OzTF/tQa/8H
# dx9xl0RBybhG02wyfFgvZ0dl5Rtztpn5aywGRu9BHvDwX+Db2a2QgESvgBBBijCC
# Bq4wggSWoAMCAQICEAc2N7ckVHzYR6z9KGYqXlswDQYJKoZIhvcNAQELBQAwYjEL
# MAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3
# LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0
# MB4XDTIyMDMyMzAwMDAwMFoXDTM3MDMyMjIzNTk1OVowYzELMAkGA1UEBhMCVVMx
# FzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVz
# dGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQTCCAiIwDQYJKoZI
# hvcNAQEBBQADggIPADCCAgoCggIBAMaGNQZJs8E9cklRVcclA8TykTepl1Gh1tKD
# 0Z5Mom2gsMyD+Vr2EaFEFUJfpIjzaPp985yJC3+dH54PMx9QEwsmc5Zt+FeoAn39
# Q7SE2hHxc7Gz7iuAhIoiGN/r2j3EF3+rGSs+QtxnjupRPfDWVtTnKC3r07G1decf
# BmWNlCnT2exp39mQh0YAe9tEQYncfGpXevA3eZ9drMvohGS0UvJ2R/dhgxndX7RU
# CyFobjchu0CsX7LeSn3O9TkSZ+8OpWNs5KbFHc02DVzV5huowWR0QKfAcsW6Th+x
# tVhNef7Xj3OTrCw54qVI1vCwMROpVymWJy71h6aPTnYVVSZwmCZ/oBpHIEPjQ2OA
# e3VuJyWQmDo4EbP29p7mO1vsgd4iFNmCKseSv6De4z6ic/rnH1pslPJSlRErWHRA
# KKtzQ87fSqEcazjFKfPKqpZzQmiftkaznTqj1QPgv/CiPMpC3BhIfxQ0z9JMq++b
# Pf4OuGQq+nUoJEHtQr8FnGZJUlD0UfM2SU2LINIsVzV5K6jzRWC8I41Y99xh3pP+
# OcD5sjClTNfpmEpYPtMDiP6zj9NeS3YSUZPJjAw7W4oiqMEmCPkUEBIDfV8ju2Tj
# Y+Cm4T72wnSyPx4JduyrXUZ14mCjWAkBKAAOhFTuzuldyF4wEr1GnrXTdrnSDmuZ
# DNIztM2xAgMBAAGjggFdMIIBWTASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQW
# BBS6FtltTYUvcyl2mi91jGogj57IbzAfBgNVHSMEGDAWgBTs1+OC0nFdZEzfLmc/
# 57qYrhwPTzAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwgwdwYI
# KwYBBQUHAQEEazBpMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5j
# b20wQQYIKwYBBQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydFRydXN0ZWRSb290RzQuY3J0MEMGA1UdHwQ8MDowOKA2oDSGMmh0dHA6Ly9j
# cmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3JsMCAGA1Ud
# IAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAgEA
# fVmOwJO2b5ipRCIBfmbW2CFC4bAYLhBNE88wU86/GPvHUF3iSyn7cIoNqilp/GnB
# zx0H6T5gyNgL5Vxb122H+oQgJTQxZ822EpZvxFBMYh0MCIKoFr2pVs8Vc40BIiXO
# lWk/R3f7cnQU1/+rT4osequFzUNf7WC2qk+RZp4snuCKrOX9jLxkJodskr2dfNBw
# CnzvqLx1T7pa96kQsl3p/yhUifDVinF2ZdrM8HKjI/rAJ4JErpknG6skHibBt94q
# 6/aesXmZgaNWhqsKRcnfxI2g55j7+6adcq/Ex8HBanHZxhOACcS2n82HhyS7T6NJ
# uXdmkfFynOlLAlKnN36TU6w7HQhJD5TNOXrd/yVjmScsPT9rp/Fmw0HNT7ZAmyEh
# QNC3EyTN3B14OuSereU0cZLXJmvkOHOrpgFPvT87eK1MrfvElXvtCl8zOYdBeHo4
# 6Zzh3SP9HSjTx/no8Zhf+yvYfvJGnXUsHicsJttvFXseGYs2uJPU5vIXmVnKcPA3
# v5gA3yAWTyf7YGcWoWa63VXAOimGsJigK+2VQbc61RWYMbRiCQ8KvYHZE/6/pNHz
# V9m8BPqC3jLfBInwAM1dwvnQI38AC+R2AibZ8GV2QqYphwlHK+Z/GqSFD/yYlvZV
# VCsfgPrA8g4r5db7qS9EFUrnEw4d2zc4GqEr9u3WfPwwggWNMIIEdaADAgECAhAO
# mxiO+dAt5+/bUOIIQBhaMA0GCSqGSIb3DQEBDAUAMGUxCzAJBgNVBAYTAlVTMRUw
# EwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20x
# JDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0yMjA4MDEw
# MDAwMDBaFw0zMTExMDkyMzU5NTlaMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxE
# aWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMT
# GERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDCCAiIwDQYJKoZIhvcNAQEBBQADggIP
# ADCCAgoCggIBAL/mkHNo3rvkXUo8MCIwaTPswqclLskhPfKK2FnC4SmnPVirdprN
# rnsbhA3EMB/zG6Q4FutWxpdtHauyefLKEdLkX9YFPFIPUh/GnhWlfr6fqVcWWVVy
# r2iTcMKyunWZanMylNEQRBAu34LzB4TmdDttceItDBvuINXJIB1jKS3O7F5OyJP4
# IWGbNOsFxl7sWxq868nPzaw0QF+xembud8hIqGZXV59UWI4MK7dPpzDZVu7Ke13j
# rclPXuU15zHL2pNe3I6PgNq2kZhAkHnDeMe2scS1ahg4AxCN2NQ3pC4FfYj1gj4Q
# kXCrVYJBMtfbBHMqbpEBfCFM1LyuGwN1XXhm2ToxRJozQL8I11pJpMLmqaBn3aQn
# vKFPObURWBf3JFxGj2T3wWmIdph2PVldQnaHiZdpekjw4KISG2aadMreSx7nDmOu
# 5tTvkpI6nj3cAORFJYm2mkQZK37AlLTSYW3rM9nF30sEAMx9HJXDj/chsrIRt7t/
# 8tWMcCxBYKqxYxhElRp2Yn72gLD76GSmM9GJB+G9t+ZDpBi4pncB4Q+UDCEdslQp
# JYls5Q5SUUd0viastkF13nqsX40/ybzTQRESW+UQUOsxxcpyFiIJ33xMdT9j7CFf
# xCBRa2+xq4aLT8LWRV+dIPyhHsXAj6KxfgommfXkaS+YHS312amyHeUbAgMBAAGj
# ggE6MIIBNjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTs1+OC0nFdZEzfLmc/
# 57qYrhwPTzAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzAOBgNVHQ8B
# Af8EBAMCAYYweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2Nz
# cC5kaWdpY2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2lj
# ZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwRQYDVR0fBD4wPDA6
# oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElE
# Um9vdENBLmNybDARBgNVHSAECjAIMAYGBFUdIAAwDQYJKoZIhvcNAQEMBQADggEB
# AHCgv0NcVec4X6CjdBs9thbX979XB72arKGHLOyFXqkauyL4hxppVCLtpIh3bb0a
# FPQTSnovLbc47/T/gLn4offyct4kvFIDyE7QKt76LVbP+fT3rDB6mouyXtTP0UNE
# m0Mh65ZyoUi0mcudT6cGAxN3J0TU53/oWajwvy8LpunyNDzs9wPHh6jSTEAZNUZq
# aVSwuKFWjuyk1T3osdz9HNj0d1pcVIxv76FQPfx2CWiEn2/K2yCNNWAcAgPLILCs
# WKAOQGPFmCLBsln1VWvPJ6tsds5vIy30fnFqI2si/xK4VC0nftg62fC2h5b9W9Fc
# rBjDTZ9ztwGpn1eqXijiuZQxggOGMIIDggIBATB3MGMxCzAJBgNVBAYTAlVTMRcw
# FQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMyRGlnaUNlcnQgVHJ1c3Rl
# ZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcgQ0ECEAVEr/OUnQg5pr/b
# P1/lYRYwDQYJYIZIAWUDBAICBQCggeEwGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJ
# EAEEMBwGCSqGSIb3DQEJBTEPFw0yNDA5MTEwMTQ3NTdaMCsGCyqGSIb3DQEJEAIM
# MRwwGjAYMBYEFGbwKzLCwskPgl3OqorJxk8ZnM9AMDcGCyqGSIb3DQEJEAIvMSgw
# JjAkMCIEINL25G3tdCLM0dRAV2hBNm+CitpVmq4zFq9NGprUDHgoMD8GCSqGSIb3
# DQEJBDEyBDCppVJSTOMGr43XRMadgmaxs6G02QnsgUtNpxE8by5Hsq5bVyKa0xSO
# J12Kqc2Y6ZkwDQYJKoZIhvcNAQEBBQAEggIAIgDwd+lkuZAvM7H2yWLQ5q5if+Xm
# f/9T86gydCx68Kvm1mVvwijC57ggeDbKlyPzAmdnsDjVd7mf/tqP+uU5seX7n25c
# El0dZ/FYe8O9yhRXCnG5nxhU467gwOuM120OOJfrlT+6FyTDITwoAa++yRP0F2Jt
# z6nXTjpw+3SROpJk0Td94koNMLTLHcaKFYmblMnMoMFlU3NTYegaJrYpPe3OZ2g3
# BH6YT1YGPJJNkV++GJJwiE1KJUDU6ETlEoUV5GDlrFLGg130E2hSAaOofKi5MMtW
# Wtbdm/s5Qra5O99sHYkzztlmDLdYW8bUszmjtuzg0bR/TfEBhLNdUtS2WXEI1jAU
# HQC0vqqIYGMlQJym6j/FhstAaUvEugUiRqv55xKu1nDIf1urVa+t8Su48eRMZJrQ
# vzrRXujcGoSpTnXv25K/g/8dRTnGixCBOX3S3rUfrWuqnZe7tZmG5IBbOawMBTr8
# ZLgcqD0ldJ6TyebjLAH1kz8VKnYKwZp1XKU+P+rNAQWYzbi0iJTSB8puEG4Z5r+Q
# Ij1cUIIq7SpFEXrS7y/D15QJ1I0joVw+fc8Y3kX0yqkwC08B5mYihJKt6eYNlLQq
# +fOQSWwogJhLd2TwsGkxKrNY4EuxAVlAzL7+I/axiMAOUayYnr9F++LdFjy5GlUD
# 5pOQ3cL2CcU8or8=
# SIG # End signature block
