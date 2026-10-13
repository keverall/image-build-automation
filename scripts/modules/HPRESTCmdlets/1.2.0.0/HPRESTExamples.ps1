<#
(c) Copyright 2015-2017 Hewlett Packard Enterprise Development LP

Licensed under the Apache License, Version 2.0 (the "License");
You may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License. 




These examples use HPE REST PowerShell cmdlets available at http://www.powershellgallery.com/packages/HPRESTCmdlets/.  
These scripts provide examples of using HPE RESTful API on HPE iLO for common use cases.

These examples use the following base set of cmdlets:

Connect-HPREST
Disconnect-HPREST
Edit-HPRESTData
Find-HPREST
Format-HPRESTDir
Get-HPRESTData
Get-HPRESTDataRaw
Get-HPRESTDir
Get-HPRESTMessage
Get-HPRESTHttpData
Get-HPRESTIndex
Get-HPRESTSchema
Get-HPRESTSchemaExtref
Get-HPRESTUriFromHref
Invoke-HPRESTAction
Remove-HPRESTData
Set-HPRESTData

#>


 
#iLO IP address and credentials to access the iLO
$Address = '10.20.30.1'
$cred = Get-Credential

function Set-BIOSExample1
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential,

        [System.String]
        $BIOSProperty,

        [System.String]
        $Value
    )

    Write-Host 'Example 1: Change a BIOS Setting'
    
    #create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication

    #Get list of systems
    $systems = Get-HPRESTDataRaw -Href 'rest/v1/systems' -Session $session
    foreach($sys in $systems.links.member.href) # rest/v1/systems/1, rest/v1/system/2
    {
        #Get BIOS URI from system data
        $data = Get-HPRESTDataRaw -Href $sys -Session $session
        $biosURI = $data.Oem.Hp.links.BIOS.href
    
        #get BIOS Data
        $biosData = Get-HPRESTDataRaw -Href $biosURI -Session $session

        #if property to be modified is not present in the bios data, then print error message and return
        if(-not(($biosData|Get-Member).Name -contains $BIOSProperty))
        {
            Write-Host "Property $BIOSProperty is not supported on this system"
        }
        else
        {
            #Get setting href to update bios property. For bios, property can be updated in the settings href only. Other data may or may not have setting href

            #creating setting object
            $biosSetting = @{}
            $biosSetting.Add($BIOSProperty,$Value)
            
            #updating setting in system bios settings
            $ret = Set-HPRESTData -Href $biosURI -Setting $biosSetting -Session $session
        
            # processing message obtained by executing Set- cmdlet
            if($ret.Messages.Count -gt 0)
            {
                foreach($msgID in $ret.Messages)
                {
                    $status = Get-HPRESTError -MessageID $msgID.MessageID -MessageArg $msgID.MessageArgs -Session $session
                    $status
                }
            }
        }
    }

    # disconnecting the session after use
    Disconnect-HPREST -Session $session
}
#Set-BIOSExample1 -Address $Address -Credential $cred -BIOSProperty 'AdminName' -Value 'test admin'

function Reset-ServerExample2
{
param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential,

        [System.String]
        $Action,

        [System.String]
        $PropertyName,

        [System.String]
        $PropertyValue
    )

    Write-Host 'Example 2: Reset the server.'
    
    #create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication

    # getting system list
    $systems = Get-HPRESTDataRaw -Href 'rest/v1/systems' -Session $session
    foreach($sys in $systems.links.member.href) # rest/v1/systems/1, rest/v1/system/2
    {
        # creating setting object to invoke reset action. 
        # Details of invoking reset (or other possible actions) is present in 'AvailableActions' of system data  
        $dataToPost = @{}
        $dataToPost.Add('Action',$Action)
        $dataToPost.Add($PropertyName,$PropertyValue)
        
        # Sending reset request to system using 'POST' in Invoke-HPRESTAction
        $ret = Invoke-HPRESTAction -Href $sys -Data $dataToPost -Session $session

        # processing message obtained by executing Set- cmdlet
        if($ret.Messages.Count -gt 0)
        {
            foreach($msgID in $ret.Messages)
            {
                $status = Get-HPRESTError -MessageID $msgID.MessageID -MessageArg $msgID.MessageArgs -Session $session
                $status
            }
        }
    }

    # disconnect the session after use
    Disconnect-HPREST -Session $session
}
#Reset-ServerExample2 -Address $Address -Credential $cred -Action Reset -PropertyName ResetType -PropertyValue ForceRestart

function Set-SecureBootExample3
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential,

        [System.String]
        $SecureBootProperty, # schema allows changing values for SecureBootEnable, ResetToDefaultKeys, ResetAllKeys

        [Boolean]
        $Value #value must be a boolean i.e. $true or $false
    )

    Write-Host 'Example 3: Enable/Disable UEFI secure boot'
    
    #create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication

    $systems = Get-HPRESTDataRaw -Href 'rest/v1/systems' -Session $session
    foreach($sys in $systems.links.member.href) # rest/v1/systems/1, rest/v1/system/2
    {
        #Get secure boot URI
        $sysData = Get-HPRESTDataRaw -Href $sys -Session $session
        $secureBootURI = $sysData.Oem.Hp.links.SecureBoot.href
    
        #get secure boot data and display original value
        $secureBootData = Get-HPRESTDataRaw -Href $secureBootURI -Session $session
        $secureBootData

        #if property to be modified is not present in the secure boot data, then print error message and return
        if(-not(($secureBootData|Get-Member).Name -Contains $SecureBootProperty))
        {
            Write-Host "Property $SecureBootProperty is not supported on this system"
        }
        else
        {
            # use Set cmdlet at Secure Boot href to update secure boot property. Here only boolean values are allowed for Value parameter
            # creating hashtable object with property and value
            $secureBootSetting = @{$SecureBootProperty=$Value}
            
            # Execute Set- cmdlet to post enable/disable setting at href for secure boot
            $ret = Set-HPRESTData -Href $secureBootURI -Setting $SecureBootSetting -Session $session
            
            # processing message obtained by executing Set- cmdlet
            if($ret.Messages.Count -gt 0)
            {
                foreach($msgID in $ret.Messages)
                {
                    $status = Get-HPRESTError -MessageID $msgID.MessageID -MessageArg $msgID.MessageArgs -Session $session
                    $status
                }
            }

            # get and display updated value of the property
            $secureBootData = Get-HPRESTDataRaw -Href $secureBootURI -Session $session
            $secureBootData        
        }
    }

    # disconnect the session after use
    Disconnect-HPREST -Session $session
}
#Set-SecureBootExample3 -Address $Address -Credential $cred -SecureBootProperty 'SecureBootEnable' -Value $true
  
function Set-BIOSDefaultExample4
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential,

        [System.Object]
        $InitializationSetting
    )

    Write-Host 'Example 4: Set default BIOS settings'
    
    #create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication

    $systems = Get-HPRESTDataRaw -Href 'rest/v1/systems' -Session $session
    foreach($sys in $systems.links.member.href) # rest/v1/systems/1, rest/v1/system/2
    {
        #Get BIOS URI
        $sysData = Get-HPRESTDataRaw -Href $sys -Session $session
        $biosURI = $sysData.Oem.Hp.links.BIOS.href
    
        #get BIOS Data and obtain the setting href from it
        $biosData = Get-HPRESTDataRaw -Href $biosURI -Session $session
        $biosSettingURI = $biosData.links.settings.href
        
        # use BIOS setting URI to obtain setting data
        $biosSettingData = Get-HPRESTDataRaw -Href $biosSettingURI -Session $session

        # create bios setting object
        $newBiosSetting=@{}
        $newBiosSetting.Add('BaseConfig','Default')

        # preserve the Type property from the existing BIOS settings to avoid error
        $newBiosSetting.Add('Type',$biosSettingData.Type)
        
        # add other optional initialization settings provided by the user
        if(-not ($InitializationSetting -eq '' -or $InitializationSetting -eq $null))
        {
            if($InitializationSetting.GetType().ToString() -eq 'System.Management.Automation.PSCustomObject')
            {
                foreach($prop in $InitializationSetting.PSObject.Properties)
                {
                    $newBiosSetting.Add($prop.Name,$prop.Value)
                }
            }
            elseif($InitializationSetting.GetType().ToString() -eq 'System.Collections.Hashtable')
            {
                foreach($ky in $InitializationSetting.Keys)
                {
                    $newBiosSetting.Add($ky,$InitializationSetting[$ky])
                }
            }
            else
            {
                Write-Host 'Invalid input type for InitializationSetting parameter. Use PSObject or PowerShell Hashtable' -ForegroundColor red
            }
        }

        # execure HTTP PUT command using Edit-HPRESTData cmdlet to set BIOS default settings
        $ret = Edit-HPRESTData -Href $biosSettingURI -Setting $newBiosSetting -Session $session
        
        # process returned message from Edit-HPRESTData cmdlet
        if($ret.Messages.Count -gt 0)
        {
            foreach($msgID in $ret.Messages)
            {
                $status = Get-HPRESTError -MessageID $msgID.MessageID -MessageArg $msgID.MessageArgs -Session $session
                $status
            }
        }
    }

    # disconnect the session after use
    Disconnect-HPREST -Session $session
}
<#
Set-BIOSDefaultExample4 -Address $Address -Credential $cred
## reset makes the BIOS property change effective
Reset-ServerExample2 -Address $Address -Credential $cred -Action Reset -PropertyName ResetType -PropertyValue ForceRestart
#>

function Set-BootOrderExample5
{
# Changes the boot order by swapping the first two boot options in the persistant boot order list
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential
    )

    Write-Host 'Example 5: Set boot order (UEFI)'
    
    #create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication

    $systems = Get-HPRESTDataRaw -Href 'rest/v1/systems' -Session $session
    foreach($sys in $systems.links.member.href) # rest/v1/systems/1, rest/v1/system/2
    {
        #Get BIOS URI
        $sysData = Get-HPRESTDataRaw -Href $sys -Session $session
        $biosURI = $sysData.Oem.Hp.links.BIOS.href
    
        #get BIOS Data
        $biosData = Get-HPRESTDataRaw -Href $biosURI -Session $session
    
        $bootURI = $biosData.links.Boot.href
        $bootData = Get-HPRESTDataRaw -Href $bootURI -Session $session
        $bootData.PersistentBootConfigOrder

        #if property to be modified is not present in the bios data, then print error message and return
        if(-not(($bootData|Get-Member).Name.Contains('PersistentBootConfigOrder')))
        {
            Write-Host 'Property PersistentBootConfigOrder is not supported on this system'
        }
        else
        {
            # changing boot order by interchanging first and second items in the list. Other orders can also be used 
            $bootOrder = $bootData.PersistentBootConfigOrder # |ConvertFrom-Json
            $temp = $bootOrder[0]
            $bootorder[0] = $bootOrder[1]
            $bootOrder[1] = $temp

            # Getting the href location where the order change has to be 'PATCHed'
            $bootSettingURI = $bootData.links.settings.href
            
            # create object to PATCH
            $persistentBootConfig = @{'PersistentBootConfigOrder'=$bootOrder}

            # execute HTTP PATCH operation using Set-HPRESTData cmdlet
            $ret = Set-HPRESTData -Href $bootSettingURI -Setting $persistentBootConfig -Session $session
            
            # process returned message from Set-HPRESTData cmdlet
            if($ret.Messages.Count -gt 0)
            {
                foreach($msgID in $ret.Messages)
                {
                    $status = Get-HPRESTError -MessageID $msgID.MessageID -MessageArg $msgID.MessageArgs -Session $session
                    $status
                }
            }
        }
    }

    # disconnect the session after use
    Disconnect-HPREST -Session $session
}
<#
#---------------------------------------------------------------------------------------------#

