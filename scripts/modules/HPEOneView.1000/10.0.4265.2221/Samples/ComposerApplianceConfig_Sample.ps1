##############################################################################
# ComposerApplianceConfig_Sample.ps1
# - Example scripts for configuring an HPE OneView appliance (networking, NTP,
#   etc.).
#
#   VERSION 3.0
#
# (C) Copyright 2013-2025 Hewlett Packard Enterprise Development LP
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

[CmdletBinding()]
param
(

    [Parameter (Mandatory, HelpMessage = "Provide the Appliances DHCP Address.")]
	[Alias('vm_ipaddr')]
    [ValidateNotNullorEmpty()]
	[IPAddress]$DhcpAddress,

	[Parameter (Mandatory, HelpMessage = "Provide the Appliances NEW Hostname or FQDN.")]
	[String]$Hostname,

	[Parameter (Mandatory, HelpMessage = "Provide a [SecureString] pr [String] object representing the new appliance Administrator password.")]
	[ValidateNotNullorEmpty()]
	[Object]$NewPassword,

	[Parameter (Mandatory, HelpMessage = "Provide the Composer Primary Virtual IP.")]
    [ValidateNotNullorEmpty()]
	[IPAddress]$IPv4Address,

	[Parameter (Mandatory, HelpMessage = "Provide the Appliances NEW IPv4 Subnet.")]
    [ValidateNotNullorEmpty()]
	[String]$IPv4SubnetMask,

	[Parameter (Mandatory, HelpMessage = "Provide the Appliances NEW IPv4 Default Gateway.")]
    [ValidateNotNullorEmpty()]
	[IPAddress]$IPv4Gateway,

	[Parameter (Mandatory, HelpMessage = "Provide the Appliances NEW IPv4 DNS Servers.")]
    [ValidateNotNullorEmpty()]
	[Array]$IPv4DnsServers,

	[Parameter (Mandatory, HelpMessage = "Provide the Appliances NEW DNS Domain Name.")]
    [ValidateNotNullorEmpty()]
	[String]$DnsDomainName,

    [Parameter (Mandatory, HelpMessage = "Provide the Appliances NEW DNS Domain Name.")]
    [ValidateNotNullorEmpty()]
    [IPAddress]$ServiceIPv4Node1,

    [Parameter (Mandatory, HelpMessage = "Provide the Appliances NEW DNS Domain Name.")]
    [ValidateNotNullorEmpty()]
    [IPAddress]$ServiceIPv4Node2,

	[Parameter (Mandatory = $false, HelpMessage = "Provide the Appliances NEW IPv4 NTP Servers.")]
    [ValidateNotNullorEmpty()]
	[Array]$IPv4NtpServers,

    [Parameter (Mandatory = $False, HelpMessage = "Provide the Appliances NEW IPv6 Static Address.")]
    [ValidateNotNullorEmpty()]
    [IPAddress]$IPv6Address,

    [Parameter (Mandatory = $False, HelpMessage = "Provide the Appliances NEW IPv6 Static Address.")]
    [ValidateNotNullorEmpty()]
    [Int]$IPv6CidrMask,

    [Parameter (Mandatory = $False, HelpMessage = "Provide the Service IP for Node 1 NEW IPv6 Static Address.")]
    [ValidateNotNullorEmpty()]
    [IPAddress]$ServiceIPv6Node1,

    [Parameter (Mandatory = $False, HelpMessage = "Provide the Service IP for Node 2 NEW IPv6 Static Address.")]
    [ValidateNotNullorEmpty()]
    [IPAddress]$ServiceIPv6Node2

)

if (-not (Get-Module HPEOneView.700))
{

    Import-Module HPEOneView.700

}

