##############################################################################
# Server_Multiconnection_SAN_Storage_Sample.ps1
#
# Example script to demonstrate creating a Server Profile with the following:
#
# - Configure 2 NICs in paired with Red
# - Configure 2 NICs in paired with Black
# - Configure 2 NICs in paired with NetworkSet (Production Networks)
# - Configure 2 FC connections to the Production Fabric A and B
# - Set requested bandwidth
# - Attach SAN Storage
#
#   VERSION 3.1
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
if (-not (get-module HPEOneView.630))
{

    Import-Module HPEOneView.630

}

if (-not $ConnectedSessions)
{

	$Appliance = Read-Host 'ApplianceName'
	$Username  = Read-Host 'Username'
	$Password  = Read-Host 'Password' -AsSecureString

    $ApplianceConnection = Connect-OVMgmt -Hostname $Appliance -Username $Username -Password $Password

}

# Now view what enclosures have been imported
Write-Host "Here is the list of enclosures managed by this appliance"
Get-OVEnclosure

# Now list all the servers that have been imported with their current state
$servers = Get-OVServer
Write-Host "There are [$servers.Count] servers managed by this appliance."
Get-OVServer

# Make sure all the servers are powered off
$servers | % {
    if ($_.powerState -ne "Off") {
        Write-Host "Server '$_.name' is ($_.powerState).  Powering off..."
        $Server | Stop-OVServer -Confirm:$false
    }
}

# Now create a server profile for the first available server
$server = Get-OVServer -NoProfile | Select -First 1

$profileName = "Profile-" + $server.serialNumber
Write-Host "Creating" $profileName "for server" $server.name

# Assume that networks "red" and "blue" are available for this server
$netRed = Get-OVNetwork "red"
$conRed1 = New-OVProfileConnection -id 1 -type Ethernet -requestedBW 1000 -network $netRed
$conRed2 = New-OVProfileConnection -id 2 -type Ethernet -requestedBW 1000 -network $netRed

$netProdFCA = Get-OVNetwork "Production Fabric A"
$conFC1 = New-OVProfileConnection -id 3 -type FibreChannel -requestedBW 4000 -network $netProdFCA
$netProdFCB = Get-OVNetwork "Production Fabric B"
$conFC2 = New-OVProfileConnection -id 4 -type FibreChannel -requestedBW 4000 -network $netProdFCB

$netBlack = Get-OVNetwork "black"
$conBlack1 = New-OVProfileConnection -id 5 -type Ethernet -requestedBW 2000 -network $netBlack
$conBlack2 = New-OVProfileConnection -id 6 -type Ethernet -requestedBW 2000 -network $netBlack

$netSetProd = Get-OVNetworkSet "Production Networks"
$conSet1 = New-OVProfileConnection -id 7 -type Ethernet -requestedBW 3000 -network $netSetProd
$conSet2 = New-OVProfileConnection -id 8 -type Ethernet -requestedBW 3000 -network $netSetProd

#Build array of connections for the profile
$conList = @($conRed1, $conRed2, $conBlack1, $conBlack2, $conSet1, $conSet2, $conFC1, $conFC2)

#Attach Volumes
$volume1 = Get-OVStorageVolume -Name Volume1 | Get-OVProfileAttachVolume -volumeid 1
$volume2 = Get-OVStorageVolume -Name SharedVolume1 | Get-OVProfileAttachVolume -volumeid 2
$attachVolumes = @($volume1,$volume2)

#Submit profile to the appliance
$task = New-OVProfile -name $profileName -server $server -connections $conList -SANStorage -HostOsType VMware -StorageVolume $attachVolumes -Async

#Monitor the profile async task progress
Write-Host $task.name $task.taskStatus
$task = $task | Wait-OVTaskComplete


# Change Connection ID 5 and 6 to "green" in the profile we just created
$profile = Send-OVRequest $task.associatedResource.resourceUri
Write-Host "Adding network to" $profile.name