## change boot order. Internally the example swaps first and second boot targets.
Set-BootOrderExample5 -Address $Address -Credential $cred
##reset maked the boot order effective
Reset-ServerExample2 -Address $Address -Credential $cred -Action Reset -PropertyName ResetType -PropertyValue ForceRestart

#### wait for server to reboot and POST. (Change sleep time as required)
Start-Sleep -Seconds 300

## change boot order to original by swapping back the first two boot targets
Set-BootOrderExample5 -Address $Address -Credential $cred
##reset makes the boot order effective
Reset-ServerExample2 -Address $Address -Credential $cred -Action Reset -PropertyName ResetType -PropertyValue ForceRestart
#---------------------------------------------------------------------------------------------#
#>

function Set-TempBootOrderExample6
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential,

        [System.String]
        $BootTarget
    )

    Write-Host 'Example 6: Set one-time(temporary)boot order'
    
    #create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication

    #Get system list
    $systems = Get-HPRESTDataRaw -Href 'rest/v1/systems' -Session $session
    foreach($sys in $systems.links.member.href) # rest/v1/systems/1, rest/v1/system/2
    {
        # get boot data for the system
        $data = Get-HPRESTDataRaw -Href $sys -Session $session
        $data.Boot

        # print available boot targets
        Write-Host 'Supported boot targets are' $data.boot.BootSourceOverrideSupported
        
        if(-not($data.Boot.BootSourceOverrideSupported  -Contains $BootTarget))
        {
            # if user provided not supported then print error
            Write-Host "$BootTarget not supported"
        }
        else
        {
            # create object to PATCH
            $tempBoot = @{'BootSourceOverrideTarget'=$BootTarget}
            $OneTimeBoot = @{'Boot'=$tempBoot}

            # PATCH the data using Set-HPRESTData cmdlet
            $ret = Set-HPRESTData -Href $sys -Setting $OneTimeBoot -Session $session
            
            #process message returned by Set-HPRESTData cmdlet
            if($ret.Messages.Count -gt 0)
            {
                foreach($msgID in $ret.Messages)
                {
                    $status = Get-HPRESTError -MessageID $msgID.MessageID -MessageArg $msgID.MessageArgs -Session $session
                    $status
                }
            }

            #get and print updated value
            $bootData = Get-HPRESTDataRaw -Href $sys -Session $session
            $bootData.Boot    
        }
    }

    # disconnect the session after use
    Disconnect-HPREST -Session $session
}
## NOTE: check the boot targets supported in BootSourceOverrideSupported $data.Boot.BootSourceOverrideSupported. The value is case sensitive. 
## E.g. Pxe will work, pxe will not
#Set-TempBootOrderExample6 -Address $Address -Credential $cred -BootTarget 'Hdd'

function Get-iLOMACAddressExample7
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential
    )

    Write-Host "Example 7: Find iLO's MAC addresses"
    
    #create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication

    $mgr = Get-HPRESTDataRaw -Href 'rest/v1/managers' -Session $session
    foreach($hrefVal in $mgr.links.member.href) # rest/v1/systems/1, rest/v1/system/2
    {
        #Get manager data
        $managerData = Get-HPRESTDataRaw -Href $hrefVal -Session $session
        
        # retrieve ethernet NIC details
        $nicURI = $managerData.links.EthernetNICs.href
        $nicData = Get-HPRESTDataRaw -Href $nicURI -Session $session

        foreach($nic in $nicData.items)
        {
            Write-Host $managerData.Model - $nic.Name - $nic.MacAddress 
        }
    }

    # disconnect session after use
    Disconnect-HPREST -Session $session
}
#Get-iLOMACAddressExample7 -Address $Address -Credential $cred

function Add-iLOUserAccountExample8
{
# NOTE: '(400) Bad Request' error will be thrown if the user already exists
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential,

        [System.String]
        $newiLOLoginName,

        [System.String]
        $newiLOUserName,

        [System.String]
        $newiLOPassword,

        [Boolean]
        $RemoteConsolePriv = $false,

        [Boolean]
        $ConfigPriv = $false,

        [Boolean]
        $VirtualMediaPriv = $false,

        [Boolean]
        $UserConfigPriv = $false,

        [Boolean]
        $VirtualPowerResetPriv = $false
    )

    Write-Host 'Example 8: Create an iLO user account.'

    #create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication

    # Get AccountService data to obtain Accounts href
    $accData = Get-HPRESTDataRaw -Href 'rest/v1/AccountService' -Session $session
    $accURI = $accData.links.Accounts.href

    # create iLO user object
    # add permissions
    $priv = @{}
    $priv.Add('RemoteConsolePriv',$RemoteConsolePriv)
    $priv.Add('iLOConfigPriv',$ConfigPriv)
    $priv.Add('VirtualMediaPriv',$VirtualMediaPriv)
    $priv.Add('UserConfigPriv',$UserConfigPriv)
    $priv.Add('VirtualPowerAndResetPriv',$VirtualPowerResetPriv)

    # add login name
    $hp = @{}
    $hp.Add('LoginName',$newiLOLoginName)
    $hp.Add('Privileges',$priv)
    
    $oem = @{}
    $oem.Add('Hp',$hp)

    # add username and password for access
    $user = @{}
    $user.Add('UserName',$newiLOUserName)
    $user.Add('Password',$newiLOPassword)
    $user.Add('Oem',$oem)

    # execute HTTP POST method using Invoke-HPRESTAction to add user data at Accounts href
    $ret = Invoke-HPRESTAction -Href $accURI -Data $user -Session $session
    
    # process messages returned by Invoke-HPRESTAction cmdlet
    if($ret.Messages.Count -gt 0)
    {
        foreach($msgID in $ret.Messages)
        {
            $status = Get-HPRESTError -MessageID $msgID.MessageID -MessageArg $msgID.MessageArgs -Session $session
            $status
        }
    }
    
    # Print the list of users. New user will be in this list
    $accData = Get-HPRESTDataRaw -Href $accData.links.Accounts.href -Session $session
    $accData.Items

    # disconnect session after use
    Disconnect-HPREST -Session $session
}
#Add-iLOUserAccountExample8 -Address $Address -Credential $cred -newiLOLoginName 'timh' -newiLOUserName 'TimHorton' -newiLOPassword 'timPassword123' -RemoteConsolePriv $true

function Set-iLOUserAccountExample9
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential,

        [System.String]
        $LoginNameToModify,

        [System.String]
        $newLoginName = '',

        [System.String]
        $newUsername = '',

        [System.String]
        $newPassword = '',

        [System.Object]
        $RemoteConsolePriv = $null,

        [System.Object]
        $ConfigPriv = $null,

        [System.Object]
        $VirtualMediaPriv = $null,

        [System.Object]
        $UserConfigPriv = $null,

        [System.Object]
        $VirtualPowerResetPriv = $null
    )

    Write-Host 'Example 9: Modify an iLO user account.'

    #create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication

    # get the href of the iLO user accounts
    $accData = Get-HPRESTDataRaw -Href 'rest/v1/AccountService' -Session $session
    $accURI = $accData.links.Accounts.href

    $members = Get-HPRESTDataRaw -Href $accURI -Session $session
    $foundFlag = $false
    $memberURI = ''
    $user = $null

    foreach($member in $members.Items)
    {
        # check if user is present in the user list
        if($member.Username -eq $LoginNameToModify)
        {
            $foundFlag = $true
            $memberURI = $member.links.self.href
            
            # Create user object with new value(s)
            $priv = @{}
            if($RemoteConsolePriv -ne $null){$priv.Add('RemoteConsolePriv',[System.Convert]::ToBoolean($RemoteConsolePriv))}
            if($ConfigPriv -ne $null){$priv.Add('iLOConfigPriv',[System.Convert]::ToBoolean($ConfigPriv))}
            if($VirtualMediaPriv -ne $null){$priv.Add('VirtualMediaPriv',[System.Convert]::ToBoolean($VirtualMediaPriv))}
            if($UserConfigPriv -ne $null){$priv.Add('UserConfigPriv',[System.Convert]::ToBoolean($UserConfigPriv))}
            if($VirtualPowerResetPriv -ne $null){$priv.Add('VirtualPowerAndResetPriv',[System.Convert]::ToBoolean($VirtualPowerResetPriv))}

            $hp = @{}
            if($newLoginName -ne ''){$hp.Add('LoginName',$newLoginName)}
            if($priv.Count -gt 0){$hp.Add('Privileges',$priv)}
    
            $oem = @{}
            if($hp.Count -gt 0){$oem.Add('Hp',$hp)}

            $user = @{}
            if($newUserName -ne ''){$user.Add('UserName',$newUserName)}
            if($newPassword -ne ''){$user.Add('Password',$newPassword)}
            if($oem.Count -gt 0){$user.Add('Oem',$oem)}
            break
        }
    }
    if($foundFlag -eq $true)
    {
        # WARNING: If you don't change anything, you will get an HTTP 400 back 
        # PATCH the data using Set-HPRESTData
        $ret = Set-HPRESTData -Href $memberURI -Setting $user -Session $session
        if($ret.Messages.Count -gt 0)
        {
            foreach($msgID in $ret.Messages)
            {
                $status = Get-HPRESTError -MessageID $msgID.MessageID -MessageArg $msgID.MessageArgs -Session $session
                $status
            }
        }
    }
    # If user name is not found, print message
    else
    {
        Write-Error "$LoginNameToModify not present"
    }

    # Disconnect session after use
    Disconnect-HPREST -Session $session
}
#Set-iLOUserAccountExample9 -Address $Address -Credential $cred -LoginNameToModify 'TimHorton' -RemoteConsolePriv $false

function Remove-iLOUserAccountExample10
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential,

        [System.String]
        $LoginNameToRemove
    )

    Write-Host 'Example 10: Delete an iLO user account.'

    #create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication

    $accData = Get-HPRESTDataRaw -Href 'rest/v1/AccountService' -Session $session
    $accURI = $accData.links.Accounts.href

    $members = Get-HPRESTDataRaw -Href $accURI -Session $session
    $foundFlag = $false
    $memberURI = ''
    foreach($member in $members.Items)
    {
        # If user to delete is found in user list, note the href of that user in memberURI variable
        if($member.Username -eq $LoginNameToRemove)
        {
            $foundFlag = $true
            $memberURI = $member.links.self.href            
            break
        }
    }
    if($foundFlag -eq $true)
    {
        # If the user was found, executet the HTTP DELETE method on the href of the user to be deleted.
        $ret = Remove-HPRESTData -Href $memberURI -Session $session
        
        # process message(s) from Remove-HPRESTData cmdlet
        if($ret.Messages.Count -gt 0)
        {
            foreach($msgID in $ret.Messages)
            {
                $status = Get-HPRESTError -MessageID $msgID.MessageID -MessageArg $msgID.MessageArgs -Session $session
                $status
            }
        }

        # print list of users. Deleted user will not be present in the list
        $accData = Get-HPRESTDataRaw -Href $accData.links.Accounts.href -Session $session
        $accData.Items
    }
    else
    {
        Write-Error "$LoginNameToRemove not present"
    }

    # Disconnect session after use
    Disconnect-HPREST -Session $session
}
#Remove-iLOUserAccountExample10 -Address $Address -Credential $cred -LoginNameToRemove TimHorton

