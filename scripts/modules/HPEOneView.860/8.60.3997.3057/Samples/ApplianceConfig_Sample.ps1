##############################################################################
# ApplianceConfig_Sample.ps1
# - Example scripts for configuring an HPE OneView appliance (networking, NTP,
#   etc.).
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

[CmdletBinding()]
param
(

    [Parameter (Mandatory, HelpMessage = "Please provide the Appliances DHCP Address.")]
    [ValidateNotNullorEmpty()]
	[IPAddress]$vm_ipaddr,

	[Parameter (Mandatory, HelpMessage = "Please provide the Appliances NEW Hostname or FQDN.")]
	[String]$Hostname,

	[Parameter (Mandatory, HelpMessage = "Provide a [SecureString] pr [String] object representing the new appliance Administrator password.")]
	[ValidateNotNullorEmpty()]
	[Object]$NewPassword,

	[Parameter (Mandatory, HelpMessage = "Please provide the Appliances NEW Static IPv4 Address.")]
    [ValidateNotNullorEmpty()]
	[IPAddress]$IPv4Address,

	[Parameter (Mandatory, HelpMessage = "Please provide the Appliances NEW IPv4 Subnet.")]
    [ValidateNotNullorEmpty()]
	[String]$IPv4SubnetMask,

	[Parameter (Mandatory, HelpMessage = "Please provide the Appliances NEW IPv4 Default Gateway.")]
    [ValidateNotNullorEmpty()]
	[IPAddress]$IPv4Gateway,

	[Parameter (Mandatory, HelpMessage = "Please provide the Appliances NEW IPv4 DNS Servers.")]
    [ValidateNotNullorEmpty()]
	[Array]$IPv4DnsServers,

	[Parameter (Mandatory, HelpMessage = "Please provide the Appliances NEW DNS Domain Name.")]
    [ValidateNotNullorEmpty()]
	[String]$DnsDomainName,

	[Parameter (Mandatory = $false, HelpMessage = "Please provide the Appliances NEW IPv4 NTP Servers.")]
    [ValidateNotNullorEmpty()]
	[Array]$IPv4NtpServers,

    [Parameter (Mandatory = $False, HelpMessage = "Please provide the Appliances NEW IPv6 Static Address.")]
    [ValidateNotNullorEmpty()]
    [IPAddress]$IPv6Address,

    [Parameter (Mandatory = $False, HelpMessage = "Please provide the Appliances NEW IPv6 Static Address CIDR Subnet Mask.")]
    [ValidateNotNullorEmpty()]
    [Int]$IPv6CidrMask

)

if (-not (get-module HPEOneView.700))
{

    Import-Module HPEOneView.700

}