#Validate the Server Power is off prior to modifying Connections (Requirement for 1.00 and 1.01)
if ($server.powerState -ne "Off") {
    Write-Host "Server" $server.name "is" $server.powerState ".  Powering it off..."
    $Server | Stop-OVServer -Confirm:$false
}

$netGreen = Get-OVNetwork "green"
$conGreen1 = New-OVProfileConnection -connectionId 5 -type Ethernet -network $netGreen
$conGreen2 = New-OVProfileConnection -connectionId 6 -type Ethernet -network $netGreen
$profile.connections = $profile.connections + $conGreen1 + $conGreen2
$task = Set-OVResource $profile
$task = Wait-OVTaskComplete -taskUri $task.uri

# Display the connections for our profile
$profile = Send-OVRequest $task.associatedResource.resourceUri
$profile.connections | Format-Table

# ADVANCED SERVER SETTINGS
# First view the capabilities of the server hardware for this profile
$serverType = Send-OVRequest $profile.serverHardwareTypeUri
Write-Host "Boot options for this server:" $serverType.bootCapabilities

# Set the boot order for the server
$profile.boot.order = @("PXE", "HardDisk", "USB", "CD", "Floppy", "FibreChannelHba")
$profile.boot.manageBoot = $true
Write-Host "Set boot order to" $profile.boot.order

#Set the BIOS setting to disable external USB ports
Write-Host "There are" $serverType.biosSettings.Count "possible BIOS settings for this server"
foreach ($setting in $serverType.biosSettings) {
    if ($setting.name.Contains("USB Control")) {
        foreach ($option in $setting.options) {
            if ($option.name.Contains("External")) {
                $profile.bios.manageBios = $true
                $profile.bios.overriddenSettings =
                    @(@{id=$setting.id;value=$option.id})
                Write-Host $setting.name ":" $option.name
                break
            }
        }
        break
        }
    }

# Let's update the profile with boot order and BIOS settings and validate the result
$task = Set-OVResource $profile
$task = Wait-OVTaskComplete -Task $task -timeout (New-TimeSpan -Minutes 20)
$profile = Send-OVRequest $task.associatedResource.resourceUri

# Now update the firmware of the profile.
# List available SPP's on the appliance
Get-OVBaseline