function Get-ActiveiLONICExample11
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential
    )
    Write-Host 'Example 11: Retrieve active iLO NIC information'

    # create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication
    
    # retrieve manager list
    $managers = Get-HPRESTDataRaw -Href 'rest/v1/Managers' -Session $session
    foreach($manager in $managers.links.Member.href)
    {
        # retrieve manager details and the ethernetNIC href from that
        $managerData = Get-HPRESTDataRaw -Href $manager -Session $session
        $nicURI = $managerData.links.EthernetNICs.href

        # retrieve all NIC information
        $nics = Get-HPRESTDataRaw -Href $nicURI -Session $session

        # print NIC details for enabled i.e. active NIC
        foreach($nic in $nics.items)
        {
            if($nic.Status.State -eq 'Enabled')
            {
                $nic
            }
        }
    }

    # Disconnect session after use
    Disconnect-HPREST -Session $session
}
#Get-ActiveiLONICExample11 -Address $Address -Credential $cred

function Get-SessionExample12
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential
    )
    Write-Host 'Example 12: Retrieve current session information'

    # connect session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication

    # retrieve all sessions
    $sessions = Get-HPRESTDataRaw -Href 'rest/v1/Sessions' -Session $session
    
    #get the details of current session
    foreach($ses in $sessions.Items)
    {
        if($ses.Oem.Hp.MySession -eq $true)
        {
            $ses
            $ses.oem.hp
        }
    }

    # disconnect session after use
    Disconnect-HPREST -Session $session
}
#Get-SessionExample12 -Address $Address -Credential $cred

function Set-UIDStateExample13
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential,

        [ValidateSet('Lit','Off')]
        [System.String]
        $UIDState # Use 'Lit' or 'Off'. Value identified by 'IndicatorLED' field in 'rest/v1/Systems/1'. The value 'Blinking' in mentioned in the schema is not settable by the user.
    )

    Write-Host 'Example 13: Change UID/IndicatorLED status'

    # connect session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication
    
    # retrieve list of systems
    $systems = Get-HPRESTDataRaw -Href 'rest/v1/Systems' -Session $session
    foreach($sys in $systems.links.Member.href)
    {
        # get the href of the system to PATCH the Indicator LED value
        $sysData = Get-HPRESTDataRaw -Href $sys -Session $session
        $sysURI = $sysData.links.self.href

        # create hashtable object to PATCH
        $UIDSetting = @{'IndicatorLED'=$UIDState}

        # PATCH the data using Set-HPRESTData cmdlet
        $ret = Set-HPRESTData -Href $sysURI -Setting $UIDSetting -Session $session

        # process the message(s) from Set-HPRESTData
        if($ret.Messages.Count -gt 0)
        {
            foreach($msgID in $ret.Messages)
            {
                $status = Get-HPRESTError -MessageID $msgID.MessageID -MessageArg $msgID.MessageArgs -Session $session
                $status
            }
        }
    }

    # Disconnect the session after use
    Disconnect-HPREST -Session $session
}
## NOTE: UID State - Unknown, Lit, Blinking, Off. Unknown and Blinking cannot be set by user
#Set-UIDStateExample13 -Address $Address -Credential $cred -UIDState 'Off'

function Get-ComputerSystemExample14
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential
    )
    Write-Host 'Example 14: Retrieve information of computer systems'

    # connect session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication
    
    # retrieve list of computer systems
    $systems = Get-HPRESTDataRaw -Href 'rest/v1/Systems' -Session $session

    # print details of all computer systems
    foreach($sys in $systems.links.Member.href)
    {
        $sysData = Get-HPRESTDataRaw -Href $sys -Session $session
        $sysData
    }

    # Disconnect session after use
    Disconnect-HPREST -Session $session    
}
#Get-ComputerSystemExample14 -Address $Address -Credential $cred

function Set-VirutalMediaExample15
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential,

        [System.Object]
        $IsoUrl = $null,

        [System.Object]
        $BootOnNextReset = $null
    )

    # NOTE: if ISO URL is blank and BootOnNextReset are blank/null, the virtual media is unmounted
    Write-Host 'Example 15 : Mount/Unmount virtual media DVD using URL'

    # Connect session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication

    $managers = Get-HPRESTDataRaw -Href 'rest/v1/Managers' -Session $session
    foreach($mgr in $managers.links.Member.href)
    {
        
        $mgrData = Get-HPRESTDataRaw -Href $mgr -Session $session
        # Check if virtual media is supported
        if($mgrData.links.PSObject.Properties.name -Contains 'VirtualMedia' -eq $false)
        {
            # If virtual media is not present in links under manager details, print error
            Write-Host 'Virtual media not available in Manager links'
        }
        else
        {
            
            $vmhref = $mgrData.links.VirtualMedia.href
            $vmdata = Get-HPRESTDataRaw -Href $vmhref -Session $session
            foreach($vm in $vmdata.links.Member.href)
            {
                $data = Get-HPRESTDataRaw -Href $vm -Session $session
                # select the media option which contains DVD
                if($data.MediaTypes -contains 'DVD')
                {
                    # Create object to PATCH to update ISO image URI and to set
                    if($IsoUrl -eq $null)
                    {
                        $mountSetting = @{'Image'=$null}
                    }
                    else
                    {
                        $mountSetting = @{'Image'=[System.Convert]::ToString($IsoUrl)}
                    }
                    if($BootOnNextReset -ne $null -and $IsoUrl -ne $null)
                    {
                        # Create object to PATCH 
                        $oem = @{'Hp'=@{'BootOnNextServerReset'=[System.Convert]::ToBoolean($BootOnNextReset)}}
                        $mountSetting.Add('Oem',$oem)
                    }
                    # PATCH the data to $vm href by using Set-HPRESTData
                    #Disconnect-HPREST -Session $session
                    $ret = Set-HPRESTData -Href $vm -Setting $mountSetting -Session $session
                    
                    # Process message(s) returned from Set-HPRESTData
                    if($ret.Messages.Count -gt 0)
                    {
                        foreach($msgID in $ret.Messages)
                        {
                            $status = Get-HPRESTError -MessageID $msgID.MessageID -MessageArg $msgID.MessageArgs -Session $session
                            $status
                        }
                    }
                    Get-HPRESTDataRaw -Href $vm -Session $session
                }
            }        
        }
    }
    # Disconnect session after use
    Disconnect-HPREST -Session $session
}
<#
# will return '(400) Bad Request' error if the virtual media is already in this state.
# IsoUrl = $null will dismount the virtual media. IsoUrl = '' will give 400 Bad Request error.

#unmount
Set-VirutalMediaExample15 -Address $Address -Credential $cred -IsoUrl $null -BootOnNextReset $false

#Mount
Set-VirutalMediaExample15 -Address $Address -Credential $cred -IsoUrl 'http://10.20.30.1/iso/Windows/Win2012/en_windows_server_2012_vl_x64_dvd_917758.iso' -BootOnNextReset $true

#unmount
Set-VirutalMediaExample15 -Address $Address -Credential $cred
#>

function Set-AssetTagExample16
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential,

        [System.String]
        $AssetTag
    )
    Write-Host 'Example 16: Update AssetTag value.'

    # Connect sesion
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication
    
    # Retrieve list of systems
    $systems = Get-HPRESTDataRaw -Href 'rest/v1/Systems' -Session $session
    foreach($sys in $systems.links.Member.href)
    {
        # Get each system href by first retrieving each system data and then extracting 'Self' href from it
        $sysData = Get-HPRESTDataRaw -Href $sys -Session $session
        $sysURI = $sysData.links.self.href

        # Create hashtable object to PATCH to system href
        $assetTagSetting = @{'AssetTag'='Test111'}
        # PATCH data using Set-HPRESTData cmdlet
        $ret = Set-HPRESTData -Href $sysURI -Setting $assetTagSetting -Session $session

        # Process message(s) from Set-HPRESTData
        if($ret.Messages.Count -gt 0)
        {
            foreach($msgID in $ret.Messages)
            {
                $status = Get-HPRESTError -MessageID $msgID.MessageID -MessageArg $msgID.MessageArgs -Session $session
                $status
            }
        }
    }
    # Disconnect session after use
    Disconnect-HPREST -Session $session
}
#Set-AssetTagExample16 -Address $Address -Credential $cred -AssetTag 'Test2'

function Reset-iLOExample17
{
param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential
    )

    Write-Host 'Example 17: Reset the iLO.'
    
    #create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication

    # Get list of managers
    $managers = Get-HPRESTDataRaw -Href 'rest/v1/Managers' -Session $session
    foreach($mgr in $managers.links.member.href) # rest/v1/managers/1, rest/v1/managers/2
    {
        # for possible operations on the manager check 'AvailableActions' field in manager data
        # Create hashtable object according to 'AvailableActions' to send to manager href 
        $dataToPost = @{}
        $dataToPost.Add('Action','Reset')

        # Send POST request using Invoke-HPRESTAction
        Invoke-HPRESTAction -Href $mgr -Data $dataToPost -Session $session
        # resetting iLO will delete all active sessions.

    }
    #automatically closes all connections
    #Disconnect-HPREST -Session $session
}
#Reset-iLOExample17 -Address $Address -Credential $cred

function Get-iLONICExample18
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential,

        [ValidateSet('Active','Inactive','All')]
        [System.String]
        $NICState = 'Active'
    )
    Write-Host 'Example 18: Retrieve iLO NIC information'

    # Create Session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication
    
    # Retrieve list of managers
    $managers = Get-HPRESTDataRaw -Href 'rest/v1/Managers' -Session $session
    foreach($manager in $managers.links.Member.href)
    {
        # Retrieve manager data to extract Ethernet NIC href
        $managerData = Get-HPRESTDataRaw -Href $manager -Session $session
        $nicURI = $managerData.links.EthernetNICs.href

        # Retrieve ethernet NIC details
        $nics = Get-HPRESTDataRaw -Href $nicURI -Session $session

        # Display NIC accoring to the NICState parameter
        foreach($nic in $nics.items)
        {
            if($nic.Status.State -eq 'Enabled')
            {
                if($NICState -eq 'Active')
                {
                    $nic
                    break
                }
                if($NICState -eq 'All')
                {
                    $nic
                }
            }
            if($nic.Status.State -eq 'Disabled')
            {
                if($NICState -eq 'Inactive')
                {
                    $nic
                    break
                }
                if($NICState -eq 'All')
                {
                    $nic
                }
            }
        }
    }
    # Disconnect the session after use
    Disconnect-HPREST -Session $session
}
#Get-iLONICExample18 -Address $Address -Credential $cred -NICState Inactive

function Set-ActiveiLONICExample19
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential,

        [Boolean]
        $SharedNIC = $false
    )
    Write-Host 'Example 19: Set the active iLO NIC'

    # Create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication
    
    # Retrieve list of managers
    $managers = Get-HPRESTDataRaw -Href 'rest/v1/Managers' -Session $session
    foreach($manager in $managers.links.Member.href)
    {
        
        $managerData = Get-HPRESTDataRaw -Href $manager -Session $session
        $nicHref = $managerData.links.EthernetNICs.href
        $nics = Get-HPRESTDataRaw -Href $nicHref -Session $session
        $selectedNICHref = ''
        foreach($nic in $nics.items)
        {
            if($SharedNIC -eq $true)
            {
                # if a shared NIC setting is required, then check for LOM or Flexible LOM select URI where LOM/FlexLOM is present
                if($nic.Oem.hp.SupportsFlexibleLOM -eq $null -and $nic.Oem.hp.SupportsLOM -eq $null)
                {
                    continue;
                }
                else
                {
                    if($nic.Oem.hp.SupportsFlexibleLOM -eq $true)
                    {
                        $selectedNICHref = $nic.links.self.href
                        break
                    }
                    elseif($nic.Oem.hp.SupportsLOM -eq $true)
                    {
                        $selectedNICHref = $nic.links.self.href
                        break
                    }
                    else
                    {
                        Write-Host 'Shared NIC not supported.'
                    }
                }
            }
            else #if sharedNic set to false, select the Href of NIC where LOM/FlexLOM are not present
            {
                if($nic.Oem.hp.SupportsFlexibleLOM -eq $null -and $nic.Oem.hp.SupportsLOM -eq $null)
                {
                    $selectedNICHref = $nic.links.self.href
                    break
                }
            }
        }

        if($selectedNICHref -ne '')
        {
            $req = @{'Oem'=@{'Hp'=@{'NICEnabled' = $true}}}
            $ret = Set-HPRESTData -Href $selectedNICHref -Setting $req -Session $session

            # Process message(s) returned from Set-HPRESTData cmdlet
            if($ret.Messages.Count -gt 0)
            {
                foreach($msgID in $ret.Messages)
                {
                    $status = Get-HPRESTError -MessageID $msgID.MessageID -MessageArg $msgID.MessageArgs -Session $session
                    $status
                }
            }
        }
    }

    # Disconnect the session after use
    Disconnect-HPREST -Session $session
}
#Set-ActiveiLONICExample19 -Address $Address -Credential $cred