#region

	Write-Host 'Waiting for appliance to respond to network test.' -NoNewline

	While (-not (Test-Connection -ComputerName $DhcpAddress.IPAddressToString -Quiet))
	{

		Write-Host '.' -NoNewline

	}

	Write-Host ""

	#Core Appliance Setup

    # Accept the EULA
    if (-not (Get-OVEulaStatus -Appliance $DhcpAddress.IPAddressToString).Accepted )
	{

        Write-Host "Accepting EULA..."

		Try
		{

			$ret = Set-OVEulaStatus -SupportAccess "yes" -Appliance $DhcpAddress.IPAddressToString

		}

		Catch
		{

			$PSCMdlet.ThrowTerminatingError($_)
		}

    }

    # For initial setup, connect first using "default" Administrator credentials:
    Try
	{

		Connect-OVMgmt -appliance $DhcpAddress.IPAddressToString -user "Administrator" -password "admin"

	}

    catch [HPEOneView.Appliance.PasswordChangeRequired]
	{

        Write-Host "Set initial password"

		Try
		{

			Set-OVInitialPassword -OldPassword "admin" -NewPassword $NewPassword -Appliance $DhcpAddress.IPAddressToString

		}

		Catch
		{

			$PSCMdlet.ThrowTerminatingError($_)

		}

    }

	catch [HPEOneView.Appliance.AuthSessionException]
	{

		Write-Host "Default password was already changed."

	}

	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}

    Write-Host "Reconnect with new password"

	Try
	{

		$ApplianceConnection = Connect-OVMgmt -appliance $DhcpAddress.IPAddressToString -user Administrator -password $NewPassword

	}

	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}

    Write-Host "Set appliance networking configuration"

    $params = @{

        Hostname         = $Hostname;
        IPv4Addr         = $IPv4Address.IPAddressToString;
        IPv4Subnet       = $IPv4SubnetMask;
        IPv4Gateway      = $IPv4Gateway.IPAddressToString;
        DomainName       = $DnsDomainName;
        IPv4NameServers  = $IPv4DnsServers;
        ServiceIPv4Node1 = $ServiceIPv4Node1;
        ServiceIPv4Node2 = $ServiceIPv4Node2

    }

    if ($IPv6Address)
    {

		$params.Add('IPv6Type','STATIC')
        $params.Add('IPv6Addr', $IPv6Address)
		$params.Add('IPv6Subnet', $IPv6CidrMask)
        $params.Add('ServiceIPv6Node1', $ServiceIPv6Node1)
        $params.Add('ServiceIPv6Node2', $ServiceIPv6Node2)

    }

	Try
	{

		$task = Set-OVApplianceNetworkConfig @params

	}

	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}

    if (-not($Global:ConnectedSessions | ? Name -EQ $Hostname))
	{

		Try
		{

			$ApplianceConnection = Connect-OVMgmt -appliance $Hostname -user Administrator -password $NewPassword

		}

		Catch
		{

			$PSCMdlet.ThrowTerminatingError($_)

		}

	}

	try
	{

		Write-Host 'Setting Appliance NTP Servers'

        $Results = Set-OVApplianceDateTime -NtpServers $IPv4NtpServers

	}

	catch
	{

		$PSCmdlet.ThrowTerminatingError($_)

	}

    #Configuring appliance LDAP/AD Security
    $dc1 = New-OVLdapServer -Name dc1.domain.local
    $dc2 = New-OVLdapServer -Name dc2.domain.local

    $AuthParams = @{

        UserName = "ftoomey@domain.local"
        Password = convertto-securestring -asplaintext "HPinv3nt" -force

    }

	Try
	{

		$LdapAuthDirectory = New-OVLdapDirectory -Name 'domain.local' -AD -BaseDN 'dc=domain,dc=local' -servers $dc1,$dc2 @AuthParams
		$LdapGroups = $LdapAuthDirectory | Show-OVLdapGroups @AuthParams
		$InfrastructureAdminGroup = $LdapGroups | ? Name -match 'CI Manager Full'
		$ServerAdminGroup  = $LdapGroups | ? Name -match 'CI Manager Server'
		$StorageAdminGroup = $LdapGroups | ? Name -match 'CI Manager Storage'
		$NetworkAdminGroup = $LdapGroups | ? Name -match 'CI Manager Network'
		New-OVLdapGroup -d $LdapAuthDirectory -GroupName $InfrastructureAdminGroup -Roles "Infrastructure administrator" @AuthParams
		New-OVLdapGroup -d $LdapAuthDirectory -GroupName $NetworkAdminGroup -Roles "Network administrator"  @AuthParams
		New-OVLdapGroup -d $LdapAuthDirectory -GroupName $ServerAdminGroup  -Roles "Server administrator"  @AuthParams
		New-OVLdapGroup -d $LdapAuthDirectory -GroupName $StorageAdminGroup -Roles "Storage administrator"  @AuthParams

	}

	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}

	Try
	{

		#Upload custom SPP Baseline
	    gci \\Server\software\SPP\bp-2016-07-11-00.iso | Add-OVBaseline

	}

	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}


	# Create the new users
    New-OVUser Nat   -fullName "Nat Network Admin"  -password hpinvent -roles "Network administrator"
    New-OVUser Sarah -fullName "Sarah Server Admin" -password hpinvent -roles "Server administrator"
    New-OVUser Sandy -fullName "Sandy SAN Admin"    -password hpinvent -roles "Storage administrator"
    New-OVUser Rheid -fullName "Rheid Read-Only"	  -password hpinvent -roles "Read only"
    New-OVUser Bob   -fullName "Bob Backup"	      -password hpinvent -roles "Backup administrator"
    New-OVUser admin -fullName "admin"              -password hpinvent -roles "Infrastructure administrator"

#endregion