$sppFileName = Read-Host "Which SPP file do you want to select ('SPP*.iso'), or <Enter> to skip firmware"
if ($sppFileName) {
    $fw = Get-OVBaseline -FileName $sppFileName
    # Now select the firmware SPP in the server profile
    if ($serverType.firmwareUpdateSupported) {
        $profile.firmwareSettings.manageFirmware = $true
        $profile.firmwareSettings.firmwareBaselineUri = $fw.uri
        $task = Set-OVResource $profile
        $task = Wait-OVTaskComplete -taskUri $task.uri -timeout (New-TimeSpan -Minutes 30)

    } else {
        Write-Host "Firmware update not supported for" $serverType.model
    }
}
# SIG # Begin signature block
# MIItlAYJKoZIhvcNAQcCoIIthTCCLYECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDmxjOXybQ4loLY
# c9sXFByqNtQmm+h9eWo+sssWW2nrX6CCEXYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# Syatatvx157YK9hlcPmVoa1oDE5/L9Uo2bC5a4CH2Rwxght0MIIbcAIBATBpMFQx
# CzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxKzApBgNVBAMT
# IlNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBDQSBSMzYCEQDzfDeB/ajwfQYd
# ZdJTJuKyMA0GCWCGSAFlAwQCAQUAoHwwEAYKKwYBBAGCNwIBDDECMAAwGQYJKoZI
# hvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcC
# ARUwLwYJKoZIhvcNAQkEMSIEIKLphITr63BMCElCMMplmCYpKT/9eRSkkNjqntIk
# ZrTPMA0GCSqGSIb3DQEBAQUABIIBgBs1s+0ko8RMqfK/MeEjkzrHSlSywHytWVvG
# J86v4CQCgZ2vofnZSdYQyH3K3vUcSrfZ8zu56fHShXiDoCDDIzVcp5Q68APV/xUU
# VN/Qx1ud+Cg1N5iJgRcSqwAeg6QpCkjTaaqWtz56gek/hPgQwqG0Y1/QMqqHuzn4
# VLe23h+jZTsqjK3SM59lpTVgNfJrSsqd4bFf4Fr1uFVcxRMVp5kp3ivQW/y9HxQ9
# E/vet3UrX4t6HVt467Nov2PmeqkBfy+sgEJbKygvvMZm6zqCJf/QPVIrLk8JHLNS
# mFmmciZhWvpEfZKwwQotNJu0fwaMM7Z5s8GDbEi38ScjoIdqlYQ/Bzcp5B00U+A9
# mjozFss/RY6sEtm8jVi2/TKcz5So/D3F99cRHwyECEYxOJXcGoyZRWPcdz5jv+S1
# xrXiP5yGaW47damidUC4lxx0G9R/AjL+BFfVDtCUqaxKAPxRCWyt0g54DGSwxCDZ
# ej5BMnWSue2efp3DYL36uXNPkaV/ZqGCGN4wghjaBgorBgEEAYI3AwMBMYIYyjCC
# GMYGCSqGSIb3DQEHAqCCGLcwghizAgEDMQ8wDQYJYIZIAWUDBAICBQAwggEDBgsq
# hkiG9w0BCRABBKCB8wSB8DCB7QIBAQYKKwYBBAGyMQIBATBBMA0GCWCGSAFlAwQC
# AgUABDDH+64OuaTfIHiwA7xzumtVQMLLP5p5gkD3WvsWYxnqp/pzD0/GqiVd+EQI
# 2J6uwAECFE3rLYH1oDLXySSlORY3GLuPWgoKGA8yMDI0MDkxMTAxNTMyNlqgcqRw
# MG4xCzAJBgNVBAYTAkdCMRMwEQYDVQQIEwpNYW5jaGVzdGVyMRgwFgYDVQQKEw9T
# ZWN0aWdvIExpbWl0ZWQxMDAuBgNVBAMTJ1NlY3RpZ28gUHVibGljIFRpbWUgU3Rh
# bXBpbmcgU2lnbmVyIFIzNaCCEv8wggZdMIIExaADAgECAhA6UmoshM5V5h1l/MwS
# 2OmJMA0GCSqGSIb3DQEBDAUAMFUxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0
# aWdvIExpbWl0ZWQxLDAqBgNVBAMTI1NlY3RpZ28gUHVibGljIFRpbWUgU3RhbXBp
# bmcgQ0EgUjM2MB4XDTI0MDExNTAwMDAwMFoXDTM1MDQxNDIzNTk1OVowbjELMAkG
# A1UEBhMCR0IxEzARBgNVBAgTCk1hbmNoZXN0ZXIxGDAWBgNVBAoTD1NlY3RpZ28g
# TGltaXRlZDEwMC4GA1UEAxMnU2VjdGlnbyBQdWJsaWMgVGltZSBTdGFtcGluZyBT
# aWduZXIgUjM1MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAjdFn9MFI
# m739OEk6TWGBm8PY3EWlYQQ2jQae45iWgPXUGVuYoIa1xjTGIyuw3suUSBzKiyG0
# /c/Yn++d5mG6IyayljuGT9DeXQU9k8GWWj2/BPoamg2fFctnPsdTYhMGxM06z1+F
# t0Bav8ybww21ii/faiy+NhiUM195+cFqOtCpJXxZ/lm9tpjmVmEqpAlRpfGmLhNd
# kqiEuDFTuD1GsV3jvuPuPGKUJTam3P53U4LM0UCxeDI8Qz40Qw9TPar6S02XExlc
# 8X1YsiE6ETcTz+g1ImQ1OqFwEaxsMj/WoJT18GG5KiNnS7n/X4iMwboAg3IjpcvE
# zw4AZCZowHyCzYhnFRM4PuNMVHYcTXGgvuq9I7j4ke281x4e7/90Z5Wbk92RrLcS
# 35hO30TABcGx3Q8+YLRy6o0k1w4jRefCMT7b5mTxtq5XPmKvtgfPuaWPkGZ/tbxI
# nyNDA7YgOgccULjp4+D56g2iuzRCsLQ9ac6AN4yRbqCYsG2rcIQ5INTyI2JzA2w1
# vsAHPRbUTeqVLDuNOY2gYIoKBWQsPYVoyzaoBVU6O5TG+a1YyfWkgVVS9nXKs8hV
# ti3VpOV3aeuaHnjgC6He2CCDL9aW6gteUe0AmC8XCtWwpePx6QW3ROZo8vSUe9AR
# 7mMdu5+FzTmW8K13Bt8GX/YBFJO7LWzwKAUCAwEAAaOCAY4wggGKMB8GA1UdIwQY
# MBaAFF9Y7UwxeqJhQo1SgLqzYZcZojKbMB0GA1UdDgQWBBRo76QySWm2Ujgd6kM5
# LPQUap4MhTAOBgNVHQ8BAf8EBAMCBsAwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8E
# DDAKBggrBgEFBQcDCDBKBgNVHSAEQzBBMDUGDCsGAQQBsjEBAgEDCDAlMCMGCCsG
# AQUFBwIBFhdodHRwczovL3NlY3RpZ28uY29tL0NQUzAIBgZngQwBBAIwSgYDVR0f
# BEMwQTA/oD2gO4Y5aHR0cDovL2NybC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGlj
# VGltZVN0YW1waW5nQ0FSMzYuY3JsMHoGCCsGAQUFBwEBBG4wbDBFBggrBgEFBQcw
# AoY5aHR0cDovL2NydC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljVGltZVN0YW1w
# aW5nQ0FSMzYuY3J0MCMGCCsGAQUFBzABhhdodHRwOi8vb2NzcC5zZWN0aWdvLmNv
# bTANBgkqhkiG9w0BAQwFAAOCAYEAsNwuyfpPNkyKL/bJT9XvGE8fnw7Gv/4SetmO
# kjK9hPPa7/Nsv5/MHuVus+aXwRFqM5Vu51qfrHTwnVExcP2EHKr7IR+m/Ub7Pama
# eWfle5x8D0x/MsysICs00xtSNVxFywCvXx55l6Wg3lXiPCui8N4s51mXS0Ht85fk
# Xo3auZdo1O4lHzJLYX4RZovlVWD5EfwV6Ve1G9UMslnm6pI0hyR0Zr95QWG0MpNP
# P0u05SHjq/YkPlDee3yYOECNMqnZ+j8onoUtZ0oC8CkbOOk/AOoV4kp/6Ql2gEp3
# bNC7DOTlaCmH24DjpVgryn8FMklqEoK4Z3IoUgV8R9qQLg1dr6/BjghGnj2XNA8u
# jta2JyoxpqpvyETZCYIUjIs69YiDjzftt37rQVwIZsfCYv+DU5sh/StFL1x4rgNj
# 2t8GccUfa/V3iFFW9lfIJWWsvtlC5XOOOQswr1UmVdNWQem4LwrlLgcdO/YAnHqY
# 52QwnBLiAuUnuBeshWmfEb5oieIYMIIGFDCCA/ygAwIBAgIQeiOu2lNplg+RyD5c
# 9MfjPzANBgkqhkiG9w0BAQwFADBXMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2Vj
# dGlnbyBMaW1pdGVkMS4wLAYDVQQDEyVTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1w
# aW5nIFJvb3QgUjQ2MB4XDTIxMDMyMjAwMDAwMFoXDTM2MDMyMTIzNTk1OVowVTEL
# MAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEsMCoGA1UEAxMj
# U2VjdGlnbyBQdWJsaWMgVGltZSBTdGFtcGluZyBDQSBSMzYwggGiMA0GCSqGSIb3
# DQEBAQUAA4IBjwAwggGKAoIBgQDNmNhDQatugivs9jN+JjTkiYzT7yISgFQ+7yav
# jA6Bg+OiIjPm/N/t3nC7wYUrUlY3mFyI32t2o6Ft3EtxJXCc5MmZQZ8AxCbh5c6W
# zeJDB9qkQVa46xiYEpc81KnBkAWgsaXnLURoYZzksHIzzCNxtIXnb9njZholGw9d
# jnjkTdAA83abEOHQ4ujOGIaBhPXG2NdV8TNgFWZ9BojlAvflxNMCOwkCnzlH4oCw
# 5+4v1nssWeN1y4+RlaOywwRMUi54fr2vFsU5QPrgb6tSjvEUh1EC4M29YGy/SIYM
# 8ZpHadmVjbi3Pl8hJiTWw9jiCKv31pcAaeijS9fc6R7DgyyLIGflmdQMwrNRxCul
# Vq8ZpysiSYNi79tw5RHWZUEhnRfs/hsp/fwkXsynu1jcsUX+HuG8FLa2BNheUPtO
# cgw+vHJcJ8HnJCrcUWhdFczf8O+pDiyGhVYX+bDDP3GhGS7TmKmGnbZ9N+MpEhWm
# biAVPbgkqykSkzyYVr15OApZYK8CAwEAAaOCAVwwggFYMB8GA1UdIwQYMBaAFPZ3
# at0//QET/xahbIICL9AKPRQlMB0GA1UdDgQWBBRfWO1MMXqiYUKNUoC6s2GXGaIy
# mzAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADATBgNVHSUEDDAK
# BggrBgEFBQcDCDARBgNVHSAECjAIMAYGBFUdIAAwTAYDVR0fBEUwQzBBoD+gPYY7
# aHR0cDovL2NybC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljVGltZVN0YW1waW5n
# Um9vdFI0Ni5jcmwwfAYIKwYBBQUHAQEEcDBuMEcGCCsGAQUFBzAChjtodHRwOi8v
# Y3J0LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNUaW1lU3RhbXBpbmdSb290UjQ2
# LnA3YzAjBggrBgEFBQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5jb20wDQYJKoZI
# hvcNAQEMBQADggIBABLXeyCtDjVYDJ6BHSVY/UwtZ3Svx2ImIfZVVGnGoUaGdlto
# X4hDskBMZx5NY5L6SCcwDMZhHOmbyMhyOVJDwm1yrKYqGDHWzpwVkFJ+996jKKAX
# yIIaUf5JVKjccev3w16mNIUlNTkpJEor7edVJZiRJVCAmWAaHcw9zP0hY3gj+fWp
# 8MbOocI9Zn78xvm9XKGBp6rEs9sEiq/pwzvg2/KjXE2yWUQIkms6+yslCRqNXPjE
# nBnxuUB1fm6bPAV+Tsr/Qrd+mOCJemo06ldon4pJFbQd0TQVIMLv5koklInHvyaf
# 6vATJP4DfPtKzSBPkKlOtyaFTAjD2Nu+di5hErEVVaMqSVbfPzd6kNXOhYm23EWm
# 6N2s2ZHCHVhlUgHaC4ACMRCgXjYfQEDtYEK54dUwPJXV7icz0rgCzs9VI29DwsjV
# ZFpO4ZIVR33LwXyPDbYFkLqYmgHjR3tKVkhh9qKV2WCmBuC27pIOx6TYvyqiYbnt
# inmpOqh/QPAnhDgexKG9GX/n1PggkGi9HCapZp8fRwg8RftwS21Ln61euBG0yONM
# 6noD2XQPrFwpm3GcuqJMf0o8LLrFkSLRQNwxPDDkWXhW+gZswbaiie5fd/W2ygct
# o78XCSPfFWveUOSZ5SqK95tBO8aTHmEa4lpJVD7HrTEn9jb1EGvxOb1cnn0CMIIG
# gjCCBGqgAwIBAgIQNsKwvXwbOuejs902y8l1aDANBgkqhkiG9w0BAQwFADCBiDEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNl
# eSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMT
# JVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMjEwMzIy
# MDAwMDAwWhcNMzgwMTE4MjM1OTU5WjBXMQswCQYDVQQGEwJHQjEYMBYGA1UEChMP
# U2VjdGlnbyBMaW1pdGVkMS4wLAYDVQQDEyVTZWN0aWdvIFB1YmxpYyBUaW1lIFN0
# YW1waW5nIFJvb3QgUjQ2MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA
# iJ3YuUVnnR3d6LkmgZpUVMB8SQWbzFoVD9mUEES0QUCBdxSZqdTkdizICFNeINCS
# JS+lV1ipnW5ihkQyC0cRLWXUJzodqpnMRs46npiJPHrfLBOifjfhpdXJ2aHHsPHg
# gGsCi7uE0awqKggE/LkYw3sqaBia67h/3awoqNvGqiFRJ+OTWYmUCO2GAXsePHi+
# /JUNAax3kpqstbl3vcTdOGhtKShvZIvjwulRH87rbukNyHGWX5tNK/WABKf+Gnoi
# 4cmisS7oSimgHUI0Wn/4elNd40BFdSZ1EwpuddZ+Wr7+Dfo0lcHflm/FDDrOJ3rW
# qauUP8hsokDoI7D/yUVI9DAE/WK3Jl3C4LKwIpn1mNzMyptRwsXKrop06m7NUNHd
# lTDEMovXAIDGAvYynPt5lutv8lZeI5w3MOlCybAZDpK3Dy1MKo+6aEtE9vtiTMzz
# /o2dYfdP0KWZwZIXbYsTIlg1YIetCpi5s14qiXOpRsKqFKqav9R1R5vj3NgevsAs
# vxsAnI8Oa5s2oy25qhsoBIGo/zi6GpxFj+mOdh35Xn91y72J4RGOJEoqzEIbW3q0
# b2iPuWLA911cRxgY5SJYubvjay3nSMbBPPFsyl6mY4/WYucmyS9lo3l7jk27MAe1
# 45GWxK4O3m3gEFEIkv7kRmefDR7Oe2T1HxAnICQvr9sCAwEAAaOCARYwggESMB8G
# A1UdIwQYMBaAFFN5v1qqK0rPVIDh2JvAnfKyA2bLMB0GA1UdDgQWBBT2d2rdP/0B
# E/8WoWyCAi/QCj0UJTAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAT
# BgNVHSUEDDAKBggrBgEFBQcDCDARBgNVHSAECjAIMAYGBFUdIAAwUAYDVR0fBEkw
# RzBFoEOgQYY/aHR0cDovL2NybC51c2VydHJ1c3QuY29tL1VTRVJUcnVzdFJTQUNl
# cnRpZmljYXRpb25BdXRob3JpdHkuY3JsMDUGCCsGAQUFBwEBBCkwJzAlBggrBgEF
# BQcwAYYZaHR0cDovL29jc3AudXNlcnRydXN0LmNvbTANBgkqhkiG9w0BAQwFAAOC
# AgEADr5lQe1oRLjlocXUEYfktzsljOt+2sgXke3Y8UPEooU5y39rAARaAdAxUeiX
# 1ktLJ3+lgxtoLQhn5cFb3GF2SSZRX8ptQ6IvuD3wz/LNHKpQ5nX8hjsDLRhsyeIi
# Jsms9yAWnvdYOdEMq1W61KE9JlBkB20XBee6JaXx4UBErc+YuoSb1SxVf7nkNtUj
# PfcxuFtrQdRMRi/fInV/AobE8Gw/8yBMQKKaHt5eia8ybT8Y/Ffa6HAJyz9gvEOc
# F1VWXG8OMeM7Vy7Bs6mSIkYeYtddU1ux1dQLbEGur18ut97wgGwDiGinCwKPyFO7
# ApcmVJOtlw9FVJxw/mL1TbyBns4zOgkaXFnnfzg4qbSvnrwyj1NiurMp4pmAWjR+
# Pb/SIduPnmFzbSN/G8reZCL4fvGlvPFk4Uab/JVCSmj59+/mB2Gn6G/UYOy8k60m
# KcmaAZsEVkhOFuoj4we8CYyaR9vd9PGZKSinaZIkvVjbH/3nlLb0a7SBIkiRzfPf
# S9T+JesylbHa1LtRV9U/7m0q7Ma2CQ/t392ioOssXW7oKLdOmMBl14suVFBmbzrt
# 5V5cQPnwtd3UOTpS9oCG+ZZheiIvPgkDmA8FzPsnfXW5qHELB43ET7HHFHeRPRYr
# MBKjkb8/IN7Po0d0hQoF4TeMM+zYAJzoKQnVKOLg8pZVPT8xggSRMIIEjQIBATBp
# MFUxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLDAqBgNV
# BAMTI1NlY3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcgQ0EgUjM2AhA6UmoshM5V
# 5h1l/MwS2OmJMA0GCWCGSAFlAwQCAgUAoIIB+TAaBgkqhkiG9w0BCQMxDQYLKoZI
# hvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI0MDkxMTAxNTMyNlowPwYJKoZIhvcN
# AQkEMTIEMB2hrogTbFQ8TPuH9ZdKPh0d0WG1KDUmkexD6mnVwUzcL4yBsdEA+qsw
# J52J70h+9jCCAXoGCyqGSIb3DQEJEAIMMYIBaTCCAWUwggFhMBYEFPhgmBmm+4gs
# 9+hSl/KhGVIaFndfMIGHBBTGrlTkeIbxfD1VEkiMacNKevnC3TBvMFukWTBXMQsw
# CQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMS4wLAYDVQQDEyVT
# ZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIFJvb3QgUjQ2AhB6I67aU2mWD5HI
# Plz0x+M/MIG8BBSFPWMtk4KCYXzQkDXEkd6SwULaxzCBozCBjqSBizCBiDELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBD
# aXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVT
# RVJUcnVzdCBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkCEDbCsL18Gzrno7Pd
# NsvJdWgwDQYJKoZIhvcNAQEBBQAEggIAA9qS4z0QJEex1SaYQcqUto2uXbxlPKGh
# N4g2eWQnpzphZzHKwsE4cshXD+HhjCymEQA+7q65AZJWD3TKKjMb4guPbKxLimvo
# R1B1K9i+xXTtH2vxYpQg1n5zhaVkdiyBY4SKowWV005oJL4uFXQgWAjM15XLu/QO
# eQ1jYBVxdsVtIdn1QXvt3S9DWDtGzcI0rOAsQcLBp4hTnE+QWDmZCmEwRJ7GaDUf
# KhGjFE925fNAyziwjIaHM+PpCVsjU6apRZ3HD4X5Zue6wxlSKwL1mvVkUwm18LEt
# SBjky1Vp9LwKkg2ZW1e7zNMJo4STbv0q4gWzUUR6xY1deYTL4s6nyn4AkXmbhIZB
# mJvNceLs+C3eUQndod07v0hd+jI0k9zRHdE40rVGFzbDbCB76Gpi2kkUMbyXWucG
# uDS4HTPGHRu2i5CdhDsKEi/HFWl+UB/ad/Q3KWUrnSdz/DwknGiy6ATcJkx48Zux
# JF4aYZolgr504kkkGHA7/0toSmrw/ORB9b+yAd3+OCOa13KKIHS0KcsHdhElezf8
# YvUsi+UXGru3PUoB8dKBN8vtZD5Lf9sIuwGWpM5vOGx8FFTg4GofaiiWKMdL4Ftl
# R2CSzv1vakm9pVYDv+g1ZQFSrpWCu7BKDOATcVPEf34sQrRwnFbfeWIRimxb+33Y
# 5AryVF0/XAw=
# SIG # End signature block
