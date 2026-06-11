# OneView information



$secpasswd = read-host  "Please enter the OneView password" -AsSecureString
# Connection to the Synergy Composer
#$credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)
#Connect-OVMgmt -Hostname $IP -Credential $credentials | Out-Null
 
$Creds = Get-Credential
Connect-OVMgmt -Hostname $IP -Credential $Creds -AuthLoginDomain "Domain"
 
 
# Capture iLO5 IP adresses managed by OneView
$computes = Get-OVServer | where mpModel -eq iLO5
# $computes = Get-OVServer | where serialNumber -eq CZ3508PYS5
 
 
clear
 
if ($computes)
{
    write-host ""
    Write-host $computes.Count "iLO5 can support REST API commands and will be configured with password complexity to enable:" 
    $computes | Format-Table -autosize | Out-Host
 
} else
{
    Write-Warning "No iLO5 server found ! Exiting... !"
    Disconnect-OVMgmt
    exit
}
 
 
# Capture iLO Administrator account password
$Defaultadmpassword = "password"
$secuadmpassword = Read-Host "Please enter the password you want to assign to all iLos for the user Administrator [$($Defaultadmpassword)]" -AsSecureString
 
$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secuadmpassword)
$admpassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
 
$admpassword = ($Defaultadmpassword, $admpassword)[[bool]$admpassword]
 
#Creation of the body content to pass to iLO
$bodyiloParams = @{Password = $admpassword } | ConvertTo-Json
 
# Added these lines to avoid the error: "The underlying connection was closed: Could not establish trust relationship for the SSL/TLS secure channel."
# due to an invalid Remote Certificate
add-type -TypeDefinition  @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
           public bool CheckValidationResult(
                ServicePoint srvPoint, X509Certificate certificate,
                WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
 
#####################################################################################################################
 
Foreach ($compute in $computes)
{
 
    # Capture of the SSO Session Key
    $iloSession = $compute | Get-OVIloSso -IloRestSession
    $ilosessionkey = $iloSession."X-Auth-Token"
 
    $iloIP = $compute.mpHostInfo.mpIpAddresses | ? type -ne LinkLocal | % address
    # Creation of the header using the SSO Session Key 
    $headerilo = @{ } 
    $headerilo["X-Auth-Token"] = $ilosessionkey
 
 
    
    # Modification of the Administrator password
    try
    {
        $response = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/accountservice/accounts/1/" -Body $bodyiloParams -ContentType "application/json" -Headers $headerilo -Method PATCH -UseBasicParsing -ErrorAction Stop
        $msg = ($response.Content | ConvertFrom-Json).error.'@Message.ExtendedInfo'.MessageId
        Write-Host "Administrator password has been changed in iLO $iloIP, message returned: [$($msg)]"
 
    } catch
    {
        $err = (New-Object System.IO.StreamReader( $_.Exception.Response.GetResponseStream() )).ReadToEnd() 
        $msg = ($err | ConvertFrom-Json ).error.'@Message.ExtendedInfo'.MessageId
        Write-Host -BackgroundColor:Black -ForegroundColor:Red "iLO $($iloIP): Error ! Password cannot be changed ! Message returned: [$($msg)]"
        continue
    }
}
 
write-host ""
Read-Host -Prompt "Operation done ! Hit return to close" 
Disconnect-OVMgmt