#region

	#Resource Configuration

    $params = @{

        hostname  = "172.18.15.1";
        type      = "BNA";
        username  = "administrator";
    	password  = "pasword";
        UseSsl    = $True

    }

    write-host "Importing BNA SAN Manager"

	Try
	{

		Add-OVSanManager @params | Wait-OVTaskComplete

	}

	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}

    Write-Host "Creating network resources"

    # Management networks
	Try
	{

		New-OVNetwork -Name "MLAG VLAN 10" -type "Ethernet" -vlanId 10 -smartlink $true -purpose Management

        # Internal Networks
		New-OVNetwork -Name "Internal Live Migration" -type "Ethernet" -vlanId 100 -smartlink $true -purpose VMMigration
        New-OVNetwork -Name "Internal Heartbeat" -type "Ethernet" -vlanId 101 -smartlink $true -purpose Management
        New-OVNetwork -Name "iSCSI Network" -type "Ethernet" -vlanId 3000 -smartlink $true -purpose ISCSI

		# VM Networks
        20,30,40,50 | % { New-OVNetwork -Name "MLAG Prod VLAN $_" -type "Ethernet" -vlanId $_ -smartlink $true -purpose General }
		101,102,103,104,105 | % { New-OVNetwork -Name "MLAG Dev VLAN $_" -type "Ethernet" -vlanId $_ -smartlink $true -purpose General }

		$AllMlagDevNetworks = Get-OVNetwork -Name "MLAG Dev VLAN"
		$AllMlagNetworks    = Get-OVNetwork -Name "MLAG VLAN*"
        $InternalNetworks   = Get-OVNetwork -Name Internal*

		# Create the network sets
		New-OVNetworkSet -Name "Prod NetSet" -networks $AllMlagNetworks -untaggedNetwork $AllMlagNetworks[0] -typicalBandwidth 2500 -maximumBandwidth 10000
		New-OVNetworkSet -Name "Dev Networks A" -networks $AllMlagDevNetworks -untaggedNetwork $AllMlagDevNetworks[0]  -typicalBandwidth 2500 -maximumBandwidth 10000

		# Create the FC networks:
		New-OVNetwork -Name "Fabric A" -type "FibreChannel" -typicalBandwidth 4000 -autoLoginRedistribution $true #-managedSan "SAN1_0"
		New-OVNetwork -Name "Fabric B" -type "FibreChannel" -typicalBandwidth 4000 -autoLoginRedistribution $true #-managedSan "SAN1_1"
		New-OVNetwork -Name "DirectAttach A" -type "FibreChannel" -typicalBandwidth 4000 -autoLoginRedistribution $true -fabricType DirectAttach
		New-OVNetwork -Name "DirectAttach B" -type "FibreChannel" -typicalBandwidth 4000 -autoLoginRedistribution $true -fabricType DirectAttach

	}

    Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}

    $params = @{

        username  = "3paradm";
        password  = "3pardata";
        hostname  = "172.18.11.11";
        domain    = "NO DOMAIN"

    }

    Write-Host "Importing storage array: $($params.hostname)"
	Try
	{

		$Results = Add-OVStorageSystem @params | Wait-OVTaskComplete

        $Results = Get-OVStorageSystem | Add-OVStoragePool -Pool 'FST_CPG1','FST_CPG2' | Wait-OVTaskComplete

	}

	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}

	$SynergyLigParams = @{

		Name               = 'Default Synergy LIG';
		InterconnectBaySet = 3;
		FabricModuleType   = 'SEVC40F8';
		FrameCount         = 3;
		InternalNetworks   = $InternalNetworks;
		FabricRedundancy   = 'HighlyAvailable'
		Bays               = @{
								Frame1 = @{Bay3 = 'SEVC40f8'; Bay6 = 'SE20ILM' };
								Frame2 = @{Bay3 = 'SE20ILM'; Bay6 = 'SEVC40f8'};
								Frame3 = @{Bay3 = 'SE20ILM'; Bay6 = 'SE20ILM'}
								}

	}

	$CreatedLogicalInterconnectObject = New-OVLogicalInterconnectGroup @SynergyLigParams | Get-OVLogicalInterconnectGroup

	$UplinkSetParams = @{

		InputObject = $CreatedLogicalInterconnectObject;
		Name        = 'MLag UplinkSet';
		Type        = 'Ethernet';
		Networks    = $AllMlagNetworks;
		UplinkPorts = "Enclosure1:Bay3:Q1","Enclosure1:Bay3:Q2","Enclosure2:Bay6:Q1","Enclosure2:Bay6:Q2"

	}

	$CreateUplinkSetResults = New-OVUplinkSet @UplinkSetParams

	$LIG = Get-OVLogicalInterconnectGroup -Name 'Default Synergy LIG'

	$EgParams = @{

		Name                            = 'Synergy Default EG';
		EnclosureCount                  = 3;
		LogicalInterconnectGroupMapping = $LIG;
		IPv4AddressType                 = 'DHCP'

	}

    $CreateEGResults = New-OVEnclosureGroup @EgParams

    Disconnect-OVMgmt

	Remove-Module HPEOneView.630