#region

	Write-Host 'Waiting for appliance to respond to network test.' -NoNewline

	While (-not (Test-Connection -ComputerName $vm_ipaddr.IPAddressToString -Quiet))
	{

		Write-Host '.' -NoNewline

	}

	Write-Host ""

	#Core Appliance Setup

    # Accept the EULA
    if (-not (Get-OVEulaStatus -Appliance $vm_ipaddr.IPAddressToString).Accepted )
	{

        Write-Host "Accepting EULA..."

		Try
		{

			$ret = Set-OVEulaStatus -SupportAccess "yes" -Appliance $vm_ipaddr.IPAddressToString

		}

		Catch
		{

			$PSCMdlet.ThrowTerminatingError($_)
		}

    }

    # For initial setup, connect first using "default" Administrator credentials:
    Try
	{

		Connect-OVMgmt -appliance $vm_ipaddr.IPAddressToString -user "Administrator" -password "admin"

	}

    catch [HPEOneView.Appliance.PasswordChangeRequired]
	{

        Write-Host "Set initial password"

		Try
		{

			Set-OVInitialPassword -OldPassword "admin" -NewPassword $NewPassword -Appliance $vm_ipaddr.IPAddressToString

		}

		Catch
		{

			$PSCMdlet.ThrowTerminatingError($_)

		}

    }

	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}

    Write-Host "Reconnect with new password"

	Try
	{

		$ApplianceConnection = Connect-OVMgmt -appliance $vm_ipaddr.IPAddressToString -user Administrator -password $NewPassword

	}

	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}

    Write-Host "Set appliance networking configuration"

    $params = @{

        Hostname        = $Hostname;
        IPv4Addr        = $IPv4Address.IPAddressToString;
        IPv4Subnet      = $IPv4SubnetMask;
        IPv4Gateway     = $IPv4Gateway.IPAddressToString;
        DomainName      = $DnsDomainName;
        IPv4NameServers = $IPv4DnsServers

    }

	if ($IPv6Address)
    {

		$params.Add('IPv6Type','STATIC')
        $params.Add('IPv6Addr', $IPv6Address)
		$params.Add('IPv6Subnet', $IPv6CidrMask)

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

    Write-Host "Completed appliance networking configuration"

    $template = "WebServer" # must always use concatenated name format
    $CA       = "MyCA.domain.local\domain-MyCA-CA"
	$csrdir   = "C:\Certs\Requests"

    if (-not(Test-Path $csrdir))
	{

		New-Item -Path $csrdir -ItemType directory | Out-Null

	}

    #Process appliance certificate
    $CSR = @{

        Country         = "US";
        State           = "California";
        City            = "Palo Alto";
        Organization    = "Hewlett-Packard";
        CommonName      = $Hostname;
        AlternativeName = "$Hostname,hpov,$IPv4Address"

    }

	Try
	{

		$request = New-OVApplianceCsr @CSR -ApplianceConnection $ApplianceConnection

	}

	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}

    $baseName    = $Hostname
    $csrFileName = "$Hostname.csr"
    $cerFileName = "$Hostname.cer"

    Set-Content -path (Join-Path $csrdir -ChildPath $csrFileName) -value $request.base64Data -Force

    $csr = Get-ChildItem $csrdir | ? name -eq $csrFileName

    $parameters = "-config {0} -submit -attrib CertificateTemplate:{1} {2}\{3}.csr {2}\{3}.cer {2}\{3}.p7b" -f $CA, $template, $csrdir, $baseName

    $request = [System.Diagnostics.Process]::Start("certreq", $parameters)

    $request.WaitForExit()

    $Task = gc $csrdir\$cerFileName | Install-OVApplianceCertificate -ApplianceConnection $ApplianceConnection | Wait-OVTaskComplete

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
		$ServerAdminGroup = $LdapGroups | ? Name -match 'CI Manager Server'
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
	    gci \\Server\SPP\bp-Default-Baseline-0-1.iso | Add-OVBaseline

	}

	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}

    Try
	{

		write-host "Adding OneView license."
		New-OVLicense -License '9CDC D9MA H9P9 KHVY V7B5 HWWB Y9JL KMPL FE2H 5BP4 DXAU 2CSM GHTG L762 EG4Z X3VJ KJVT D5KM EFVW DW5J G4QM M6SW 9K2P 3E82 AJYM LURN TZZP AB6X 82Z5 WHEF D9ED 3RUX BJS2 XFXC T84U R42A 58S5 XA2D WXAP GMTQ 4YLB MM2S CZU7 2E4X E8EW BGB5 BWPD CAAR YT9J 4NUG 2NJN J9UF "424710048 HPOV-NFR1 HP_OneView_16_Seat_NFR 64HTAYJH92EY"_3KB73-R2JV9-V9HS6-LYGTN-6RLYW'

	}

	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}

	# Create the new users
    New-OVUser Nat   -fullName "Nat Network Admin"  -password hpinvent -roles "Network administrator"
    New-OVUser Sally -fullName "Sally Server Admin" -password hpinvent -roles "Server administrator"
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
    	password  = "password";
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

		New-OVNetwork -Name "VLAN 1-A" -type "Ethernet" -vlanId 1 -smartlink $true -purpose Management
		New-OVNetwork -Name "VLAN 1-B" -type "Ethernet" -vlanId 1 -smartlink $true -purpose Management

        # Internal Networks
		New-OVNetwork -Name "Live Migration" -type "Ethernet" -vlanId 100 -smartlink $true -purpose VMMigration
        New-OVNetwork -Name "Heartbeat" -type "Ethernet" -vlanId 101 -smartlink $true -purpose Management
        New-OVNetwork -Name "iSCSI Network" -type "Ethernet" -vlanId 3000 -smartlink $true -purpose ISCSI

		# VM Networks
		10,20,30,40,50 | % { New-OVNetwork -Name "VLAN $_-A" -type "Ethernet" -vlanId $_ -smartlink $true -purpose General }
		10,20,30,40,50 | % { New-OVNetwork -Name "VLAN $_-B" -type "Ethernet" -vlanId $_ -smartlink $true -purpose General }
		101,102,103,104,105 | % { New-OVNetwork -Name "Dev VLAN $_-A" -type "Ethernet" -vlanId $_ -smartlink $true -purpose General }
		101,102,103,104,105 | % { New-OVNetwork -Name "Dev VLAN $_-B" -type "Ethernet" -vlanId $_ -smartlink $true -purpose General }

        #Misc networks
        New-OVNetwork -Name "My Vlan 501" -type "Ethernet" -vlanId 3000 -smartlink $true -purpose General

		$ProdNetsA = Get-OVNetwork -Name "VLAN *0-A" -ErrorAction Stop
		$ProdNetsB = Get-OVNetwork -Name "VLAN *0-B" -ErrorAction Stop
		$DevNetsA  = Get-OVNetwork -Name "Dev VLAN *-A" -ErrorAction Stop
		$DevNetsB  = Get-OVNetwork -Name "Dev VLAN *-B" -ErrorAction Stop
        $InternalNetworks = 'Live Migration','Heartbeat' | % { Get-OVNetwork -Name $_ -ErrorAction Stop }

		# Create the network sets
		New-OVNetworkSet -Name "Prod NetSet1 A" -networks $ProdNetsA -untaggedNetwork $ProdNetsA[0] -typicalBandwidth 2500 -maximumBandwidth 10000
		New-OVNetworkSet -Name "Prod NetSet1 B" -networks $ProdNetsB -untaggedNetwork $ProdNetsB[0] -typicalBandwidth 2500 -maximumBandwidth 10000
		New-OVNetworkSet -Name "Dev Networks A" -networks $DevNetsA  -untaggedNetwork $DevNetsA[0]  -typicalBandwidth 2500 -maximumBandwidth 10000
		New-OVNetworkSet -Name "Dev Networks B" -networks $DevNetsB  -untaggedNetwork $DevNetsB[0]  -typicalBandwidth 2500 -maximumBandwidth 10000

		# Create the FC networks:
		New-OVNetwork -Name "Fabric A" -type "FibreChannel" -typicalBandwidth 4000 -autoLoginRedistribution $true -managedSan "SAN1_0"
		New-OVNetwork -Name "Fabric B" -type "FibreChannel" -typicalBandwidth 4000 -autoLoginRedistribution $true -managedSan "SAN1_1"
		New-OVNetwork -Name "DirectAttach A" -type "FibreChannel" -typicalBandwidth 4000 -autoLoginRedistribution $true -fabricType DirectAttach
		New-OVNetwork -Name "DirectAttach B" -type "FibreChannel" -typicalBandwidth 4000 -autoLoginRedistribution $true -fabricType DirectAttach

	}

    Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}

	Try
	{

		$LigName = "Default VC FF LIG"
		$Bays = @{ 1 = 'Flex2040f8'; 2 = 'Flex2040f8'}

		$SnmpDest1 = New-OVSnmpTrapDestination -Destination mysnmpserver.domain.local -Community MyR3adcommun1ty -SnmpFormat SNMPv1 -TrapSeverities critical,warning
		$SnmpDest2 = New-OVSnmpTrapDestination -Destination 10.44.120.9 -Community MyR3adcommun1ty -SnmpFormat SNMPv1 -TrapSeverities critical,warning -VCMTrapCategories legacy -EnetTrapCategories Other,PortStatus,PortThresholds -FCTrapCategories Other,PortStatus
		$SnmpConfig = New-OVSnmpConfiguration -ReadCommunity MyR3adC0mmun1ty -AccessList '10.44.120.9/32','172.20.148.0/22' -TrapDestinations $SnmpDest1,$SnmpDest2

		$CreatedLig = New-OVLogicalInterconnectGroup -Name $LigName -Bays $Bays -Snmp $SnmpConfig -EnableIgmpSnooping $True -InternalNetworks $InternalNetworks | Wait-OVTaskComplete | Get-OVLogicalInterconnectGroup

		# Get FC Network Objects
		$FabricA   = Get-OVNetwork -Name "Fabric A" -ErrorAction Stop
		$FabricB   = Get-OVNetwork -Name "Fabric B" -ErrorAction Stop
		$DAFabricA = Get-OVNetwork -Name "DirectAttach A" -ErrorAction Stop
		$DAFabricB = Get-OVNetwork -Name "DirectAttach B" -ErrorAction Stop

		# Create Ethernet Uplink Sets
		$CreatedLig = $CreatedLig | New-OVUplinkSet -Name "Uplink Set 1" -Type "Ethernet" -Networks $ProdNetsA -nativeEthNetwork $ProdNetsA[0] -UplinkPorts "BAY1:X1","BAY1:X2" -EthMode "Auto" | Wait-OVTaskComplete | Get-OVLogicalInterconnectGroup -ErrorAction Stop
		$CreatedLig = $CreatedLig | New-OVUplinkSet -Name "Uplink Set 2" -Type "Ethernet" -Networks $ProdNetsB -nativeEthNetwork $ProdNetsB[0] -UplinkPorts "BAY2:X1","BAY2:X2" -EthMode "Auto" | Wait-OVTaskComplete | Get-OVLogicalInterconnectGroup -ErrorAction Stop

		# FC Uplink Sets
		$CreatedLig = $CreatedLig | New-OVUplinkSet -Name "FC Fabric A" -Type "FibreChannel" -Networks $FabricA   -UplinkPorts "BAY1:X7" | Wait-OVTaskComplete | Get-OVLogicalInterconnectGroup -ErrorAction Stop
		$CreatedLig = $CreatedLig | New-OVUplinkSet -Name "FC Fabric B" -Type "FibreChannel" -Networks $FabricB   -UplinkPorts "BAY2:X7" | Wait-OVTaskComplete | Get-OVLogicalInterconnectGroup -ErrorAction Stop
		$CreatedLig = $CreatedLig | New-OVUplinkSet -Name "DA Fabric A" -Type "FibreChannel" -Networks $DAFabricA -UplinkPorts "BAY1:X3",'BAY1:X4' | Wait-OVTaskComplete | Get-OVLogicalInterconnectGroup -ErrorAction Stop
		$CreatedLig = $CreatedLig | New-OVUplinkSet -Name "DA Fabric B" -Type "FibreChannel" -Networks $DAFabricB -UplinkPorts "BAY2:X3",'BAY2:X4' | Wait-OVTaskComplete | Get-OVLogicalInterconnectGroup -ErrorAction Stop

	}

	Catch
	{

		$PSCMdlet.ParameterSetName

		$PSCMdlet.ThrowTerminatingError($_)

	}

	Try
	{

		$EGParams = @{

			Name                     = "Default EG 1"
			LogicalInterConnectGroup = $CreatedLig
			ConfigurationScript      = 'ADD USER "admin" "Supersecretpassword"
SET USER CONTACT "admin" ""
SET USER FULLNAME "admin" ""
SET USER ACCESS "admin" ADMINISTRATOR
ASSIGN SERVER 1-16 "admin"
ASSIGN INTERCONNECT 1-8 "admin"
ASSIGN OA "admin"
ENABLE USER "admin"
hponcfg all >> end_marker
<RIBCL VERSION="2.0">
   <LOGIN USER_LOGIN="admin" PASSWORD="passthrough">
      <USER_INFO MODE="write">
         <ADD_USER
           USER_NAME="admin"
           USER_LOGIN="admin"
           PASSWORD="Supersecretpassword">
            <ADMIN_PRIV value ="N"/>
            <REMOTE_CONS_PRIV value ="Y"/>
            <RESET_SERVER_PRIV value ="N"/>
            <VIRTUAL_MEDIA_PRIV value ="N"/>
            <CONFIG_ILO_PRIV value="Yes"/>
         </ADD_USER>
      </USER_INFO>
   </LOGIN>
</RIBCL>
end_marker'
		}

		$EnclosureGroup = New-OVEnclosureGroup @EGParams

	}

	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}

    Write-host "Sleeping 30 seconds"
    start-sleep -Seconds 30

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

        $Results = Get-OVStorageSystem -ErrorAction Stop | Add-OVStoragePool -Pool 'FST_CPG1','FST_CPG2' | Wait-OVTaskComplete

		$StorageVolume = Get-OVStoragePool -Pool 'FST_CPG1' -ErrorAction Stop | New-OVStorageVolume -Name 'DO NOT DELETE' -Capacity 1

	}

	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}

    #Add Encl1
    Try
    {

        $EnclosureAddParams = @{

            Hostname       = '172.18.1.11';
            Username       = 'administrator';
            Password       = 'password';
            EnclosureGroup = $EnclosureGroup

        }

		$Results = Add-OVEnclosure @EnclosureAddParams

    }

    Catch
    {

        $PSCMdlet.ThrowTerminatingError($_)

    }

    Disconnect-OVMgmt

	Remove-Module HPEOneView.630

