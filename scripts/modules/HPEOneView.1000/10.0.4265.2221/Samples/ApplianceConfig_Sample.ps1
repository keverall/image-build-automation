##############################################################################
# ApplianceConfig_Sample.ps1
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
# MIItEAYJKoZIhvcNAQcCoIItATCCLP0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCChFfTdGW8I/wUL
# toCvFfRNl+biUf9LRoKEx6lVf9Gr0qCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# nZ+oA+rbZZyGZkz3xbUYKTGCGnAwghpsAgEBMGkwVDELMAkGA1UEBhMCR0IxGDAW
# BgNVBAoTD1NlY3RpZ28gTGltaXRlZDErMCkGA1UEAxMiU2VjdGlnbyBQdWJsaWMg
# Q29kZSBTaWduaW5nIENBIFIzNgIRAMgx4fswkMFDciVfUuoKqr0wDQYJYIZIAWUD
# BAIBBQCgfDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGC
# NwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQx
# IgQgioj2xvKnJg4Xf6EPkgMDKBvTLflmLgy+Mz6uRpBNlnkwDQYJKoZIhvcNAQEB
# BQAEggIAGNJF9HnRRglnqx9ZTdbhaRI0YMgu8oEUKH8vG61q3dtrDjw2xBsHvErE
# NBCMRWpKxqJsLG/GFEOtMEN67dOUR/tSfo0C0u25I8SDup8vMB69B4gxFQZLW0HX
# f1lZ8EidGUfTCmLpJstAg8pDGLExTjgiIKS9/imLEKyetuc5aSAPdewe+/PWLIOB
# OfSw8hHCH9e7A14vvX34YcKQiiZFrVqn0eKvGy0YKONnGkBaH7q19ceiCXb0UTdl
# WDf0ri1dgcXM6pBCPN92+FE1uwP9tWg6arwQiwHHjB2+dI4zsW4dViWFp8quBjMr
# 7MpWik7G/1S8F1NtEBTLeT8S2fDIVZrH0s3IV1Kw5Jy5YM93DhBbzRi9pVpdRY36
# Aq70oWdf0OekKg7HzCzgK4yfQkV9kFEq1tYv5m3yF5OTg1kwvgtbfLEauNfL7RkX
# 32LkwN5ROXdMpBI9dHdGyCDqglaEplAtKhd/5DqJaxu0WDhWRTaMT1TTbSwX3R2I
# nDYvP9xd/P7DyVcgKsiALNbn99v4x+MHy4fS5Czw8zf7DoyhLCKeds8HZfSbfyxj
# KPW2P92HhQW36z4b/MPy92W51lFJWS1QsWpVrNbbwx4fzvUqYLM9jXdrYQBGv39c
# WCeTfJj2NSadMFPC709wDOjLJo5ouO0XvXvF6eQGAubqeMUVhLahghdaMIIXVgYK
# KwYBBAGCNwMDATGCF0YwghdCBgkqhkiG9w0BBwKgghczMIIXLwIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIGHBgsqhkiG9w0BCRABBKB4BHYwdAIBAQYJYIZIAYb9bAcBMEEw
# DQYJYIZIAWUDBAICBQAEMI0KflahH+WK6WeSJc6fHTiBi55L7UWTa3pRgFZ0cngm
# 5sk66IxmRaXy1kjqLSgIbwIQFZ49CU84lQ0P5WEdIVnQaxgPMjAyNTA2MDYxODM3
# NDZaoIITAzCCBrwwggSkoAMCAQICEAuuZrxaun+Vh8b56QTjMwQwDQYJKoZIhvcN
# AQELBQAwYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTsw
# OQYDVQQDEzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVT
# dGFtcGluZyBDQTAeFw0yNDA5MjYwMDAwMDBaFw0zNTExMjUyMzU5NTlaMEIxCzAJ
# BgNVBAYTAlVTMREwDwYDVQQKEwhEaWdpQ2VydDEgMB4GA1UEAxMXRGlnaUNlcnQg
# VGltZXN0YW1wIDIwMjQwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC+
# anOf9pUhq5Ywultt5lmjtej9kR8YxIg7apnjpcH9CjAgQxK+CMR0Rne/i+utMeV5
# bUlYYSuuM4vQngvQepVHVzNLO9RDnEXvPghCaft0djvKKO+hDu6ObS7rJcXa/UKv
# NminKQPTv/1+kBPgHGlP28mgmoCw/xi6FG9+Un1h4eN6zh926SxMe6We2r1Z6VFZ
# j75MU/HNmtsgtFjKfITLutLWUdAoWle+jYZ49+wxGE1/UXjWfISDmHuI5e/6+NfQ
# rxGFSKx+rDdNMsePW6FLrphfYtk/FLihp/feun0eV+pIF496OVh4R1TvjQYpAztJ
# pVIfdNsEvxHofBf1BWkadc+Up0Th8EifkEEWdX4rA/FE1Q0rqViTbLVZIqi6viEk
# 3RIySho1XyHLIAOJfXG5PEppc3XYeBH7xa6VTZ3rOHNeiYnY+V4j1XbJ+Z9dI8Zh
# qcaDHOoj5KGg4YuiYx3eYm33aebsyF6eD9MF5IDbPgjvwmnAalNEeJPvIeoGJXae
# BQjIK13SlnzODdLtuThALhGtyconcVuPI8AaiCaiJnfdzUcb3dWnqUnjXkRFwLts
# VAxFvGqsxUA2Jq/WTjbnNjIUzIs3ITVC6VBKAOlb2u29Vwgfta8b2ypi6n2PzP0n
# VepsFk8nlcuWfyZLzBaZ0MucEdeBiXL+nUOGhCjl+QIDAQABo4IBizCCAYcwDgYD
# VR0PAQH/BAQDAgeAMAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUH
# AwgwIAYDVR0gBBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMB8GA1UdIwQYMBaA
# FLoW2W1NhS9zKXaaL3WMaiCPnshvMB0GA1UdDgQWBBSfVywDdw4oFZBmpWNe7k+S
# H3agWzBaBgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsMy5kaWdpY2VydC5jb20v
# RGlnaUNlcnRUcnVzdGVkRzRSU0E0MDk2U0hBMjU2VGltZVN0YW1waW5nQ0EuY3Js
# MIGQBggrBgEFBQcBAQSBgzCBgDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGln
# aWNlcnQuY29tMFgGCCsGAQUFBzAChkxodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5j
# b20vRGlnaUNlcnRUcnVzdGVkRzRSU0E0MDk2U0hBMjU2VGltZVN0YW1waW5nQ0Eu
# Y3J0MA0GCSqGSIb3DQEBCwUAA4ICAQA9rR4fdplb4ziEEkfZQ5H2EdubTggd0ShP
# z9Pce4FLJl6reNKLkZd5Y/vEIqFWKt4oKcKz7wZmXa5VgW9B76k9NJxUl4JlKwyj
# UkKhk3aYx7D8vi2mpU1tKlY71AYXB8wTLrQeh83pXnWwwsxc1Mt+FWqz57yFq6la
# ICtKjPICYYf/qgxACHTvypGHrC8k1TqCeHk6u4I/VBQC9VK7iSpU5wlWjNlHlFFv
# /M93748YTeoXU/fFa9hWJQkuzG2+B7+bMDvmgF8VlJt1qQcl7YFUMYgZU1WM6nyw
# 23vT6QSgwX5Pq2m0xQ2V6FJHu8z4LXe/371k5QrN9FQBhLLISZi2yemW0P8ZZfx4
# zvSWzVXpAb9k4Hpvpi6bUe8iK6WonUSV6yPlMwerwJZP/Gtbu3CKldMnn+LmmRTk
# TXpFIEB06nXZrDwhCGED+8RsWQSIXZpuG4WLFQOhtloDRWGoCwwc6ZpPddOFkM2L
# lTbMcqFSzm4cd0boGhBq7vkqI1uHRz6Fq1IX7TaRQuR+0BGOzISkcqwXu7nMpFu3
# mgrlgbAW+BzikRVQ3K2YHcGkiKjA4gi4OA/kz1YCsdhIBHXqBzR0/Zd2QwQ/l4Gx
# ftt/8wY3grcc/nS//TVkej9nmUYu83BDtccHHXKibMs/yXHhDXNkoPIdynhVAku7
# aRZOwqw6pDCCBq4wggSWoAMCAQICEAc2N7ckVHzYR6z9KGYqXlswDQYJKoZIhvcN
# AQELBQAwYjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcG
# A1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3Rl
# ZCBSb290IEc0MB4XDTIyMDMyMzAwMDAwMFoXDTM3MDMyMjIzNTk1OVowYzELMAkG
# A1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdp
# Q2VydCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQTCC
# AiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMaGNQZJs8E9cklRVcclA8Ty
# kTepl1Gh1tKD0Z5Mom2gsMyD+Vr2EaFEFUJfpIjzaPp985yJC3+dH54PMx9QEwsm
# c5Zt+FeoAn39Q7SE2hHxc7Gz7iuAhIoiGN/r2j3EF3+rGSs+QtxnjupRPfDWVtTn
# KC3r07G1decfBmWNlCnT2exp39mQh0YAe9tEQYncfGpXevA3eZ9drMvohGS0UvJ2
# R/dhgxndX7RUCyFobjchu0CsX7LeSn3O9TkSZ+8OpWNs5KbFHc02DVzV5huowWR0
# QKfAcsW6Th+xtVhNef7Xj3OTrCw54qVI1vCwMROpVymWJy71h6aPTnYVVSZwmCZ/
# oBpHIEPjQ2OAe3VuJyWQmDo4EbP29p7mO1vsgd4iFNmCKseSv6De4z6ic/rnH1ps
# lPJSlRErWHRAKKtzQ87fSqEcazjFKfPKqpZzQmiftkaznTqj1QPgv/CiPMpC3BhI
# fxQ0z9JMq++bPf4OuGQq+nUoJEHtQr8FnGZJUlD0UfM2SU2LINIsVzV5K6jzRWC8
# I41Y99xh3pP+OcD5sjClTNfpmEpYPtMDiP6zj9NeS3YSUZPJjAw7W4oiqMEmCPkU
# EBIDfV8ju2TjY+Cm4T72wnSyPx4JduyrXUZ14mCjWAkBKAAOhFTuzuldyF4wEr1G
# nrXTdrnSDmuZDNIztM2xAgMBAAGjggFdMIIBWTASBgNVHRMBAf8ECDAGAQH/AgEA
# MB0GA1UdDgQWBBS6FtltTYUvcyl2mi91jGogj57IbzAfBgNVHSMEGDAWgBTs1+OC
# 0nFdZEzfLmc/57qYrhwPTzAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYB
# BQUHAwgwdwYIKwYBBQUHAQEEazBpMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5k
# aWdpY2VydC5jb20wQQYIKwYBBQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0
# LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3J0MEMGA1UdHwQ8MDowOKA2oDSG
# Mmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQu
# Y3JsMCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0B
# AQsFAAOCAgEAfVmOwJO2b5ipRCIBfmbW2CFC4bAYLhBNE88wU86/GPvHUF3iSyn7
# cIoNqilp/GnBzx0H6T5gyNgL5Vxb122H+oQgJTQxZ822EpZvxFBMYh0MCIKoFr2p
# Vs8Vc40BIiXOlWk/R3f7cnQU1/+rT4osequFzUNf7WC2qk+RZp4snuCKrOX9jLxk
# Jodskr2dfNBwCnzvqLx1T7pa96kQsl3p/yhUifDVinF2ZdrM8HKjI/rAJ4JErpkn
# G6skHibBt94q6/aesXmZgaNWhqsKRcnfxI2g55j7+6adcq/Ex8HBanHZxhOACcS2
# n82HhyS7T6NJuXdmkfFynOlLAlKnN36TU6w7HQhJD5TNOXrd/yVjmScsPT9rp/Fm
# w0HNT7ZAmyEhQNC3EyTN3B14OuSereU0cZLXJmvkOHOrpgFPvT87eK1MrfvElXvt
# Cl8zOYdBeHo46Zzh3SP9HSjTx/no8Zhf+yvYfvJGnXUsHicsJttvFXseGYs2uJPU
# 5vIXmVnKcPA3v5gA3yAWTyf7YGcWoWa63VXAOimGsJigK+2VQbc61RWYMbRiCQ8K
# vYHZE/6/pNHzV9m8BPqC3jLfBInwAM1dwvnQI38AC+R2AibZ8GV2QqYphwlHK+Z/
# GqSFD/yYlvZVVCsfgPrA8g4r5db7qS9EFUrnEw4d2zc4GqEr9u3WfPwwggWNMIIE
# daADAgECAhAOmxiO+dAt5+/bUOIIQBhaMA0GCSqGSIb3DQEBDAUAMGUxCzAJBgNV
# BAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdp
# Y2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAe
# Fw0yMjA4MDEwMDAwMDBaFw0zMTExMDkyMzU5NTlaMGIxCzAJBgNVBAYTAlVTMRUw
# EwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20x
# ITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDCCAiIwDQYJKoZIhvcN
# AQEBBQADggIPADCCAgoCggIBAL/mkHNo3rvkXUo8MCIwaTPswqclLskhPfKK2FnC
# 4SmnPVirdprNrnsbhA3EMB/zG6Q4FutWxpdtHauyefLKEdLkX9YFPFIPUh/GnhWl
# fr6fqVcWWVVyr2iTcMKyunWZanMylNEQRBAu34LzB4TmdDttceItDBvuINXJIB1j
# KS3O7F5OyJP4IWGbNOsFxl7sWxq868nPzaw0QF+xembud8hIqGZXV59UWI4MK7dP
# pzDZVu7Ke13jrclPXuU15zHL2pNe3I6PgNq2kZhAkHnDeMe2scS1ahg4AxCN2NQ3
# pC4FfYj1gj4QkXCrVYJBMtfbBHMqbpEBfCFM1LyuGwN1XXhm2ToxRJozQL8I11pJ
# pMLmqaBn3aQnvKFPObURWBf3JFxGj2T3wWmIdph2PVldQnaHiZdpekjw4KISG2aa
# dMreSx7nDmOu5tTvkpI6nj3cAORFJYm2mkQZK37AlLTSYW3rM9nF30sEAMx9HJXD
# j/chsrIRt7t/8tWMcCxBYKqxYxhElRp2Yn72gLD76GSmM9GJB+G9t+ZDpBi4pncB
# 4Q+UDCEdslQpJYls5Q5SUUd0viastkF13nqsX40/ybzTQRESW+UQUOsxxcpyFiIJ
# 33xMdT9j7CFfxCBRa2+xq4aLT8LWRV+dIPyhHsXAj6KxfgommfXkaS+YHS312amy
# HeUbAgMBAAGjggE6MIIBNjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTs1+OC
# 0nFdZEzfLmc/57qYrhwPTzAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823I
# DzAOBgNVHQ8BAf8EBAMCAYYweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhho
# dHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNl
# cnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwRQYD
# VR0fBD4wPDA6oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0
# QXNzdXJlZElEUm9vdENBLmNybDARBgNVHSAECjAIMAYGBFUdIAAwDQYJKoZIhvcN
# AQEMBQADggEBAHCgv0NcVec4X6CjdBs9thbX979XB72arKGHLOyFXqkauyL4hxpp
# VCLtpIh3bb0aFPQTSnovLbc47/T/gLn4offyct4kvFIDyE7QKt76LVbP+fT3rDB6
# mouyXtTP0UNEm0Mh65ZyoUi0mcudT6cGAxN3J0TU53/oWajwvy8LpunyNDzs9wPH
# h6jSTEAZNUZqaVSwuKFWjuyk1T3osdz9HNj0d1pcVIxv76FQPfx2CWiEn2/K2yCN
# NWAcAgPLILCsWKAOQGPFmCLBsln1VWvPJ6tsds5vIy30fnFqI2si/xK4VC0nftg6
# 2fC2h5b9W9FcrBjDTZ9ztwGpn1eqXijiuZQxggOGMIIDggIBATB3MGMxCzAJBgNV
# BAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMyRGlnaUNl
# cnQgVHJ1c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcgQ0ECEAuu
# Zrxaun+Vh8b56QTjMwQwDQYJYIZIAWUDBAICBQCggeEwGgYJKoZIhvcNAQkDMQ0G
# CyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yNTA2MDYxODM3NDZaMCsGCyqG
# SIb3DQEJEAIMMRwwGjAYMBYEFNvThe5i29I+e+T2cUhQhyTVhltFMDcGCyqGSIb3
# DQEJEAIvMSgwJjAkMCIEIHZ2n6jyYy8fQws6IzCu1lZ1/tdz2wXWZbkFk5hDj5rb
# MD8GCSqGSIb3DQEJBDEyBDDj5O2woWqVSL4fVHfjj1K6q7zUqJxdp5eT5WF1Jj9p
# CEKXzVMAlWI+CfsE/l70jJQwDQYJKoZIhvcNAQEBBQAEggIAf7Mg4AJFEZ45WjV1
# 10b1Chpr2qQrhxs7O6nn+4kjxeP0aQ0D68GW6p64rciDKJK3v/YxpyzH6OyJ83rY
# m+bxH/RpQCXkhPwVa/MRlA1Exf3DIYcXqAXVSkKzpluXDkAvB/7ozx9J/iA0hmus
# K0e3d4zMMCrTagWYHQvTBGawSE7FIrH2TcT3vmSrUlTvP9hTgs0w67dAkTumG1KW
# 6m9M9MpEgcit4oGTXFqerdlho+FjpIl6hrh/aa/Ud42vTpvPRVsBreic3XzBhexC
# 4mtn3V9smr4doMJUEC+84WALC4Sij+do3CTDGJX3XhgdklN6zkZCUkpukMKankyW
# DsKJIMyDA+McRFsuBgeShiHwhrOLBbt72Fa0FZtmknSldvQm4yUJYNqmzf7H4vz6
# 6jtW90r+Q+4O0GxQ2cmPDRH4VhRRc4OzhoA5LKiRMqI06szx0xeciD204yyRfDva
# xqirJa2MBgKZga+m/EwEaf93PGLirwq4svRLNoXlfbRKYw02wMHksa/maVmUg1j+
# XTrGXjczhEgNOyuupbuyfcPOSrjrqN+7mYoRK0VCRTmfMf92X6MbTr+DbSCHnfsu
# fDQHbsusCb5BPO2RPin7/SmgCGEDwCH8hb2w9d58ssg48WxXvKCGZdToqlK5spuA
# onP2uWtQfGN0vVSxMCDYxk8m6tU=
# SIG # End signature block