function Get-IMLExample20
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential
    )
    Write-Host 'Example 20: Retrieve Integrated Management Log (IML)'

    # Create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication
    
    # Retrieve systems list
    $systems = Get-HPRESTDataRaw -Href 'rest/v1/systems' -Session $session
    foreach($sys in $systems.links.Member.href)
    {
        # Check if logs are available
        $systemData = Get-HPRESTDataRaw -Href $sys -Session $session
        if($systemData.links.PSObject.properties.name -notcontains 'Logs')
        {
            Write-Host 'Logs not available'
        }
        else
        {
            # Retrieve the IML href
            $logURI = $systemData.links.Logs.href
            $logData = Get-HPRESTDataRaw -Href $logURI -Session $session
            $imlURI = ''
            foreach($link in $logData.links.Member.href)
            {
                $spl = $link.split('`/')
                if($spl[$spl.length-1] -match 'IML')
                {
                    $imlURI = $link
                    break
                }
            }

            # retrieve and display IML log entries
            $imlData = Get-HPRESTDataRaw -Href $imlURI -Session $session
            foreach($entryLink in $imlData.links.Entries)
            {
                $imlEntries = Get-HPRESTDataRaw -Href $entryLink.href -Session $session
                $imlEntries.Items
            }
        }
    }
    # Disconnect the session after use
    Disconnect-HPREST -Session $session
}
#Get-IMLExample20 -Address $Address -Credential $cred

function Get-iLOEventLogExample21
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential
    )
    Write-Host 'Example 21: Retrieve iLO Event Log'

    # Create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication
    $managers = Get-HPRESTDataRaw -Href 'rest/v1/managers' -Session $session
    foreach($mgr in $managers.links.Member.href)
    {
        $managerData = Get-HPRESTDataRaw -Href $mgr -Session $session
        if($managerData.links.PSObject.properties.name -notcontains 'Logs')
        {
            Write-Host 'Logs not available'
        }
        else
        {
            # get the href for iLO event logs
            $logURI = $managerData.links.Logs.href
            $logData = Get-HPRESTDataRaw -Href $logURI -Session $session
            $imlURI = ''
            foreach($link in $logData.links.Member.href)
            {
                $spl = $link.split('`/')
                if($spl[$spl.length-1] -match 'IEL')
                {
                    $ielURI = $link
                    break
                }
            }

            # Retrieve and display the log entries
            $ielData = Get-HPRESTDataRaw -Href $ielURI -Session $session
            foreach($entryLink in $ielData.links.Entries)
            {
                $ielEntries = Get-HPRESTDataRaw -Href $entryLink.href -Session $session
                $ielEntries.Items
            }
        }
    }
    # Disconnect the session after use
    Disconnect-HPREST -Session $session
}
#Get-iLOEventLogExample21 -Address $Address -Credential $cred

function Clear-IMLExample22
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential
    )
    Write-Host 'Example 22: Clear Integrated Management Log'

    # Create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication
    $systems = Get-HPRESTDataRaw -Href 'rest/v1/systems' -Session $session
    foreach($sys in $systems.links.Member.href)
    {
        # check if logs are available or not
        $systemData = Get-HPRESTDataRaw -Href $sys -Session $session
        if($systemData.links.PSObject.properties.name -notcontains 'Logs')
        {
            Write-Host 'Logs not available'
        }
        else
        {
            # extract href href for IML
            $logURI = $systemData.links.Logs.href
            $logData = Get-HPRESTDataRaw -Href $logURI -Session $session
            $imlURI = ''
            foreach($link in $logData.links.Member.href)
            {
                $spl = $link.split('`/')
                if($spl[$spl.length-1] -match 'IML')
                {
                    $imlURI = $link
                    break
                }
            }
            
            # Create hashtable object to invoke action to clear logs
            # Check 'AvailableActions' for values in this hashtable object
            $action = @{'Action'='ClearLog'}
            
            # POST the object using Invoke-HPRESTAction cmdlet
            $ret = Invoke-HPRESTAction -Href $imlURI -Data $action -Session $session

            # Process message(s) returned from Invoke-HPRESTAction cmdlet
            if($ret.Messages.Count -gt 0)
            {
                foreach($msgID in $ret.Messages)
                {
                    $status = Get-HPRESTError -MessageID $msgID.MessageID -MessageArg $msgID.MessageArgs -Session $session
                    $status
                }
            }
        }
    }

    # Disconnect the session after use
    Disconnect-HPREST -Session $session
}
<#
Clear-IMLExample22 -Address $Address -Credential $cred
Get-IMLExample20 -Address $Address -Credential $cred
#>

function Clear-iLOEventLogExample23
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential
    )
    Write-Host 'Example 23: Clear iLO Event Log'

    # Create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication
    
    # Retrieve manager list
    $managers = Get-HPRESTDataRaw -Href 'rest/v1/managers' -Session $session
    foreach($mgr in $managers.links.Member.href)
    {
        $managerData = Get-HPRESTDataRaw -Href $mgr -Session $session
        # check if logs are available or not
        if($managerData.links.PSObject.properties.name -notcontains 'Logs')
        {
            Write-Host 'Logs not available'
        }
        else
        {
            # get the href for iLO event logs
            $logURI = $managerData.links.Logs.href
            $logData = Get-HPRESTDataRaw -Href $logURI -Session $session
            $ielURI = ''
            foreach($link in $logData.links.Member.href)
            {
                $spl = $link.split('`/')
                if($spl[$spl.length-1] -match 'IEL')
                {
                    $ielURI = $link
                    break
                }
            }

            # Create hashtable object to invoke action to clear logs
            # Check 'AvailableActions' for values in this hashtable object
            $action = @{'Action'='ClearLog'}

            # POST the object using Invoke-HPRESTAction cmdlet
            $ret = Invoke-HPRESTAction -Href $ielURI -Data $action -Session $session

            # Process message(s) returned from Invoke-HPRESTAction cmdlet
            if($ret.Messages.Count -gt 0)
            {
                foreach($msgID in $ret.Messages)
                {
                    $status = Get-HPRESTError -MessageID $msgID.MessageID -MessageArg $msgID.MessageArgs -Session $session
                    $status
                }
            }
        }
    }

    # Disconnect the session after use
    Disconnect-HPREST -Session $session
}
<#
Clear-iLOEventLogExample23 -Address $Address -Credential $cred
Get-iLOEventLogExample21 -Address $Address -Credential $cred
#>

function Set-SNMPExample24
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential,

        [System.String]
        $Mode, # Agentless or Passthru

        [System.Object]
        $AlertsEnabled = $null #use true or false only


    )
    Write-Host 'Example 24: Configure iLO SNMP settings.'

    # Create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication
    
    # retrieve list of managers
    $managers = Get-HPRESTDataRaw -Href 'rest/v1/Managers' -Session $session
    foreach($mgr in $managers.links.Member.href)
    {
        # retrieve settings of NetworkService data
        $mgrData = Get-HPRESTDataRaw -Href $mgr -Session $session
        $netSerURI = $mgrData.links.NetworkService.href
        $netSerData = Get-HPRESTDataRaw -Href $netSerURI -Session $session
        if($netSerData.links.PSObject.properties.name -notcontains 'SNMPService')
        {
            Write-Host 'SNMP services not available in Manager Network Service'
        }
        else
        {
            # create hashtable object according to the parameters provided by user
            $snmpSerURI = $netSerData.links.SNMPService.href
            $snmpSetting = @{}
            if($mode -ne '' -and $Mode -ne $null)
            {
                $snmpSetting.Add('Mode',$Mode)
            }
            if($AlertsEnabled -ne $null)
            {
                $snmpSetting.Add('AlertsEnabled',[System.Convert]::ToBoolean($AlertsEnabled))
            }

            # PATCh the settings using Set-HPRESTData cmdlet
            $ret = Set-HPRESTData -Href $snmpSerURI -Setting $snmpSetting -Session $session

            # Process message(s) returned from Set-HPRESTData cmdlet
            if($ret.Messages.Count -gt 0)
            {
                foreach($msgID in $ret.Messages)
                {
                    $status = Get-HPRESTError -MessageID $msgID.MessageID -MessageArg $msgID.MessageArgs -Session $session
                    $status
                }
            }
        }
    }
    # Disconnect the session after use
    Disconnect-HPREST -Session $session
}
#Set-SNMPExample24 -Address $Address -Credential $cred -Mode Agentless -AlertsEnabled $true
 
function Get-SchemaExample25
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential,

        [System.String]
        $Type,

        [ValidateSet('en','jp','zh')]
        [System.String]
        $Language = 'en'


    )

    Write-Host 'Example 25: Retrieve schema'

    # Create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication
    
    # Retrieve the schema with the Type provided by the user
    $sch = Get-HPRESTSchema -Type $Type -Language $Language -Session $session
    $sch.properties
    
    # Disconnect the session after use
    Disconnect-HPREST -Session $session

}
#Get-SchemaExample25 -Address $Address -Credential $cred -Type ComputerSystem

function Get-RegistryExample26
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential,

        [System.String]
        $RegistryPrefix,

        [System.String]
        $Language = 'en'


    )

    Write-Host 'Example 26: Retrieve registry'

    # Create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication
    
    # retrieve list of registries
    $reg = Get-HPRESTDataRaw -href rest/v1/registries -Session $session

    # select the registry where the prefix is same as value provided by user in 'RegistryPrefix' parameter
    $reqRegList = $reg.Items | ? {$_.Schema.ToString().IndexOf($RegistryPrefix) -eq 0}
    
    # retrieve and display the external reference for the required language
    foreach($reqReg in $reqRegList)
    {
        $reqRegURI = ($reqReg.Location|?{$_.Language -eq $Language}).uri.extref
        $reqRegData = Get-HPRESTDataRaw -Href $reqRegURI -Session $session
        $reqRegData
    }
    # Disconnect the session after use
    Disconnect-HPREST -Session $session

}
#Get-RegistryExample26 -Address $Address -Credential $cred -RegistryPrefix HpBiosAttributeRegistryP89