#endregion
# SIG # Begin signature block
# MIItlQYJKoZIhvcNAQcCoIIthjCCLYICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD1x+aJKOAmknnS
# IFgs0rYjfYojB4S6AhtNzbQPdpk/MaCCEXYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# Syatatvx157YK9hlcPmVoa1oDE5/L9Uo2bC5a4CH2Rwxght1MIIbcQIBATBpMFQx
# CzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxKzApBgNVBAMT
# IlNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBDQSBSMzYCEQDzfDeB/ajwfQYd
# ZdJTJuKyMA0GCWCGSAFlAwQCAQUAoHwwEAYKKwYBBAGCNwIBDDECMAAwGQYJKoZI
# hvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcC
# ARUwLwYJKoZIhvcNAQkEMSIEIItZensOpfs912gHrIhRIZzdyjTZTUzfQ9MllsTq
# wJjJMA0GCSqGSIb3DQEBAQUABIIBgK6qghngiAw9vvnGG7mndQK96jHz2hgwZAsg
# WofeNx88CpOddZs7gCDc2cb3k/a5YPKJvxZs9/fpJ7FZ5TcFRKTuhEzWuc1dCuvI
# 3YvRmvLCsES/J1Fip1sC16IFmial29mjZFyqn9/ge0WaIhpi4ACXfoarv4HJyFx0
# s8Tbd/iYDl8KaRbPJchXSA1yVLe2unAyxLEZJahVc8k7HVzOc0Zv3tfGDgUwqvY+
# r2nvfuFBSFz32pLqZWcl8Ztpo8TixicJEUZfNM1oT7Cdz4IVMFunmpSduFDX6o3N
# H3YhipOyLbzcndQQ3cWPXqtigcawIU/tuJPzncYNNg0MvHnpFRn6UUDsJ0E88LT0
# 10YfC7+Azqna6k4XPVL4CKeRnZtwyNFX6iS9tKWfBkjzOhe47OrU2/NHF3NeSRlo
# JwnMqzWMYJnhRyjUlia8Dj4/5D5QWs3ksg1akc2a9bhsGCMuIzyftFJCU9wQ4Kbd
# BGwYiRbrN4jl5Y1KGPXTqzHZKt7BGaGCGN8wghjbBgorBgEEAYI3AwMBMYIYyzCC
# GMcGCSqGSIb3DQEHAqCCGLgwghi0AgEDMQ8wDQYJYIZIAWUDBAICBQAwggEEBgsq
# hkiG9w0BCRABBKCB9ASB8TCB7gIBAQYKKwYBBAGyMQIBATBBMA0GCWCGSAFlAwQC
# AgUABDDpfnMCO4qF7TS2vMNB5biAYB3ommMnY2w8WjV+gr4/RBrRllwJI64XimAv
# 2gXK3mICFQCxthWc7CdcVvBU92/Mu7E6Lb7yGhgPMjAyNDA5MTEwMTQ5MjJaoHKk
# cDBuMQswCQYDVQQGEwJHQjETMBEGA1UECBMKTWFuY2hlc3RlcjEYMBYGA1UEChMP
# U2VjdGlnbyBMaW1pdGVkMTAwLgYDVQQDEydTZWN0aWdvIFB1YmxpYyBUaW1lIFN0
# YW1waW5nIFNpZ25lciBSMzWgghL/MIIGXTCCBMWgAwIBAgIQOlJqLITOVeYdZfzM
# EtjpiTANBgkqhkiG9w0BAQwFADBVMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2Vj
# dGlnbyBMaW1pdGVkMSwwKgYDVQQDEyNTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1w
# aW5nIENBIFIzNjAeFw0yNDAxMTUwMDAwMDBaFw0zNTA0MTQyMzU5NTlaMG4xCzAJ
# BgNVBAYTAkdCMRMwEQYDVQQIEwpNYW5jaGVzdGVyMRgwFgYDVQQKEw9TZWN0aWdv
# IExpbWl0ZWQxMDAuBgNVBAMTJ1NlY3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcg
# U2lnbmVyIFIzNTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAI3RZ/TB
# SJu9/ThJOk1hgZvD2NxFpWEENo0GnuOYloD11BlbmKCGtcY0xiMrsN7LlEgcyosh
# tP3P2J/vneZhuiMmspY7hk/Q3l0FPZPBllo9vwT6GpoNnxXLZz7HU2ITBsTNOs9f
# hbdAWr/Mm8MNtYov32osvjYYlDNfefnBajrQqSV8Wf5ZvbaY5lZhKqQJUaXxpi4T
# XZKohLgxU7g9RrFd477j7jxilCU2ptz+d1OCzNFAsXgyPEM+NEMPUz2q+ktNlxMZ
# XPF9WLIhOhE3E8/oNSJkNTqhcBGsbDI/1qCU9fBhuSojZ0u5/1+IjMG6AINyI6XL
# xM8OAGQmaMB8gs2IZxUTOD7jTFR2HE1xoL7qvSO4+JHtvNceHu//dGeVm5Pdkay3
# Et+YTt9EwAXBsd0PPmC0cuqNJNcOI0XnwjE+2+Zk8bauVz5ir7YHz7mlj5Bmf7W8
# SJ8jQwO2IDoHHFC46ePg+eoNors0QrC0PWnOgDeMkW6gmLBtq3CEOSDU8iNicwNs
# Nb7ABz0W1E3qlSw7jTmNoGCKCgVkLD2FaMs2qAVVOjuUxvmtWMn1pIFVUvZ1yrPI
# VbYt1aTld2nrmh544Auh3tgggy/WluoLXlHtAJgvFwrVsKXj8ekFt0TmaPL0lHvQ
# Ee5jHbufhc05lvCtdwbfBl/2ARSTuy1s8CgFAgMBAAGjggGOMIIBijAfBgNVHSME
# GDAWgBRfWO1MMXqiYUKNUoC6s2GXGaIymzAdBgNVHQ4EFgQUaO+kMklptlI4HepD
# OSz0FGqeDIUwDgYDVR0PAQH/BAQDAgbAMAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/
# BAwwCgYIKwYBBQUHAwgwSgYDVR0gBEMwQTA1BgwrBgEEAbIxAQIBAwgwJTAjBggr
# BgEFBQcCARYXaHR0cHM6Ly9zZWN0aWdvLmNvbS9DUFMwCAYGZ4EMAQQCMEoGA1Ud
# HwRDMEEwP6A9oDuGOWh0dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1B1Ymxp
# Y1RpbWVTdGFtcGluZ0NBUjM2LmNybDB6BggrBgEFBQcBAQRuMGwwRQYIKwYBBQUH
# MAKGOWh0dHA6Ly9jcnQuc2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY1RpbWVTdGFt
# cGluZ0NBUjM2LmNydDAjBggrBgEFBQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5j
# b20wDQYJKoZIhvcNAQEMBQADggGBALDcLsn6TzZMii/2yU/V7xhPH58Oxr/+EnrZ
# jpIyvYTz2u/zbL+fzB7lbrPml8ERajOVbudan6x08J1RMXD9hByq+yEfpv1G+z2p
# mnln5XucfA9MfzLMrCArNNMbUjVcRcsAr18eeZeloN5V4jwrovDeLOdZl0tB7fOX
# 5F6N2rmXaNTuJR8yS2F+EWaL5VVg+RH8FelXtRvVDLJZ5uqSNIckdGa/eUFhtDKT
# Tz9LtOUh46v2JD5Q3nt8mDhAjTKp2fo/KJ6FLWdKAvApGzjpPwDqFeJKf+kJdoBK
# d2zQuwzk5Wgph9uA46VYK8p/BTJJahKCuGdyKFIFfEfakC4NXa+vwY4IRp49lzQP
# Lo7WticqMaaqb8hE2QmCFIyLOvWIg4837bd+60FcCGbHwmL/g1ObIf0rRS9ceK4D
# Y9rfBnHFH2v1d4hRVvZXyCVlrL7ZQuVzjjkLMK9VJlXTVkHpuC8K5S4HHTv2AJx6
# mOdkMJwS4gLlJ7gXrIVpnxG+aIniGDCCBhQwggP8oAMCAQICEHojrtpTaZYPkcg+
# XPTH4z8wDQYJKoZIhvcNAQEMBQAwVzELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1Nl
# Y3RpZ28gTGltaXRlZDEuMCwGA1UEAxMlU2VjdGlnbyBQdWJsaWMgVGltZSBTdGFt
# cGluZyBSb290IFI0NjAeFw0yMTAzMjIwMDAwMDBaFw0zNjAzMjEyMzU5NTlaMFUx
# CzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLDAqBgNVBAMT
# I1NlY3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcgQ0EgUjM2MIIBojANBgkqhkiG
# 9w0BAQEFAAOCAY8AMIIBigKCAYEAzZjYQ0GrboIr7PYzfiY05ImM0+8iEoBUPu8m
# r4wOgYPjoiIz5vzf7d5wu8GFK1JWN5hciN9rdqOhbdxLcSVwnOTJmUGfAMQm4eXO
# ls3iQwfapEFWuOsYmBKXPNSpwZAFoLGl5y1EaGGc5LByM8wjcbSF52/Z42YaJRsP
# XY545E3QAPN2mxDh0OLozhiGgYT1xtjXVfEzYBVmfQaI5QL35cTTAjsJAp85R+KA
# sOfuL9Z7LFnjdcuPkZWjssMETFIueH69rxbFOUD64G+rUo7xFIdRAuDNvWBsv0iG
# DPGaR2nZlY24tz5fISYk1sPY4gir99aXAGnoo0vX3Okew4MsiyBn5ZnUDMKzUcQr
# pVavGacrIkmDYu/bcOUR1mVBIZ0X7P4bKf38JF7Mp7tY3LFF/h7hvBS2tgTYXlD7
# TnIMPrxyXCfB5yQq3FFoXRXM3/DvqQ4shoVWF/mwwz9xoRku05iphp22fTfjKRIV
# pm4gFT24JKspEpM8mFa9eTgKWWCvAgMBAAGjggFcMIIBWDAfBgNVHSMEGDAWgBT2
# d2rdP/0BE/8WoWyCAi/QCj0UJTAdBgNVHQ4EFgQUX1jtTDF6omFCjVKAurNhlxmi
# MpswDgYDVR0PAQH/BAQDAgGGMBIGA1UdEwEB/wQIMAYBAf8CAQAwEwYDVR0lBAww
# CgYIKwYBBQUHAwgwEQYDVR0gBAowCDAGBgRVHSAAMEwGA1UdHwRFMEMwQaA/oD2G
# O2h0dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY1RpbWVTdGFtcGlu
# Z1Jvb3RSNDYuY3JsMHwGCCsGAQUFBwEBBHAwbjBHBggrBgEFBQcwAoY7aHR0cDov
# L2NydC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljVGltZVN0YW1waW5nUm9vdFI0
# Ni5wN2MwIwYIKwYBBQUHMAGGF2h0dHA6Ly9vY3NwLnNlY3RpZ28uY29tMA0GCSqG
# SIb3DQEBDAUAA4ICAQAS13sgrQ41WAyegR0lWP1MLWd0r8diJiH2VVRpxqFGhnZb
# aF+IQ7JATGceTWOS+kgnMAzGYRzpm8jIcjlSQ8JtcqymKhgx1s6cFZBSfvfeoyig
# F8iCGlH+SVSo3HHr98NepjSFJTU5KSRKK+3nVSWYkSVQgJlgGh3MPcz9IWN4I/n1
# qfDGzqHCPWZ+/Mb5vVyhgaeqxLPbBIqv6cM74Nvyo1xNsllECJJrOvsrJQkajVz4
# xJwZ8blAdX5umzwFfk7K/0K3fpjgiXpqNOpXaJ+KSRW0HdE0FSDC7+ZKJJSJx78m
# n+rwEyT+A3z7Ss0gT5CpTrcmhUwIw9jbvnYuYRKxFVWjKklW3z83epDVzoWJttxF
# pujdrNmRwh1YZVIB2guAAjEQoF42H0BA7WBCueHVMDyV1e4nM9K4As7PVSNvQ8LI
# 1WRaTuGSFUd9y8F8jw22BZC6mJoB40d7SlZIYfaildlgpgbgtu6SDsek2L8qomG5
# 7Yp5qTqof0DwJ4Q4HsShvRl/59T4IJBovRwmqWafH0cIPEX7cEttS5+tXrgRtMjj
# TOp6A9l0D6xcKZtxnLqiTH9KPCy6xZEi0UDcMTww5Fl4VvoGbMG2oonuX3f1tsoH
# LaO/Fwkj3xVr3lDkmeUqivebQTvGkx5hGuJaSVQ+x60xJ/Y29RBr8Tm9XJ59AjCC
# BoIwggRqoAMCAQICEDbCsL18Gzrno7PdNsvJdWgwDQYJKoZIhvcNAQEMBQAwgYgx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpOZXcgSmVyc2V5MRQwEgYDVQQHEwtKZXJz
# ZXkgQ2l0eTEeMBwGA1UEChMVVGhlIFVTRVJUUlVTVCBOZXR3b3JrMS4wLAYDVQQD
# EyVVU0VSVHJ1c3QgUlNBIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MB4XDTIxMDMy
# MjAwMDAwMFoXDTM4MDExODIzNTk1OVowVzELMAkGA1UEBhMCR0IxGDAWBgNVBAoT
# D1NlY3RpZ28gTGltaXRlZDEuMCwGA1UEAxMlU2VjdGlnbyBQdWJsaWMgVGltZSBT
# dGFtcGluZyBSb290IFI0NjCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
# AIid2LlFZ50d3ei5JoGaVFTAfEkFm8xaFQ/ZlBBEtEFAgXcUmanU5HYsyAhTXiDQ
# kiUvpVdYqZ1uYoZEMgtHES1l1Cc6HaqZzEbOOp6YiTx63ywTon434aXVydmhx7Dx
# 4IBrAou7hNGsKioIBPy5GMN7KmgYmuu4f92sKKjbxqohUSfjk1mJlAjthgF7Hjx4
# vvyVDQGsd5KarLW5d73E3ThobSkob2SL48LpUR/O627pDchxll+bTSv1gASn/hp6
# IuHJorEu6EopoB1CNFp/+HpTXeNARXUmdRMKbnXWflq+/g36NJXB35ZvxQw6zid6
# 1qmrlD/IbKJA6COw/8lFSPQwBP1ityZdwuCysCKZ9ZjczMqbUcLFyq6KdOpuzVDR
# 3ZUwxDKL1wCAxgL2Mpz7eZbrb/JWXiOcNzDpQsmwGQ6Stw8tTCqPumhLRPb7YkzM
# 8/6NnWH3T9ClmcGSF22LEyJYNWCHrQqYubNeKolzqUbCqhSqmr/UdUeb49zYHr7A
# LL8bAJyPDmubNqMtuaobKASBqP84uhqcRY/pjnYd+V5/dcu9ieERjiRKKsxCG1t6
# tG9oj7liwPddXEcYGOUiWLm742st50jGwTzxbMpepmOP1mLnJskvZaN5e45NuzAH
# teORlsSuDt5t4BBRCJL+5EZnnw0ezntk9R8QJyAkL6/bAgMBAAGjggEWMIIBEjAf
# BgNVHSMEGDAWgBRTeb9aqitKz1SA4dibwJ3ysgNmyzAdBgNVHQ4EFgQU9ndq3T/9
# ARP/FqFsggIv0Ao9FCUwDgYDVR0PAQH/BAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8w
# EwYDVR0lBAwwCgYIKwYBBQUHAwgwEQYDVR0gBAowCDAGBgRVHSAAMFAGA1UdHwRJ
# MEcwRaBDoEGGP2h0dHA6Ly9jcmwudXNlcnRydXN0LmNvbS9VU0VSVHJ1c3RSU0FD
# ZXJ0aWZpY2F0aW9uQXV0aG9yaXR5LmNybDA1BggrBgEFBQcBAQQpMCcwJQYIKwYB
# BQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0cnVzdC5jb20wDQYJKoZIhvcNAQEMBQAD
# ggIBAA6+ZUHtaES45aHF1BGH5Lc7JYzrftrIF5Ht2PFDxKKFOct/awAEWgHQMVHo
# l9ZLSyd/pYMbaC0IZ+XBW9xhdkkmUV/KbUOiL7g98M/yzRyqUOZ1/IY7Ay0YbMni
# IibJrPcgFp73WDnRDKtVutShPSZQZAdtFwXnuiWl8eFARK3PmLqEm9UsVX+55DbV
# Iz33Mbhba0HUTEYv3yJ1fwKGxPBsP/MgTECimh7eXomvMm0/GPxX2uhwCcs/YLxD
# nBdVVlxvDjHjO1cuwbOpkiJGHmLXXVNbsdXUC2xBrq9fLrfe8IBsA4hopwsCj8hT
# uwKXJlSTrZcPRVSccP5i9U28gZ7OMzoJGlxZ5384OKm0r568Mo9TYrqzKeKZgFo0
# fj2/0iHbj55hc20jfxvK3mQi+H7xpbzxZOFGm/yVQkpo+ffv5gdhp+hv1GDsvJOt
# JinJmgGbBFZIThbqI+MHvAmMmkfb3fTxmSkop2mSJL1Y2x/955S29Gu0gSJIkc3z
# 30vU/iXrMpWx2tS7UVfVP+5tKuzGtgkP7d/doqDrLF1u6Ci3TpjAZdeLLlRQZm86
# 7eVeXED58LXd1Dk6UvaAhvmWYXoiLz4JA5gPBcz7J311uahxCweNxE+xxxR3kT0W
# KzASo5G/PyDez6NHdIUKBeE3jDPs2ACc6CkJ1Sji4PKWVT0/MYIEkTCCBI0CAQEw
# aTBVMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSwwKgYD
# VQQDEyNTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIENBIFIzNgIQOlJqLITO
# VeYdZfzMEtjpiTANBglghkgBZQMEAgIFAKCCAfkwGgYJKoZIhvcNAQkDMQ0GCyqG
# SIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yNDA5MTEwMTQ5MjJaMD8GCSqGSIb3
# DQEJBDEyBDB9YP4Q8QABXpcGPrAisxM93po4Vz9hLRvdSym69AMGc+mS9/UadLQG
# Ad2imXBEjKgwggF6BgsqhkiG9w0BCRACDDGCAWkwggFlMIIBYTAWBBT4YJgZpvuI
# LPfoUpfyoRlSGhZ3XzCBhwQUxq5U5HiG8Xw9VRJIjGnDSnr5wt0wbzBbpFkwVzEL
# MAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEuMCwGA1UEAxMl
# U2VjdGlnbyBQdWJsaWMgVGltZSBTdGFtcGluZyBSb290IFI0NgIQeiOu2lNplg+R
# yD5c9MfjPzCBvAQUhT1jLZOCgmF80JA1xJHeksFC2scwgaMwgY6kgYswgYgxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpOZXcgSmVyc2V5MRQwEgYDVQQHEwtKZXJzZXkg
# Q2l0eTEeMBwGA1UEChMVVGhlIFVTRVJUUlVTVCBOZXR3b3JrMS4wLAYDVQQDEyVV
# U0VSVHJ1c3QgUlNBIENlcnRpZmljYXRpb24gQXV0aG9yaXR5AhA2wrC9fBs656Oz
# 3TbLyXVoMA0GCSqGSIb3DQEBAQUABIICAGb2I9lM3sEGnNEEj5vhO1zYnBm4PF44
# 9ROUMldsxZz0qMskbZiVnsVEsU84Cy0WiHwmxEOXDHAP/vqnI/5iQnyMOCalKDz/
# QPiPfB8g55WwaI8lau/8cxTdDO8R3z9JqjWS7vni9VXK9sThdLqceZvSpitIs8xP
# d0w4q6qiLXcCJR7RIUyN3p8szlTAnJceqJ3sd/dLVIOtx21TVwVH3NW2ptqBZVQG
# Y8ZzCNeiEosbxBSMnp9bBw/zWkHQEFp3N++I+Q4qPSI8ziQ7dBAnkBdZqG5xVHRy
# 2GnMQwe8lgpNrjWSLHx74YssDZCGxr0bxC9w4f4y4LTSfYOG/guif70/BhpMey5m
# 2cY/zZTft5KrDSwkQ7lwbyZmEhJ/6+rrSgwkT9LLVEi10XbSkd1BqvCV04C1qazR
# XYMsObnULE8Itzt64uxmEcbNhY26rj2vBAYpOJ1X3Lbd0P9e2KZ8QT8yLvVoBCGd
# kklNt9QI1tOj/1FB6Sk0baSNZ3wk251jYUK80cD/EPOuLZOx6TSOccyI3j9v8vKZ
# 7wrc9NRKGKHSUPmktoFwyxGRHPTYlsnFAXRM4ugk3MlR0oUVMKyt1CEW6Y+4zfc7
# wk8P+AzKIUedhZznk1fFacmastpPsuYzTYqA22kF1/S15OPKlmoKugDAQrBP8DpB
# pH+XWvD251Nn
# SIG # End signature block