#endregion
# SIG # Begin signature block
# MIItEQYJKoZIhvcNAQcCoIItAjCCLP4CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAWRd8wXU/Kc/01
# KEDLA/T8eFEwBm9LxVK+/rivj/40TKCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# +9/DUp/mBlXpnYzyOmJRvOwkDynUWICE5EV7WtgwggYaMIIEAqADAgECAhBiHW0M
# UgGeO5B5FSCJIRwKMA0GCSqGSIb3DQEBDAUAMFYxCzAJBgNVBAYTAkdCMRgwFgYD
# VQQKEw9TZWN0aWdvIExpbWl0ZWQxLTArBgNVBAMTJFNlY3RpZ28gUHVibGljIENv
# ZGUgU2lnbmluZyBSb290IFI0NjAeFw0yMTAzMjIwMDAwMDBaFw0zNjAzMjEyMzU5
# NTlaMFQxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxKzAp
# BgNVBAMTIlNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBDQSBSMzYwggGiMA0G
# CSqGSIb3DQEBAQUAA4IBjwAwggGKAoIBgQCbK51T+jU/jmAGQ2rAz/V/9shTUxjI
# ztNsfvxYB5UXeWUzCxEeAEZGbEN4QMgCsJLZUKhWThj/yPqy0iSZhXkZ6Pg2A2NV
# DgFigOMYzB2OKhdqfWGVoYW3haT29PSTahYkwmMv0b/83nbeECbiMXhSOtbam+/3
# 6F09fy1tsB8je/RV0mIk8XL/tfCK6cPuYHE215wzrK0h1SWHTxPbPuYkRdkP05Zw
# mRmTnAO5/arnY83jeNzhP06ShdnRqtZlV59+8yv+KIhE5ILMqgOZYAENHNX9SJDm
# +qxp4VqpB3MV/h53yl41aHU5pledi9lCBbH9JeIkNFICiVHNkRmq4TpxtwfvjsUe
# dyz8rNyfQJy/aOs5b4s+ac7IH60B+Ja7TVM+EKv1WuTGwcLmoU3FpOFMbmPj8pz4
# 4MPZ1f9+YEQIQty/NQd/2yGgW+ufflcZ/ZE9o1M7a5Jnqf2i2/uMSWymR8r2oQBM
# dlyh2n5HirY4jKnFH/9gRvd+QOfdRrJZb1sCAwEAAaOCAWQwggFgMB8GA1UdIwQY
# MBaAFDLrkpr/NZZILyhAQnAgNpFcF4XmMB0GA1UdDgQWBBQPKssghyi47G9IritU
# pimqF6TNDDAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADATBgNV
# HSUEDDAKBggrBgEFBQcDAzAbBgNVHSAEFDASMAYGBFUdIAAwCAYGZ4EMAQQBMEsG
# A1UdHwREMEIwQKA+oDyGOmh0dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1B1
# YmxpY0NvZGVTaWduaW5nUm9vdFI0Ni5jcmwwewYIKwYBBQUHAQEEbzBtMEYGCCsG
# AQUFBzAChjpodHRwOi8vY3J0LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNDb2Rl
# U2lnbmluZ1Jvb3RSNDYucDdjMCMGCCsGAQUFBzABhhdodHRwOi8vb2NzcC5zZWN0
# aWdvLmNvbTANBgkqhkiG9w0BAQwFAAOCAgEABv+C4XdjNm57oRUgmxP/BP6YdURh
# w1aVcdGRP4Wh60BAscjW4HL9hcpkOTz5jUug2oeunbYAowbFC2AKK+cMcXIBD0Zd
# OaWTsyNyBBsMLHqafvIhrCymlaS98+QpoBCyKppP0OcxYEdU0hpsaqBBIZOtBajj
# cw5+w/KeFvPYfLF/ldYpmlG+vd0xqlqd099iChnyIMvY5HexjO2AmtsbpVn0OhNc
# WbWDRF/3sBp6fWXhz7DcML4iTAWS+MVXeNLj1lJziVKEoroGs9Mlizg0bUMbOalO
# hOfCipnx8CaLZeVme5yELg09Jlo8BMe80jO37PU8ejfkP9/uPak7VLwELKxAMcJs
# zkyeiaerlphwoKx1uHRzNyE6bxuSKcutisqmKL5OTunAvtONEoteSiabkPVSZ2z7
# 6mKnzAfZxCl/3dq3dUNw4rg3sTCggkHSRqTqlLMS7gjrhTqBmzu1L90Y1KWN/Y5J
# KdGvspbOrTfOXyXvmPL6E52z1NZJ6ctuMFBQZH3pwWvqURR8AgQdULUvrxjUYbHH
# j95Ejza63zdrEcxWLDX6xWls/GDnVNueKjWUH3fTv1Y8Wdho698YADR7TNx8X8z2
# Bev6SivBBOHY+uqiirZtg0y9ShQoPzmCcn63Syatatvx157YK9hlcPmVoa1oDE5/
# L9Uo2bC5a4CH2RwwggZhMIIEyaADAgECAhEAyDHh+zCQwUNyJV9S6gqqvTANBgkq
# hkiG9w0BAQwFADBUMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1p
# dGVkMSswKQYDVQQDEyJTZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgQ0EgUjM2
# MB4XDTI1MDUyMDAwMDAwMFoXDTI4MDUxOTIzNTk1OVowdzELMAkGA1UEBhMCVVMx
# DjAMBgNVBAgMBVRleGFzMSswKQYDVQQKDCJIZXdsZXR0IFBhY2thcmQgRW50ZXJw
# cmlzZSBDb21wYW55MSswKQYDVQQDDCJIZXdsZXR0IFBhY2thcmQgRW50ZXJwcmlz
# ZSBDb21wYW55MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA37AD03qw
# cmuCQyxRB2VBM7SfUf0SmpQb8iaPvGmxw5uoDBY3gdC/3Xq/rfM3ndCn03hNdGyu
# cpC7tD4zmel6yYqxyXDVr45Jd2cz9jFXoYTOMcuDV6I6CvU/EnbFxWhv0VCp+2Ip
# z4+uJGI6aVlMpFpLbgPjhp9ogd/89HEyi1FkSFoarnvxxaXm93S81k7FD/4Edtvu
# muGI4V8p39GfbCiMuHku8BzSQ2g86gWFnOaVhY6h4XWvEmE8LPYkU/STrej28Flg
# kSt9f/Jg6+dvRKm92uN2Z760Eql9+DTWkGmGe4YrIyD25XDa07sS9tIpVWzLrGOy
# ecaVpJwVVBqCadXDgkgTYKw/UlS+cEqsviT6wREGl4aX/GbeNO6Y4oDTTYkabW3p
# eg1ku0v90oDqzoTaWEE5ly2UajvXIgzpFLLXqpR6GYkv/y3ZJV0chBqRtAObebH7
# XOBa5a2kqMBw0gkIZBJHd8+PCPH/U7eJkeKXtGGj2uTudcGjZgOjVcFYdCRnufJd
# isrV7bj0Hzghcv3QyRXL3rRjcNb4ccKNnSgF/8cmiTVpvFHTfUKsYdkbM6wsbjXR
# dJNADjGOYRms7tKsii3/oXO+2S1Um7yomBZQ2+wVRCY6MrRX1onDKid5t5AyWFtR
# u0aQcdBmHG6JeDiQ3Hrb2g9kZhuFkgABVBkCAwEAAaOCAYkwggGFMB8GA1UdIwQY
# MBaAFA8qyyCHKLjsb0iuK1SmKaoXpM0MMB0GA1UdDgQWBBQH4rUE0gsy8LW2G3vm
# oYtOnZ8zEjAOBgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAK
# BggrBgEFBQcDAzBKBgNVHSAEQzBBMDUGDCsGAQQBsjEBAgEDAjAlMCMGCCsGAQUF
# BwIBFhdodHRwczovL3NlY3RpZ28uY29tL0NQUzAIBgZngQwBBAEwSQYDVR0fBEIw
# QDA+oDygOoY4aHR0cDovL2NybC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljQ29k
# ZVNpZ25pbmdDQVIzNi5jcmwweQYIKwYBBQUHAQEEbTBrMEQGCCsGAQUFBzAChjho
# dHRwOi8vY3J0LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNDb2RlU2lnbmluZ0NB
# UjM2LmNydDAjBggrBgEFBQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5jb20wDQYJ
# KoZIhvcNAQEMBQADggGBAIax+Yaj5EciDlztft4iAfD2CtIWEF0cxR+UbbvJEs86
# 5wyoO3ZQoujr0FJ+P5fjDKLbamHrEWmyoD2YC4lzecmnFOnY0y4uJ9zBY8B6X6TU
# 9e6+TfZtlXd44YffXYAfoLX+uYjVJcZOaMuXF61+CFpjLJjepsD8m1gdj5QUz2sH
# 6GOfU6mEm8SHvKpgPMV/yhEKqgjlenY6Ao49RkxnDuvRlMP8SFPB+8bxiLegEdGa
# ei8nSr/j5YeDZFevUJ696T4W45QGrwAhBBpbKDz6CzlImC1b2C8Bp02XBAsOQs/u
# CIaQv5XxUmVxmb85tDJkd7QfqHo2z1T2NYMkvXUcSClYRuVxxC/frpqcrxS9O9xE
# v65BoUztAJSXsTdfpUjWeNOnhq8lrwa2XAD3fbagNF6ElsBiNDSbwHCG/iY4kAya
# VpbAYtaa6TfzdI/I0EaCX5xYRW56ccI2AnbaEVKz9gVjzi8hBLALlRhrs1uMFtPj
# nZ+oA+rbZZyGZkz3xbUYKTGCGnEwghptAgEBMGkwVDELMAkGA1UEBhMCR0IxGDAW
# BgNVBAoTD1NlY3RpZ28gTGltaXRlZDErMCkGA1UEAxMiU2VjdGlnbyBQdWJsaWMg
# Q29kZSBTaWduaW5nIENBIFIzNgIRAMgx4fswkMFDciVfUuoKqr0wDQYJYIZIAWUD
# BAIBBQCgfDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGC
# NwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQx
# IgQgqlHZIQ9lmA/IJ31jcLk6sTHqFxo4m5ErhfO4exfdYJ4wDQYJKoZIhvcNAQEB
# BQAEggIASo8raFk2pQkAGB2OqiezQYwrqZgQRUJNsH6wnxUUdlFGLF/6+YR7G0yz
# hXDc+pfn8imcsQFQWjkAf3zkRjtUm2lDUnwI9x9fi8HhOs0goEShyi8EcXiMSUTY
# CpmHDvYqj/VHhk92X6SUt9I/QmrV9f0CpPeX0gXN7iVPNdIQMCmjkWLgTHnuL5EJ
# Oo8DDdRsC2pA1TGMUOnKwYyL2jYoF8DgV5Ervsy99WdtdMU4Uq45/12suOD/8x/D
# tyg51IEPvgekIua0W7dfwNtJbGj4PvxkQ/ZyiQbZNQj1oQ8Ch4wDV2Z32BJjnY2r
# e/4s16gtOs1fgEQUA1CNM56qx/D0r+rllB2lAkpOWIwueEc37dKVBdZJnvUGva1A
# X6aZzqCa/pFPRi0/9rDw4F1/qEHaV5eVHRAIolh1BXg6jmaeB3dUD9xRjrpmPex3
# BlRUKxlNnIkSG1VHqJxvfNKBpstZlzEJ386N54AghPR2zJmHgCrHYIo2EBzvB9Ic
# UsEJMSwIXaJKz9JMdsWnAdZQsKAbDYrpw/pskWOoq9zzZ7XrBC+BVbIvw+6kCidr
# qvtDTOH3KzFVYrqjfdqem1uga6MVwQjJ0GI1TeJipex5Wb6/us817NhMy+zPg9br
# 7vvHLm9/Tcy1uOxir6btYCUasxz9m/sfNucgEGHUDfYOd0gkqyKhghdbMIIXVwYK
# KwYBBAGCNwMDATGCF0cwghdDBgkqhkiG9w0BBwKgghc0MIIXMAIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIGIBgsqhkiG9w0BCRABBKB5BHcwdQIBAQYJYIZIAYb9bAcBMEEw
# DQYJYIZIAWUDBAICBQAEMHBHWw+jTXlfPSUU+eroK6IW7f/2tz46eEq6WjBHMjqE
# PZpj5NkBsewQp+0WrfglCQIRALNOM78txNMhFhvzgX9b4OgYDzIwMjUwNjA2MTgz
# ODA4WqCCEwMwgga8MIIEpKADAgECAhALrma8Wrp/lYfG+ekE4zMEMA0GCSqGSIb3
# DQEBCwUAMGMxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7
# MDkGA1UEAxMyRGlnaUNlcnQgVHJ1c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1l
# U3RhbXBpbmcgQ0EwHhcNMjQwOTI2MDAwMDAwWhcNMzUxMTI1MjM1OTU5WjBCMQsw
# CQYDVQQGEwJVUzERMA8GA1UEChMIRGlnaUNlcnQxIDAeBgNVBAMTF0RpZ2lDZXJ0
# IFRpbWVzdGFtcCAyMDI0MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA
# vmpzn/aVIauWMLpbbeZZo7Xo/ZEfGMSIO2qZ46XB/QowIEMSvgjEdEZ3v4vrrTHl
# eW1JWGErrjOL0J4L0HqVR1czSzvUQ5xF7z4IQmn7dHY7yijvoQ7ujm0u6yXF2v1C
# rzZopykD07/9fpAT4BxpT9vJoJqAsP8YuhRvflJ9YeHjes4fduksTHulntq9WelR
# WY++TFPxzZrbILRYynyEy7rS1lHQKFpXvo2GePfsMRhNf1F41nyEg5h7iOXv+vjX
# 0K8RhUisfqw3TTLHj1uhS66YX2LZPxS4oaf33rp9HlfqSBePejlYeEdU740GKQM7
# SaVSH3TbBL8R6HwX9QVpGnXPlKdE4fBIn5BBFnV+KwPxRNUNK6lYk2y1WSKour4h
# JN0SMkoaNV8hyyADiX1xuTxKaXN12HgR+8WulU2d6zhzXomJ2PleI9V2yfmfXSPG
# YanGgxzqI+ShoOGLomMd3mJt92nm7Mheng/TBeSA2z4I78JpwGpTRHiT7yHqBiV2
# ngUIyCtd0pZ8zg3S7bk4QC4RrcnKJ3FbjyPAGogmoiZ33c1HG93Vp6lJ415ERcC7
# bFQMRbxqrMVANiav1k425zYyFMyLNyE1QulQSgDpW9rtvVcIH7WvG9sqYup9j8z9
# J1XqbBZPJ5XLln8mS8wWmdDLnBHXgYly/p1DhoQo5fkCAwEAAaOCAYswggGHMA4G
# A1UdDwEB/wQEAwIHgDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUF
# BwMIMCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwHATAfBgNVHSMEGDAW
# gBS6FtltTYUvcyl2mi91jGogj57IbzAdBgNVHQ4EFgQUn1csA3cOKBWQZqVjXu5P
# kh92oFswWgYDVR0fBFMwUTBPoE2gS4ZJaHR0cDovL2NybDMuZGlnaWNlcnQuY29t
# L0RpZ2lDZXJ0VHJ1c3RlZEc0UlNBNDA5NlNIQTI1NlRpbWVTdGFtcGluZ0NBLmNy
# bDCBkAYIKwYBBQUHAQEEgYMwgYAwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRp
# Z2ljZXJ0LmNvbTBYBggrBgEFBQcwAoZMaHR0cDovL2NhY2VydHMuZGlnaWNlcnQu
# Y29tL0RpZ2lDZXJ0VHJ1c3RlZEc0UlNBNDA5NlNIQTI1NlRpbWVTdGFtcGluZ0NB
# LmNydDANBgkqhkiG9w0BAQsFAAOCAgEAPa0eH3aZW+M4hBJH2UOR9hHbm04IHdEo
# T8/T3HuBSyZeq3jSi5GXeWP7xCKhVireKCnCs+8GZl2uVYFvQe+pPTScVJeCZSsM
# o1JCoZN2mMew/L4tpqVNbSpWO9QGFwfMEy60HofN6V51sMLMXNTLfhVqs+e8haup
# WiArSozyAmGH/6oMQAh078qRh6wvJNU6gnh5OruCP1QUAvVSu4kqVOcJVozZR5RR
# b/zPd++PGE3qF1P3xWvYViUJLsxtvge/mzA75oBfFZSbdakHJe2BVDGIGVNVjOp8
# sNt70+kEoMF+T6tptMUNlehSR7vM+C13v9+9ZOUKzfRUAYSyyEmYtsnpltD/GWX8
# eM70ls1V6QG/ZOB6b6Yum1HvIiulqJ1Elesj5TMHq8CWT/xrW7twipXTJ5/i5pkU
# 5E16RSBAdOp12aw8IQhhA/vEbFkEiF2abhuFixUDobZaA0VhqAsMHOmaT3XThZDN
# i5U2zHKhUs5uHHdG6BoQau75KiNbh0c+hatSF+02kULkftARjsyEpHKsF7u5zKRb
# t5oK5YGwFvgc4pEVUNytmB3BpIiowOIIuDgP5M9WArHYSAR16gc0dP2XdkMEP5eB
# sX7bf/MGN4K3HP50v/01ZHo/Z5lGLvNwQ7XHBx1yomzLP8lx4Q1zZKDyHcp4VQJL
# u2kWTsKsOqQwggauMIIElqADAgECAhAHNje3JFR82Ees/ShmKl5bMA0GCSqGSIb3
# DQEBCwUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAX
# BgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0
# ZWQgUm9vdCBHNDAeFw0yMjAzMjMwMDAwMDBaFw0zNzAzMjIyMzU5NTlaMGMxCzAJ
# BgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMyRGln
# aUNlcnQgVHJ1c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcgQ0Ew
# ggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDGhjUGSbPBPXJJUVXHJQPE
# 8pE3qZdRodbSg9GeTKJtoLDMg/la9hGhRBVCX6SI82j6ffOciQt/nR+eDzMfUBML
# JnOWbfhXqAJ9/UO0hNoR8XOxs+4rgISKIhjf69o9xBd/qxkrPkLcZ47qUT3w1lbU
# 5ygt69OxtXXnHwZljZQp09nsad/ZkIdGAHvbREGJ3HxqV3rwN3mfXazL6IRktFLy
# dkf3YYMZ3V+0VAshaG43IbtArF+y3kp9zvU5EmfvDqVjbOSmxR3NNg1c1eYbqMFk
# dECnwHLFuk4fsbVYTXn+149zk6wsOeKlSNbwsDETqVcplicu9Yemj052FVUmcJgm
# f6AaRyBD40NjgHt1biclkJg6OBGz9vae5jtb7IHeIhTZgirHkr+g3uM+onP65x9a
# bJTyUpURK1h0QCirc0PO30qhHGs4xSnzyqqWc0Jon7ZGs506o9UD4L/wojzKQtwY
# SH8UNM/STKvvmz3+DrhkKvp1KCRB7UK/BZxmSVJQ9FHzNklNiyDSLFc1eSuo80Vg
# vCONWPfcYd6T/jnA+bIwpUzX6ZhKWD7TA4j+s4/TXkt2ElGTyYwMO1uKIqjBJgj5
# FBASA31fI7tk42PgpuE+9sJ0sj8eCXbsq11GdeJgo1gJASgADoRU7s7pXcheMBK9
# Rp6103a50g5rmQzSM7TNsQIDAQABo4IBXTCCAVkwEgYDVR0TAQH/BAgwBgEB/wIB
# ADAdBgNVHQ4EFgQUuhbZbU2FL3MpdpovdYxqII+eyG8wHwYDVR0jBBgwFoAU7Nfj
# gtJxXWRM3y5nP+e6mK4cD08wDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsG
# AQUFBwMIMHcGCCsGAQUFBwEBBGswaTAkBggrBgEFBQcwAYYYaHR0cDovL29jc3Au
# ZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0cy5kaWdpY2Vy
# dC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNydDBDBgNVHR8EPDA6MDigNqA0
# hjJodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0
# LmNybDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcN
# AQELBQADggIBAH1ZjsCTtm+YqUQiAX5m1tghQuGwGC4QTRPPMFPOvxj7x1Bd4ksp
# +3CKDaopafxpwc8dB+k+YMjYC+VcW9dth/qEICU0MWfNthKWb8RQTGIdDAiCqBa9
# qVbPFXONASIlzpVpP0d3+3J0FNf/q0+KLHqrhc1DX+1gtqpPkWaeLJ7giqzl/Yy8
# ZCaHbJK9nXzQcAp876i8dU+6WvepELJd6f8oVInw1YpxdmXazPByoyP6wCeCRK6Z
# JxurJB4mwbfeKuv2nrF5mYGjVoarCkXJ38SNoOeY+/umnXKvxMfBwWpx2cYTgAnE
# tp/Nh4cku0+jSbl3ZpHxcpzpSwJSpzd+k1OsOx0ISQ+UzTl63f8lY5knLD0/a6fx
# ZsNBzU+2QJshIUDQtxMkzdwdeDrknq3lNHGS1yZr5Dhzq6YBT70/O3itTK37xJV7
# 7QpfMzmHQXh6OOmc4d0j/R0o08f56PGYX/sr2H7yRp11LB4nLCbbbxV7HhmLNriT
# 1ObyF5lZynDwN7+YAN8gFk8n+2BnFqFmut1VwDophrCYoCvtlUG3OtUVmDG0YgkP
# Cr2B2RP+v6TR81fZvAT6gt4y3wSJ8ADNXcL50CN/AAvkdgIm2fBldkKmKYcJRyvm
# fxqkhQ/8mJb2VVQrH4D6wPIOK+XW+6kvRBVK5xMOHds3OBqhK/bt1nz8MIIFjTCC
# BHWgAwIBAgIQDpsYjvnQLefv21DiCEAYWjANBgkqhkiG9w0BAQwFADBlMQswCQYD
# VQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGln
# aWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgQ0Ew
# HhcNMjIwODAxMDAwMDAwWhcNMzExMTA5MjM1OTU5WjBiMQswCQYDVQQGEwJVUzEV
# MBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29t
# MSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwggIiMA0GCSqGSIb3
# DQEBAQUAA4ICDwAwggIKAoICAQC/5pBzaN675F1KPDAiMGkz7MKnJS7JIT3yithZ
# wuEppz1Yq3aaza57G4QNxDAf8xukOBbrVsaXbR2rsnnyyhHS5F/WBTxSD1Ifxp4V
# pX6+n6lXFllVcq9ok3DCsrp1mWpzMpTREEQQLt+C8weE5nQ7bXHiLQwb7iDVySAd
# YyktzuxeTsiT+CFhmzTrBcZe7FsavOvJz82sNEBfsXpm7nfISKhmV1efVFiODCu3
# T6cw2Vbuyntd463JT17lNecxy9qTXtyOj4DatpGYQJB5w3jHtrHEtWoYOAMQjdjU
# N6QuBX2I9YI+EJFwq1WCQTLX2wRzKm6RAXwhTNS8rhsDdV14Ztk6MUSaM0C/CNda
# SaTC5qmgZ92kJ7yhTzm1EVgX9yRcRo9k98FpiHaYdj1ZXUJ2h4mXaXpI8OCiEhtm
# mnTK3kse5w5jrubU75KSOp493ADkRSWJtppEGSt+wJS00mFt6zPZxd9LBADMfRyV
# w4/3IbKyEbe7f/LVjHAsQWCqsWMYRJUadmJ+9oCw++hkpjPRiQfhvbfmQ6QYuKZ3
# AeEPlAwhHbJUKSWJbOUOUlFHdL4mrLZBdd56rF+NP8m800ERElvlEFDrMcXKchYi
# Cd98THU/Y+whX8QgUWtvsauGi0/C1kVfnSD8oR7FwI+isX4KJpn15GkvmB0t9dmp
# sh3lGwIDAQABo4IBOjCCATYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU7Nfj
# gtJxXWRM3y5nP+e6mK4cD08wHwYDVR0jBBgwFoAUReuir/SSy4IxLVGLp6chnfNt
# yA8wDgYDVR0PAQH/BAQDAgGGMHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYY
# aHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2Fj
# ZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MEUG
# A1UdHwQ+MDwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2Vy
# dEFzc3VyZWRJRFJvb3RDQS5jcmwwEQYDVR0gBAowCDAGBgRVHSAAMA0GCSqGSIb3
# DQEBDAUAA4IBAQBwoL9DXFXnOF+go3QbPbYW1/e/Vwe9mqyhhyzshV6pGrsi+Ica
# aVQi7aSId229GhT0E0p6Ly23OO/0/4C5+KH38nLeJLxSA8hO0Cre+i1Wz/n096ww
# epqLsl7Uz9FDRJtDIeuWcqFItJnLnU+nBgMTdydE1Od/6Fmo8L8vC6bp8jQ87PcD
# x4eo0kxAGTVGamlUsLihVo7spNU96LHc/RzY9HdaXFSMb++hUD38dglohJ9vytsg
# jTVgHAIDyyCwrFigDkBjxZgiwbJZ9VVrzyerbHbObyMt9H5xaiNrIv8SuFQtJ37Y
# OtnwtoeW/VvRXKwYw02fc7cBqZ9Xql4o4rmUMYIDhjCCA4ICAQEwdzBjMQswCQYD
# VQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lD
# ZXJ0IFRydXN0ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBAhAL
# rma8Wrp/lYfG+ekE4zMEMA0GCWCGSAFlAwQCAgUAoIHhMBoGCSqGSIb3DQEJAzEN
# BgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjUwNjA2MTgzODA4WjArBgsq
# hkiG9w0BCRACDDEcMBowGDAWBBTb04XuYtvSPnvk9nFIUIck1YZbRTA3BgsqhkiG
# 9w0BCRACLzEoMCYwJDAiBCB2dp+o8mMvH0MLOiMwrtZWdf7Xc9sF1mW5BZOYQ4+a
# 2zA/BgkqhkiG9w0BCQQxMgQwrYOEaDB8GumhW22w3xuAZATVu8O/VsOr71LSaUlP
# i7nFy1F4L+VdYRK3HyjTtjZXMA0GCSqGSIb3DQEBAQUABIICAEYFZd/FcToi+nd4
# Epo4NFpgVaCMP8yk7w2kl205/P6Svh93O4Wfn1Jm/fH2aS3OZL6ffQapg1hTLX/s
# fmNQM+CTzi9z2APjfz4q82sa4u3I3Ui2smAIEnW+3Z58DG/DuiD0DhyNVBo26B16
# 0IvOsSLDXzsb5z9eAPsvJckPwCqMiB10NdMy1a+Ue/zqmby7wLEWv3kKU0iMvKw2
# tFiF0vOzgJtWB1TNgBarlgrKpQf87R4mBcLt70QyRHE7c82PC3gdCQhmP6zPYmBp
# 6YjzdkR/x7eCWiLEF+dvnFWgPUVCCEZ9pDv2ICfzPnIujVTC6CGPXwHIAfgU3iY4
# mxefRTvoNujqF8fVkZlhUTEo1o+L+Pt7VA5JLqIjWgWlt1uMPuqS6FcK7dPdM+0t
# QgnvE8QdwO5n9ionocYlWsrYaqVfZ0u/c1XwLfdsKv6wBzF8L/0NdfEaHTvqMjcg
# BrDn5r/3R7pj0Z9WcU1AY/XfX2B80CD1r4iip3K9RHyIqtQY+knk9RakNvfvpIkB
# Z1afc5Rf03qDNhAp19MCI5AFz/zC9zRL4ThKD+Cvl2VnlH9i0eQFlnaN/m4Tkap5
# v5pWwtX8oysx2DsPtiCl17E350VlS9leQraym+LhNezx0t60Rnnk+ziZSxB0JbTz
# ZcywGegFBu8xuUKuJvlDKiNcC2Zz
# SIG # End signature block