function Set-TimeZoneExample27
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential,

        [System.String]
        $TimeZone
    )

    #NOTE: This will work only if iLO is NOT configured to take time settings from DHCP v4 or v6. Otherwise, error 400 - bad request is thrown.
    Write-Host 'Example 27: Set timezone'

    # Create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication
    
    # retrieve manager list
    $managers = Get-HPRESTDataRaw -href rest/v1/managers -Session $session
    foreach($mgr in $managers.links.Member.href)
    {
        # Retrieve DateTimeService href and timezone name to display to user
        $mgrData = Get-HPRESTDataRaw -href $mgr -Session $session
        $dtsURI = $mgrData.Oem.Hp.links.DateTimeService.href
        $dtsData = Get-HPRESTDataRaw -Href $dtsURI -Session $session
        $currTimeZone = $dtsData.TimeZone.Name
        Write-Host "Current timezone $currTimeZone"

        # from list of all timezone, first check if the user entered value is present in this list.
        foreach($tz in $dtsData.TimeZoneList)
        {
            if($tz.Name -eq $TimeZone)
            {
                # User entered timezone value is present.
                # Create timezone hashtable object to PATCH
                $setting = @{'TimeZone'=@{'Name'=$tz.name}}
                
                # PATCH the new setting using Set-HPRESTData cmdlet
                $ret = Set-HPRESTData -Href $dtsURI -Setting $setting -Session $session

                # Process message(s) returned from Set-HPRESTData cmdlet
                if($ret.Messages.Count -gt 0)
                {
                    foreach($msgID in $ret.Messages)
                    {
                        $status = Get-HPRESTError -MessageID $msgID.MessageID -MessageArg $msgID.MessageArgs -Session $session
                        $status
                    }
                }
                break
            }
        }
    }

    # Disconnect the session after use
    Disconnect-HPREST -Session $session
}
## Patch using Timezone name is preferred over timezone index. If both are patched, Index field will be ignored
## DHCPv4 should be disabled in active NIC for setting the timezone
#Set-TimeZoneExample27 -Address $Address -Credential $cred -TimeZone 'America/Chicago' 

function Set-iLONTPServerExample28
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential,

        [System.Array]
        $StaticNTPServer
    )

    #NOTE: This will work only if iLO is NOT configured to take time settings from DHCP v4 or v6. Otherwise, error 400 - bad request is thrown. 
    Write-Host 'Example 28: Set NTP server'

    # Create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication
    
    # Retrieve manager list
    $managers = Get-HPRESTDataRaw -href rest/v1/managers -Session $session
    foreach($mgr in $managers.links.Member.href)
    {
        # retrieve date time details and display current values
        $mgrData = Get-HPRESTDataRaw -Href $mgr -Session $session
        $dtsURI = $mgrData.Oem.Hp.links.DateTimeService.href
        $dtsData = Get-HPRESTDataRaw -Href $dtsURI -Session $session
        Write-Host Current iLO Date and Time setting - $dtsData.ConfigurationSettings
        Write-Host Current iLO NTP Servers - $dtsData.NTPServers

        # Create hashtable object with values for NTPServer
        $setting = @{'StaticNTPServers'=$StaticNTPServer}

        # PATCH new NTPServer data using Set-HPRESTData
        $ret = Set-HPRESTData -Href $dtsURI -Setting $setting -Session $session

        # Process message(s) returned from Set-HPRESTData cmdlet
        if($ret.Messages.Count -gt 0)
        {
            foreach($msgID in $ret.Messages)
            {
                $status = Get-HPRESTError -MessageID $msgID.MessageID -MessageArg $msgID.MessageArgs -Session $session
                $status
            }
        }
    }

    # Disconnect the session after use
    Disconnect-HPREST -Session $session
}
## DHCPv4 should be disabled in active NIC for setting the StaticNTPServer
#Set-iLONTPServerExample28 -Address $Address -Credential $cred -StaticNTPServer @('10.20.30.1','10.20.30.2')

function Get-PowerMetricExample29
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential
    )

    #NOTE: This will work only if iLO is NOT configured to take time settings from DHCP v4 or v6
    Write-Host 'Example 29: Retrieve PowerMetrics average watts'

    # Create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication
    
    # retrieve chassis list
    $chassis = Get-HPRESTDataRaw -href rest/v1/chassis -Session $session
    foreach($cha in $chassis.links.member.href)
    {
        # get PowerMetrics href, retrieve the data and display
        $chaData = Get-HPRESTDataRaw -Href $cha -Session $session
        $pmURI = $chaData.links.PowerMetrics.href
        $pmData = Get-HPRESTDataRaw -Href $pmURI -Session $session
        $pm = $pmData.PowerMetrics
        Write-Host $chaData.Model AverageConsumedWatts = $pm.AverageConsumedWatts watts over a $pm.IntervalInMin minute moving average
    }

    # Disconnect the session after use
    Disconnect-HPREST -Session $session
}
#Get-PowerMetricExample29 -Address $Address -Credential $cred

function Get-BiosDependenciesExample30
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential
    )

    Write-Host 'Example 30: Get BIOS dependencies.'

    $attRegFromBios = ''
    $attRegLoc = ''
    $registries = $null

    #create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication

    $sysList = Get-HPRESTDataRaw -Href 'rest/v1/systems' -Session $session
    $registries = Get-HPRESTDataRaw -Href $session.RootData.links.Registries.href -Session $session
    foreach($sys in $syslist.links.member.href)
    {
        # Get the Attribute registry version from BIOS settings
        $sysData = Get-HPRESTDataRaw -Href $sys -Session $session
        $biosURI = $sysData.Oem.Hp.links.BIOS.href
        
        # get BIOS data
        $biosData = Get-HPRESTDataRaw -Href $biosURI -Session $session
        $attRegFromBios = $biosData.AttributeRegistry

        # get the atttribute registry that matched the BIOS settings
        foreach($reg in $registries.items)
        {
            if($reg.Schema -eq $attRegFromBios)
            {
                $attRegLoc = $reg.Location|Where-Object{$_.Language -eq 'en'}|%{$_.uri.extref}

                # Display the dependencies from the registry entries
                $attReg = Get-HPRESTDataRaw -Href $attRegLoc -Session $session
                $attReg.RegistryEntries.Dependencies

                break
            }
        }
    }
    
    # Disconnect the session after use
    Disconnect-HPREST -Session $session
}
#Get-BiosDependenciesExample30 -Address $Address -Credential $cred

function Set-TPMExample31
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential,

        [System.String]
        $TPMProperty, # TpmType, TpmState, TPMOperation, TpmVisibility, Tpm2Operation -Tpm2Visibility, Tpm2Ppi, TpmBinding, TpmUefiOpromMeasuring.
        #These property names may be present or not based on the system configuration.

        [System.String]
        $Value
<#
## ValueName is the value to be used in REST interface
## ValueDisplayName is seen in RBSU menu options

TpmType - 
ValueName                                     ValueDisplayName                            
---------                                     ----------------                            
NoTpm                                         No TPM                                      
Tpm12                                         TPM 1.2                                     
Tpm20                                         TPM 2.0                                     
Tcm10                                         TCM 1.0                                     


TpmState
ValueName                                     ValueDisplayName                            
---------                                     ----------------                            
NotPresent                                    Not Present                                 
PresentDisabled                               Present and Disabled                        
PresentEnabled                                Present and Enabled       

TPMOperation
ValueName                                     ValueDisplayName                            
---------                                     ----------------                            
NoAction                                      No Action                                   
Enable                                        Enable                                      
Disable                                       Disable                                     
Clear                                         Clear   

TpmVisibility
ValueName                                     ValueDisplayName                            
---------                                     ----------------                            
Hidden                                        Hidden                                      
Visible                                       Visible                                     

Tpm2Operation
ValueName                                     ValueDisplayName                            
---------                                     ----------------                            
NoAction                                      No Action                                   
Clear                                         Clear                                       


Tpm2Visibility, 
ValueName                                     ValueDisplayName                            
---------                                     ----------------                            
Hidden                                        Hidden                                      
Visible                                       Visible                                     


Tpm2Ppi
ValueName                                     ValueDisplayName                            
---------                                     ----------------                            
Enabled                                       Enabled                                     
Disabled                                      Disabled                                    


TpmBinding 
ValueName                                     ValueDisplayName                            
---------                                     ----------------                            
Enabled                                       Enabled                                     
Disabled                                      Disabled                                    


TpmUefiOpromMeasuring
ValueName                                     ValueDisplayName                            
---------                                     ----------------                            
Enabled                                       Enabled                                     
Disabled                                      Disabled                                    


#>

    )

    Write-Host 'Example 31: Change TPM 2.0 Setting'
    
    #create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication

    #Get BIOS URI
    $sys = Get-HPRESTDataRaw -Href 'rest/v1/systems' -Session $session
    foreach($hrefVal in $sys.links.member.href) # rest/v1/systems/1, rest/v1/system/2
    {
        $data = Get-HPRESTDataRaw -Href $hrefVal -Session $session
        $biosURI = $data.Oem.Hp.links.BIOS.href
    
        #get AttributeRegistry value from BIOS Data
        $biosData = Get-HPRESTDataRaw -Href $biosURI -Session $session
        $biosData
        $ar = $biosData.AttributeRegistry

        # get attribute registries and select the one that matches BIOS data attribute registry
        $reg = Get-HPRESTDataRaw -Href 'rest/v1/registries' -Session $session
        
        #if property to be modified is not present in the bios data, then print error message and return
        if(-not(($biosData|Get-Member).Name -Contains $TPMProperty))
        {
            Write-Host "Property $TPMProperty is not supported on this system"
        }
        else
        {
            #Get setting href to update bios property. For bios, property can be updated in the settings href only. other data may not have setting href
            $biosSettingURI = $biosData.links.settings.href

            # Create hashtable object with TPM property and value to PATCH
            $tpmSetting = @{$TPMProperty=$Value}

            # PATCH TPM setting using Set-HPRESTData
            $ret = Set-HPRESTData -Href $biosSettingURI -Setting $tpmSetting -Session $session

            # Process message(s) returned from Set-HPRESTData cmdlet
            if($ret.Messages.Count -gt 0)
            {
                foreach($msgID in $ret.Messages)
                {
                    $status = Get-HPRESTError -MessageID $msgID.MessageID -MessageArg $msgID.MessageArgs -Session $session
                    $status
                }
            }
        }
    }
       
    # Disconnect the session after use
    Disconnect-HPREST -Session $session
}
<#
Set-TPMExample31 -Address $Address -Credential $cred -TPMProperty Tpm2Visibility -Value Hidden
Reset-ServerExample2 -Address $Address -Credential $cred -Action Reset -PropertyName ResetType -PropertyValue ForceRestart
#>

function Get-TPMExample32
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential,

        [ValidateSet('All', 'TpmType', 'TpmState', 'TPMOperation', 'TpmVisibility', 'Tpm2Operation', 'Tpm2Visibility', 'Tpm2Ppi', 'TpmBinding', 'TpmUefiOpromMeasuring')]
        [System.String]
        $TPMProperty = 'All'
    )

    Write-Host 'Example 32: Get TPM Setting'
    
    #create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication

    #Get BIOS URI
    $sys = Get-HPRESTDataRaw -Href 'rest/v1/systems' -Session $session
    foreach($hrefVal in $sys.links.member.href) # rest/v1/systems/1, rest/v1/system/2
    {
        $data = Get-HPRESTDataRaw -Href $hrefVal -Session $session
        $biosURI = $data.Oem.Hp.links.BIOS.href
    
        #get AttributeRegistry value from BIOS Data
        $biosData = Get-HPRESTDataRaw -Href $biosURI -Session $session
        $ar = $biosData.AttributeRegistry

        # get attribute registries and select the one that matches BIOS data attribute registry
        $reg = Get-HPRESTDataRaw -Href 'rest/v1/registries' -Session $session
        $selectedReg = $null
        foreach($x in $reg.Items)
        {
            if($x.Schema -eq $ar)
            {
                $selectedReg = $x
            }
        }
        if($selectedReg -eq $null)
        {
            Write-Host 'No valid registry available for BIOS/TPM settings'
        }
        else
        {
            # Display TMP registry entries
            $attReg = Get-HPRESTDataRaw -Href ($selectedReg.Location|?{$_.Language -eq 'en'}|%{$_.URI.extref}) -Session $session

            if($TPMProperty -eq 'All')
            {
                $tpmDetails = $attReg.RegistryEntries.Attributes | ?{$_.name -match 'TPM'}
                $tpmDetails
            }
            else
            {
                $tpmDetails = $attReg.RegistryEntries.Attributes | ?{$_.name -match $TPMProperty}
                if(-not(($biosData|Get-Member).Name -Contains $TPMProperty))
                {
                    Write-Host "Property $TPMProperty is not supported on this system"
                }
                else
                {
                    $tpmDetails
                }
            }
        }
    }
       
    # Disconnect the session after use
    Disconnect-HPREST -Session $session
}
#Get-TPMExample32 -Address $Address -Credential $cred -TPMProperty TpmBinding

function Get-ThermalMetricsExample33
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential
    )

    Write-Host 'Example 33: Get Temperature and Fan details from Thermal Metrics.'
    
    #create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication

    #retrieve Chassis list
    $chassisList = Get-HPRESTDataRaw -Href rest/v1/chassis -Session $session
    foreach($mem in $chassisList.links.Member)
    {
        $chasis = Get-HPRESTDataRaw -Href $mem.href -Session $session
        
        # get the thermal metrics of the chassis
        $thermalMetrics = Get-HPRESTDataRaw -Href $chasis.links.ThermalMetrics.href -Session $session
        
        # display temperature values
        Write-Host "Temperature: "
        $temps = $thermalMetrics.Temperatures
        $temps
        
        # display fan values        
        Write-Host "Fans: "
        $fans = $thermalMetrics.Fans
        $fans
    }
    Disconnect-HPREST -Session $session
}
#Get-ThermalMetricsExample33 -Address $Address -Credential $cred

function Set-BIOSPowerOnPassword34
{
    param
    (
        [System.String]
        $Address,

        [PSCredential]
        $Credential,

        [System.String]
        $OldPowerOnPassword = '',

        [System.String]
        $NewPowerOnPassword
    )

    Write-Host 'Example 34: Change BIOS Password'
    
    #create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication

    #Get list of systems
    $systems = Get-HPRESTDataRaw -Href 'rest/v1/systems' -Session $session
    foreach($sys in $systems.links.member.href) # rest/v1/systems/1, rest/v1/system/2
    {
        #Get BIOS URI from system data
        $data = Get-HPRESTDataRaw -Href $sys -Session $session
        $biosURI = $data.Oem.Hp.links.BIOS.href
    
        #get BIOS Data
        $biosData = Get-HPRESTDataRaw -Href $biosURI -Session $session

        #if property to be modified is not present in the bios data, then print error message and return
        #Get setting href to update bios property. For bios, property can be updated in the settings href only. Other data may or may not have setting href

        #creating setting object
        # provide old and new BIOS password values for the respective fields
        $biosSetting = @{}
        $biosSetting.Add("OldPowerOnPassword",$OldPowerOnPassword)
        $biosSetting.Add("PowerOnPassword",$NewPowerOnPassword)
            
        Function Get-StringSHA256Hash
        { 
            param (
              [parameter(Mandatory=$true)] [String] $String
           )
            $StringBuilder = New-Object System.Text.StringBuilder
            [System.Security.Cryptography.HashAlgorithm]::Create('SHA256').ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String))|%{ 
            [Void]$StringBuilder.Append($_.ToString("X2"))
            }
            $StringBuilder.ToString()
        }

        if($OldPowerOnPassword -ne "" -and $OldPowerOnPassword -ne $null)
        {
            $rsa256Pwd = Get-StringSHA256Hash -String $OldPowerOnPassword
            $header = @{}
            $header.Add('X-HPRESTFULAPI-AuthToken',$rsa256Pwd)

            #updating setting in system bios settings
            $ret = Set-HPRESTData -Href $biosURI -Setting $biosSetting -Session $session -Header $header
        }
        else
        {
            #updating setting in system bios settings
            $ret = Set-HPRESTData -Href $biosURI -Setting $biosSetting -Session $session
        }

        # processing message obtained by executing Set- cmdlet
        if($ret.Messages.Count -gt 0)
        {
            foreach($msgID in $ret.Messages)
            {
                $status = Get-HPRESTError -MessageID $msgID.MessageID -MessageArg $msgID.MessageArgs -Session $session
                $status
            }
        }
    }

    # disconnecting the session after use
    Disconnect-HPREST -Session $session
}

<#
##If the old BIOS password is not set:
#Set-BIOSPowerOnPassword34 -Address $Address -Credential $cred -OldPowerOnPassword '' -NewPowerOnPassword 'passwd123'
##reset makes the BIOS password setting effective
#Reset-ServerExample2 -Address $Address -Credential $cred -Action Reset -PropertyName ResetType -PropertyValue ForceRestart


##If an old BIOS password exists and has to be updated:
#Set-BIOSPowerOnPassword34 -Address $Address -Credential $cred -OldPowerOnPassword 'passwd123' -NewPowerOnPassword 'newpasswd'
##reset makes the BIOS password setting effective
#Reset-ServerExample2 -Address $Address -Credential $cred -Action Reset -PropertyName ResetType -PropertyValue ForceRestart


##To remove bios password, provide existing password as old password and a blank value for the new password:
#Set-BIOSPowerOnPassword34 -Address $Address -Credential $cred -OldPowerOnPassword 'newpasswd' -NewPowerOnPassword ''
##reset makes the BIOS password setting effective
#Reset-ServerExample2 -Address $Address -Credential $cred -Action Reset -PropertyName ResetType -PropertyValue ForceRestart
#>

function Get-AHSLogsExample35
{
    param
    (
        [System.String]
        $Address,

        [System.String]
        $OutputAHSFile,

        [PSCredential]
        $Credential
    )

    Write-Host 'Example 35: Download AHS logs.'
    
    #create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication

    #retrieve Chassis list
    $managerList = Get-HPRESTDataRaw -Href 'rest/v1/Managers' -Session $session
    foreach($mem in $managerList.links.Member)
    {
        $manager = Get-HPRESTDataRaw -Href $mem.href -Session $session
        $ahsHref = $manager.Oem.Hp.links.ActiveHealthSystem.href

        # get the Href for AHS logs
        $ahsData = Get-HPRESTDataRaw -Href $ahsHref -Session $session
        $ahsLogHref = $ahsData.links.AHSLocation.extref
        
        # get the AHS logs in ByteArray format
        $ahsLogs = Get-HPRESTDataRaw -Href $ahsLogHref -Session $session -OutputType 'ByteArray'

        # AHS logs are stored in the specified filename
        [System.IO.File]::WriteAllBytes($OutputAHSFile, $ahsLogs)

    }
    Disconnect-HPREST -Session $session
}
#Get-AHSLogsExample35 -Address $Address -OutputAHSFile 'c:\ahsLogsOutput.ahs' -Credential $cred

function Update-FirmwareExample36
{
    param(
        [System.String]
        [parameter(Mandatory=$true)]
        $Address = '',

        [PSCredential]
        $Credential,

        [System.String]
        [parameter(Mandatory=$true)]
        $FirmwareURI = '',

        [switch]
        [parameter(Mandatory=$false)]
        $TPMOverride
    )

    if($null -eq $FirmwareURI -or $FirmwareURI -eq '')
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,'FirmwareURI'))
    }

    if($null -eq $Address -or $Address -eq '')
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,'Address'))
    }

    Write-Host 'Example 36: Update Firmware'
    
    # create session
    $session = Connect-HPREST -Address $Address -Credential $Credential -DisableCertificateAuthentication

    # getting managers list
    $managers = Get-HPRESTDataRaw -Href 'rest/v1/Managers' -Session $session
    foreach($manager in $managers.links.Member){
        
        # retrieve update service href
        $managerData = Get-HPRESTDataRaw -Href $manager.href -Session $session
        $updateURI = $managerData.oem.Hp.links.UpdateService.href
        
        #Creating payload
        $dataToPost = @{}
        $dataToPost.Add('Action','InstallFromURI')
        $dataToPost.Add('FirmwareURI',$FirmwareURI)
        $dataToPost.Add('TPMOverrideFlag', $TPMOverride.IsPresent)
    
        # Sending update request to system using 'POST' in Invoke-HPRESTAction
        $ret = Invoke-HPRESTAction -Href $updateURI -Data $dataToPost -Session $session

        # processing message obtained by executing Set- cmdlet
        if($ret.Messages.Count -gt 0)
        {
            foreach($msgID in $ret.Messages)
            {
                $status = Get-HPRESTError -MessageID $msgID.MessageID -MessageArg $msgID.MessageArgs -Session $session
                $status
            }
        }
    }

    Disconnect-HPREST -Session $session    
}
## Update iLO, ROM, System Programmable Logic Device, or SL/XL chassis firmware using this example. Provide the path on the network share or web server location in the -FirmwareURI parameter
#Update-FirmwareExample36 -Address $Address -FirmwareURI 'http://10.20.30.1/firmware/iLO4/ilo4_240_p24_checked.bin' -TPMOverride -Credential $cred

# SIG # Begin signature block
# MIIjqAYJKoZIhvcNAQcCoIIjmTCCI5UCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDHVwvn4Zg6ljXr
# zGvNsREVzCvkCBvZROPBy5uDOxN13aCCHrMwggPuMIIDV6ADAgECAhB+k+v7fMZO
# WepLmnfUBvw7MA0GCSqGSIb3DQEBBQUAMIGLMQswCQYDVQQGEwJaQTEVMBMGA1UE
# CBMMV2VzdGVybiBDYXBlMRQwEgYDVQQHEwtEdXJiYW52aWxsZTEPMA0GA1UEChMG
# VGhhd3RlMR0wGwYDVQQLExRUaGF3dGUgQ2VydGlmaWNhdGlvbjEfMB0GA1UEAxMW
# VGhhd3RlIFRpbWVzdGFtcGluZyBDQTAeFw0xMjEyMjEwMDAwMDBaFw0yMDEyMzAy
# MzU5NTlaMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsayzSVRLlxwS
# CtgleZEiVypv3LgmxENza8K/LlBa+xTCdo5DASVDtKHiRfTot3vDdMwi17SUAAL3
# Te2/tLdEJGvNX0U70UTOQxJzF4KLabQry5kerHIbJk1xH7Ex3ftRYQJTpqr1SSwF
# eEWlL4nO55nn/oziVz89xpLcSvh7M+R5CvvwdYhBnP/FA1GZqtdsn5Nph2Upg4XC
# YBTEyMk7FNrAgfAfDXTekiKryvf7dHwn5vdKG3+nw54trorqpuaqJxZ9YfeYcRG8
# 4lChS+Vd+uUOpyyfqmUg09iW6Mh8pU5IRP8Z4kQHkgvXaISAXWp4ZEXNYEZ+VMET
# fMV58cnBcQIDAQABo4H6MIH3MB0GA1UdDgQWBBRfmvVuXMzMdJrU3X3vP9vsTIAu
# 3TAyBggrBgEFBQcBAQQmMCQwIgYIKwYBBQUHMAGGFmh0dHA6Ly9vY3NwLnRoYXd0
# ZS5jb20wEgYDVR0TAQH/BAgwBgEB/wIBADA/BgNVHR8EODA2MDSgMqAwhi5odHRw
# Oi8vY3JsLnRoYXd0ZS5jb20vVGhhd3RlVGltZXN0YW1waW5nQ0EuY3JsMBMGA1Ud
# JQQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIBBjAoBgNVHREEITAfpB0wGzEZ
# MBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMTANBgkqhkiG9w0BAQUFAAOBgQADCZuP
# ee9/WTCq72i1+uMJHbtPggZdN1+mUp8WjeockglEbvVt61h8MOj5aY0jcwsSb0ep
# rjkR+Cqxm7Aaw47rWZYArc4MTbLQMaYIXCp6/OJ6HVdMqGUY6XlAYiWWbsfHN2qD
# IQiOQerd2Vc/HXdJhyoWBl6mOGoiEqNRGYN+tjCCBKMwggOLoAMCAQICEA7P9DjI
# /r81bgTYapgbGlAwDQYJKoZIhvcNAQEFBQAwXjELMAkGA1UEBhMCVVMxHTAbBgNV
# BAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTAwLgYDVQQDEydTeW1hbnRlYyBUaW1l
# IFN0YW1waW5nIFNlcnZpY2VzIENBIC0gRzIwHhcNMTIxMDE4MDAwMDAwWhcNMjAx
# MjI5MjM1OTU5WjBiMQswCQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29y
# cG9yYXRpb24xNDAyBgNVBAMTK1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2Vydmlj
# ZXMgU2lnbmVyIC0gRzQwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCi
# Yws5RLi7I6dESbsO/6HwYQpTk7CY260sD0rFbv+GPFNVDxXOBD8r/amWltm+YXkL
# W8lMhnbl4ENLIpXuwitDwZ/YaLSOQE/uhTi5EcUj8mRY8BUyb05Xoa6IpALXKh7N
# S+HdY9UXiTJbsF6ZWqidKFAOF+6W22E7RVEdzxJWC5JH/Kuu9mY9R6xwcueS51/N
# ELnEg2SUGb0lgOHo0iKl0LoCeqF3k1tlw+4XdLxBhircCEyMkoyRLZ53RB9o1qh0
# d9sOWzKLVoszvdljyEmdOsXF6jML0vGjG/SLvtmzV4s73gSneiKyJK4ux3DFvk6D
# Jgj7C72pT5kI4RAocqrNAgMBAAGjggFXMIIBUzAMBgNVHRMBAf8EAjAAMBYGA1Ud
# JQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIHgDBzBggrBgEFBQcBAQRn
# MGUwKgYIKwYBBQUHMAGGHmh0dHA6Ly90cy1vY3NwLndzLnN5bWFudGVjLmNvbTA3
# BggrBgEFBQcwAoYraHR0cDovL3RzLWFpYS53cy5zeW1hbnRlYy5jb20vdHNzLWNh
# LWcyLmNlcjA8BgNVHR8ENTAzMDGgL6AthitodHRwOi8vdHMtY3JsLndzLnN5bWFu
# dGVjLmNvbS90c3MtY2EtZzIuY3JsMCgGA1UdEQQhMB+kHTAbMRkwFwYDVQQDExBU
# aW1lU3RhbXAtMjA0OC0yMB0GA1UdDgQWBBRGxmmjDkoUHtVM2lJjFz9eNrwN5jAf
# BgNVHSMEGDAWgBRfmvVuXMzMdJrU3X3vP9vsTIAu3TANBgkqhkiG9w0BAQUFAAOC
# AQEAeDu0kSoATPCPYjA3eKOEJwdvGLLeJdyg1JQDqoZOJZ+aQAMc3c7jecshaAba
# tjK0bb/0LCZjM+RJZG0N5sNnDvcFpDVsfIkWxumy37Lp3SDGcQ/NlXTctlzevTcf
# Q3jmeLXNKAQgo6rxS8SIKZEOgNER/N1cdm5PXg5FRkFuDbDqOJqxOtoJcRD8HHm0
# gHusafT9nLYMFivxf1sJPZtb4hbKE4FtAC44DagpjyzhsvRaqQGvFZwsL0kb2yK7
# w/54lFHDhrGCiF3wPbRRoXkzKy57udwgCRNx62oZW8/opTBXLIlJP7nPf8m/PiJo
# Y1OavWl0rMUdPH+S4MO8HNgEdTCCBUwwggM0oAMCAQICEzMAAAA12NVZWwZxQSsA
# AAAAADUwDQYJKoZIhvcNAQEFBQAwfzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEpMCcGA1UEAxMgTWljcm9zb2Z0IENvZGUgVmVyaWZpY2F0aW9u
# IFJvb3QwHhcNMTMwODE1MjAyNjMwWhcNMjMwODE1MjAzNjMwWjBvMQswCQYDVQQG
# EwJTRTEUMBIGA1UEChMLQWRkVHJ1c3QgQUIxJjAkBgNVBAsTHUFkZFRydXN0IEV4
# dGVybmFsIFRUUCBOZXR3b3JrMSIwIAYDVQQDExlBZGRUcnVzdCBFeHRlcm5hbCBD
# QSBSb290MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAt/caM+byAAQt
# OeBOW+0fvGwPzbX6I7bO3psRM5ekKUx9k5+9SryT7QMa44/P5W1QWtaXKZRagLBJ
# etsulf24yr83OC0ePpFBrXBWx/BPP+gynnTKyJBU6cZfD3idmkA8Dqxhql4Uj56H
# oWpQ3NeaTq8Fs6ZxlJxxs1BgCscTnTgHhgKo6ahpJhiQq0ywTyOrOk+E2N/On+Fp
# b7vXQtdrROTHre5tQV9yWnEIN7N5ZaRZoJQ39wAvDcKSctrQOHLbFKhFxF0qfbe0
# 1sTurM0TRLfJK91DACX6YblpalgjEbenM49WdVn1zSnXRrcKK2W200JvFbK4e/vv
# 6V1T1TRaJwIDAQABo4HQMIHNMBMGA1UdJQQMMAoGCCsGAQUFBwMDMBIGA1UdEwEB
# /wQIMAYBAf8CAQIwHQYDVR0OBBYEFK29mHo0tCb3+sQmVO8DveAky1QaMAsGA1Ud
# DwQEAwIBhjAfBgNVHSMEGDAWgBRi+wohW39DbhHaCVRQa/XSlnHxnjBVBgNVHR8E
# TjBMMEqgSKBGhkRodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9k
# dWN0cy9NaWNyb3NvZnRDb2RlVmVyaWZSb290LmNybDANBgkqhkiG9w0BAQUFAAOC
# AgEANiui8uEzH+ST9/JphcZkDsmbYy/kcDeY/ZTse8/4oUJG+e1qTo00aTYFVXoe
# u62MmUKWBuklqCaEvsG/Fql8qlsEt/3RwPQCvijt9XfHm/469ujBe9OCq/oUTs8r
# z+XVtUhAsaOPg4utKyVTq6Y0zvJD908s6d0eTlq2uug7EJkkALxQ/Xj25SOoiZST
# 97dBMDdKV7fmRNnJ35kFqkT8dK+CZMwHywG2CcMu4+gyp7SfQXjHoYQ2VGLy7BUK
# yOrQhPjx4Gv0VhJfleD83bd2k/4pSiXpBADxtBEOyYSe2xd99R6ljjYpGTptbEZL
# 16twJCiNBaPZ1STy+KDRPII51KiCDmk6gQn8BvDHWTOENpMGQZEjLCKlpwErULQo
# rttGsFkbhrObh+hJTjkLbRTfTAMwHh9fdK71W1kDU+yYFuDQYjV1G0i4fRPleki4
# d1KkB5glOwabek5qb0SGTxRPJ3knPVBzQUycQT7dKQxzscf7H3YMF2UE69JQEJJB
# SezkBn02FURvib9pfflNQME6mLagfjHSta7K+1PVP1CGzV6TO21dfJo/P/epJViE
# 3RFJAKLHyJ433XeObXGL4FuBNF1Uusz1k0eIbefvW+Io5IAbQOQPKtF/IxVlWqyZ
# lEM/RlUm1sT6iJXikZqjLQuF3qyM4PlncJ9xeQIx92GiKcQwggVqMIIEUqADAgEC
# AhEA3GTlJ1A9M/BwMzcyvM3YkDANBgkqhkiG9w0BAQsFADB9MQswCQYDVQQGEwJH
# QjEbMBkGA1UECBMSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxmb3Jk
# MRowGAYDVQQKExFDT01PRE8gQ0EgTGltaXRlZDEjMCEGA1UEAxMaQ09NT0RPIFJT
# QSBDb2RlIFNpZ25pbmcgQ0EwHhcNMTcwODE0MDAwMDAwWhcNMTgwODE0MjM1OTU5
# WjCB0jELMAkGA1UEBhMCVVMxDjAMBgNVBBEMBTk0MzA0MQswCQYDVQQIDAJDQTES
# MBAGA1UEBwwJUGFsbyBBbHRvMRwwGgYDVQQJDBMzMDAwIEhhbm92ZXIgU3RyZWV0
# MSswKQYDVQQKDCJIZXdsZXR0IFBhY2thcmQgRW50ZXJwcmlzZSBDb21wYW55MRow
# GAYDVQQLDBFIUCBDeWJlciBTZWN1cml0eTErMCkGA1UEAwwiSGV3bGV0dCBQYWNr
# YXJkIEVudGVycHJpc2UgQ29tcGFueTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC
# AQoCggEBAMV6msMHbQ1HoKkqIAakZl0zTmJcEYdyWMz7vEGKHttpw9hDmejCpUeY
# W/9BaUu2mI1yW/XC3F2GeMb0ImUo1Yejb85tPbPVTc8j8nTGrlLQ+kHGjewhh14O
# StBDXFnoD0dO9VSYI0l0zNRJxBz7XBwvVhIqCwwuKHl7GqU833fGLKtCO/pmOd6D
# pqiBoSehq7Dpct1g70wSLkjNmzQJpaFBGdB8gpo8EPqLqnJ+LGvwM0x83O4o60f+
# uiRgPn//TgC4BQ1LqLWcyxwlzPSNx+mOn2TnDIXrIUdLnVSFFo3b2gWg37XWT2u+
# UaAIIeC1vNGio6GlggOAZtpB1Fw1ixUCAwEAAaOCAY0wggGJMB8GA1UdIwQYMBaA
# FCmRYP+KTfrr+aZquM/55ku9Sc4SMB0GA1UdDgQWBBRY98jf5AH19heGv91inQ4Q
# kGetXjAOBgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggr
# BgEFBQcDAzARBglghkgBhvhCAQEEBAMCBBAwRgYDVR0gBD8wPTA7BgwrBgEEAbIx
# AQIBAwIwKzApBggrBgEFBQcCARYdaHR0cHM6Ly9zZWN1cmUuY29tb2RvLm5ldC9D
# UFMwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2NybC5jb21vZG9jYS5jb20vQ09N
# T0RPUlNBQ29kZVNpZ25pbmdDQS5jcmwwdAYIKwYBBQUHAQEEaDBmMD4GCCsGAQUF
# BzAChjJodHRwOi8vY3J0LmNvbW9kb2NhLmNvbS9DT01PRE9SU0FDb2RlU2lnbmlu
# Z0NBLmNydDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuY29tb2RvY2EuY29tMA0G
# CSqGSIb3DQEBCwUAA4IBAQASJVM4nkMiKaayG12Zi0fsPjnnp7gmBMFQL1oknbS6
# TcGH9gwHWJQcYmwDHhUm0lU25Vts62PtSkawnSsLS1Lc2rvxBsv4vuqZA7+2NKUo
# EY4Ac4KzZ9hQEEftROmLpJgQwt5z4CMsDqd6X8fwGix20lsOXjVguLZCXP8IoKEO
# g/BnSflxJwsUqlMCWPG5h9uPK58sR8gWffwWN4zr9bb/AkaRS8u4L1Xsz9vGhXqm
# QAmBCehSQpOW5xJArnRUU0KgyZ0kT8RALxgcOs/ReiwxPnVxDLvERym9hy6Bmruu
# OmsfMHhArb6ID4XfRzo8qrpzhlDmvcyIwCIVRuPH3RTfMIIFdDCCBFygAwIBAgIQ
# J2buVutJ846r13Ci/ITeIjANBgkqhkiG9w0BAQwFADBvMQswCQYDVQQGEwJTRTEU
# MBIGA1UEChMLQWRkVHJ1c3QgQUIxJjAkBgNVBAsTHUFkZFRydXN0IEV4dGVybmFs
# IFRUUCBOZXR3b3JrMSIwIAYDVQQDExlBZGRUcnVzdCBFeHRlcm5hbCBDQSBSb290
# MB4XDTAwMDUzMDEwNDgzOFoXDTIwMDUzMDEwNDgzOFowgYUxCzAJBgNVBAYTAkdC
# MRswGQYDVQQIExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQx
# GjAYBgNVBAoTEUNPTU9ETyBDQSBMaW1pdGVkMSswKQYDVQQDEyJDT01PRE8gUlNB
# IENlcnRpZmljYXRpb24gQXV0aG9yaXR5MIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEAkehUktIKVrGsDSTdxc9EZ3SZKzejfSNwAHG8U9/E+ioSj0t/EFa9
# n3Byt2F/yUsPF6c947AEYe7/EZfH9IY+Cvo+XPmT5jR62RRr55yzhaCCenavcZDX
# 7P0N+pxs+t+wgvQUfvm+xKYvT3+Zf7X8Z0NyvQwA1onrayzT7Y+YHBSrfuXjbvzY
# qOSSJNpDa2K4Vf3qwbxstovzDo2a5JtsaZn4eEgwRdWt4Q08RWD8MpZRJ7xnw8ou
# tmvqRsfHIKCxH2XeSAi6pE6p8oNGN4Tr6MyBSENnTnIqm1y9TBsoilwie7SrmNnu
# 4FGDwwlGTm0+mfqVF9p8M1dBPI1R7Qu2XK8sYxrfV8g/vOldxJuvRZnio1oktLqp
# Vj3Pb6r/SVi+8Kj/9Lit6Tf7urj0Czr56ENCHonYhMsT8dm74YlguIwoVqwUHZwK
# 53Hrzw7dPamWoUi9PPevtQ0iTMARgexWO/bTouJbt7IEIlKVgJNp6I5MZfGRAy1w
# dALqi2cVKWlSArvX31BqVUa/oKMoYX9w0MOiqiwhqkfOKJwGRXa/ghgntNWutMtQ
# 5mv0TIZxMOmm3xaG4Nj/QN370EKIf6MzOi5cHkERgWPOGHFrK+ymircxXDpqR+DD
# eVnWIBqv8mqYqnK8V0rSS527EPywTEHl7R09XiidnMy/s1Hap0flhFMCAwEAAaOB
# 9DCB8TAfBgNVHSMEGDAWgBStvZh6NLQm9/rEJlTvA73gJMtUGjAdBgNVHQ4EFgQU
# u69+Aj36pvE8hI6t7jiY7NkyMtQwDgYDVR0PAQH/BAQDAgGGMA8GA1UdEwEB/wQF
# MAMBAf8wEQYDVR0gBAowCDAGBgRVHSAAMEQGA1UdHwQ9MDswOaA3oDWGM2h0dHA6
# Ly9jcmwudXNlcnRydXN0LmNvbS9BZGRUcnVzdEV4dGVybmFsQ0FSb290LmNybDA1
# BggrBgEFBQcBAQQpMCcwJQYIKwYBBQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0cnVz
# dC5jb20wDQYJKoZIhvcNAQEMBQADggEBAGS/g/FfmoXQzbihKVcN6Fr30ek+8nYE
# bvFScLsePP9NDXRqzIGCJdPDoCpdTPW6i6FtxFQJdcfjJw5dhHk3QBN39bSsHNA7
# qxcS1u80GH4r6XnTq1dFDK8o+tDb5VCViLvfhVdpfZLYUspzgb8c8+a4bmYRBbMe
# lC1/kZWSWfFMzqORcUx8Rww7Cxn2obFshj5cqsQugsv5B5a6SE2Q8pTIqXOi6wZ7
# I53eovNNVZ96YUWYGGjHXkBrI/V5eu+MtWuLt29G9HvxPUsE2JOAWVrgQSQdso8V
# YFhH2+9uRv0V9dlfmrPb2LjkQLPNlzmuhbsdjrzch5vRpu/xO28QOG8wggXgMIID
# yKADAgECAhAufIfMDpNKUv6U/Ry3zTSvMA0GCSqGSIb3DQEBDAUAMIGFMQswCQYD
# VQQGEwJHQjEbMBkGA1UECBMSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdT
# YWxmb3JkMRowGAYDVQQKExFDT01PRE8gQ0EgTGltaXRlZDErMCkGA1UEAxMiQ09N
# T0RPIFJTQSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTAeFw0xMzA1MDkwMDAwMDBa
# Fw0yODA1MDgyMzU5NTlaMH0xCzAJBgNVBAYTAkdCMRswGQYDVQQIExJHcmVhdGVy
# IE1hbmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQxGjAYBgNVBAoTEUNPTU9ETyBD
# QSBMaW1pdGVkMSMwIQYDVQQDExpDT01PRE8gUlNBIENvZGUgU2lnbmluZyBDQTCC
# ASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKaYkGN3kTR/itHd6WcxEevM
# Hv0xHbO5Ylc/k7xb458eJDIRJ2u8UZGnz56eJbNfgagYDx0eIDAO+2F7hgmz4/2i
# aJ0cLJ2/cuPkdaDlNSOOyYruGgxkx9hCoXu1UgNLOrCOI0tLY+AilDd71XmQChQY
# USzm/sES8Bw/YWEKjKLc9sMwqs0oGHVIwXlaCM27jFWM99R2kDozRlBzmFz0hUpr
# D4DdXta9/akvwCX1+XjXjV8QwkRVPJA8MUbLcK4HqQrjr8EBb5AaI+JfONvGCF1H
# s4NB8C4ANxS5Eqp5klLNhw972GIppH4wvRu1jHK0SPLj6CH5XkxieYsCBp9/1QsC
# AwEAAaOCAVEwggFNMB8GA1UdIwQYMBaAFLuvfgI9+qbxPISOre44mOzZMjLUMB0G
# A1UdDgQWBBQpkWD/ik366/mmarjP+eZLvUnOEjAOBgNVHQ8BAf8EBAMCAYYwEgYD
# VR0TAQH/BAgwBgEB/wIBADATBgNVHSUEDDAKBggrBgEFBQcDAzARBgNVHSAECjAI
# MAYGBFUdIAAwTAYDVR0fBEUwQzBBoD+gPYY7aHR0cDovL2NybC5jb21vZG9jYS5j
# b20vQ09NT0RPUlNBQ2VydGlmaWNhdGlvbkF1dGhvcml0eS5jcmwwcQYIKwYBBQUH
# AQEEZTBjMDsGCCsGAQUFBzAChi9odHRwOi8vY3J0LmNvbW9kb2NhLmNvbS9DT01P
# RE9SU0FBZGRUcnVzdENBLmNydDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuY29t
# b2RvY2EuY29tMA0GCSqGSIb3DQEBDAUAA4ICAQACPwI5w+74yjuJ3gxtTbHxTpJP
# r8I4LATMxWMRqwljr6ui1wI/zG8Zwz3WGgiU/yXYqYinKxAa4JuxByIaURw61OHp
# Cb/mJHSvHnsWMW4j71RRLVIC4nUIBUzxt1HhUQDGh/Zs7hBEdldq8d9YayGqSdR8
# N069/7Z1VEAYNldnEc1PAuT+89r8dRfb7Lf3ZQkjSR9DV4PqfiB3YchN8rtlTaj3
# hUUHr3ppJ2WQKUCL33s6UTmMqB9wea1tQiCizwxsA4xMzXMHlOdajjoEuqKhfB/L
# YzoVp9QVG6dSRzKp9L9kR9GqH1NOMjBzwm+3eIKdXP9Gu2siHYgL+BuqNKb8jPXd
# f2WMjDFXMdA27Eehz8uLqO8cGFjFBnfKS5tRr0wISnqP4qNS4o6OzCbkstjlOMKo
# 7caBnDVrqVhhSgqXtEtCtlWdvpnncG1Z+G0qDH8ZYF8MmohsMKxSCZAWG/8rndvQ
# IMqJ6ih+Mo4Z33tIMx7XZfiuyfiDFJN2fWTQjs6+NX3/cjFNn569HmwvqI8MBlD7
# jCezdsn05tfDNOKMhyGGYf6/VXThIXcDCmhsu+TJqebPWSXrfOxFDnlmaOgizbjv
# mIVNlhE8CYrQf7woKBP7aspUjZJczcJlmAaezkhb1LU3k0ZBfAfdz/pD77pnYf99
# SeC7MH1cgOPmFjlLpzGCBEswggRHAgEBMIGSMH0xCzAJBgNVBAYTAkdCMRswGQYD
# VQQIExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQxGjAYBgNV
# BAoTEUNPTU9ETyBDQSBMaW1pdGVkMSMwIQYDVQQDExpDT01PRE8gUlNBIENvZGUg
# U2lnbmluZyBDQQIRANxk5SdQPTPwcDM3MrzN2JAwDQYJYIZIAWUDBAIBBQCgfDAQ
# BgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgIsdQx296
# fmL9cWtZA+GMEKTrpirQeLCxByiLnk1gwDYwDQYJKoZIhvcNAQEBBQAEggEAeKIp
# ya51CgZEqIrTxLs//tnb1Js8R3tmAwSEuLOAohfPa1QNGDZ/yRJlYLdW2kh6XGSG
# NnfqPe5aAdHPX8jloilgTseDM91Bd6WU5A4aEH1iBgDmIj0XMSwwTzc//+NmTH9+
# MKkRBaGHmOWsFKYcb4lJuBt2qvLWPnOOWi/PVem2RrHgCd3O0BKnlfzJJyY+gARP
# Y/FvNDBMwly9Qyc6NkYO//n5d/z3rQG3qjzpT2Kyhiacb3icc6iYqOgcOCEf0SHn
# IHlyJzdwB5ZRWEAofW+FbX8KYfYru0qkBvXVFxyPAiw6LkwnZ7YrQnV9e5NNwTGK
# +Qk8D/SPVmXUKIi5dKGCAgswggIHBgkqhkiG9w0BCQYxggH4MIIB9AIBATByMF4x
# CzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEwMC4G
# A1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBDQSAtIEcyAhAO
# z/Q4yP6/NW4E2GqYGxpQMAkGBSsOAwIaBQCgXTAYBgkqhkiG9w0BCQMxCwYJKoZI
# hvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0xNzEwMjYwNDM5NDNaMCMGCSqGSIb3DQEJ
# BDEWBBQMwRu9vQXyWMS4hg4NXzD1U7VbRjANBgkqhkiG9w0BAQEFAASCAQAy9fpV
# JCqbJJeO6E/siAeJme/7av7327zCTB+vky49DH4tehmMiHMW34ndLH4OmLHgukZl
# pKInhMLyNydookHj/EoAP72olI2A2OaL07GTMJx9QkZBIa9SCifPwxGgtv52R44+
# +mUsNlrYDXSPsfjv/Kpnrk/JmUI9DnxHUY0uC4zvQ0K/bpNa7CiDZ2JoGzZC/rT4
# yRlAE+D+VC5xq5kS2XasgH5Lh6AAm8JSEXeBmZf9JalYSAApdzfB754mAxsTDTUO
# JjUPr+UsHKkOnJSYPpUM3XNTJv3/t3vzPba4FCaM53EQ3Ga2nnlbtn78AV1puu+O
# nIJxPyOBOwIyGwM0
# SIG # End signature block
