# .ExternalHelp Microsoft.SystemCenter.OperationsManagerV10.Commands.dll-Help.xml
function Get-SCOMCommand
{
    [CmdletBinding(DefaultParameterSetName='CmdletSet')]
    param(
    [Parameter(ParameterSetName='AllCommandSet', Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
    [ValidateNotNullOrEmpty()]
    [System.String[]]
    ${Name},

    [Parameter(ParameterSetName='CmdletSet', ValueFromPipelineByPropertyName=$true)]
    [System.String[]]
    ${Verb},

    [Parameter(ParameterSetName='CmdletSet', ValueFromPipelineByPropertyName=$true)]
    [System.String[]]
    ${Noun},
   
    [Parameter(ParameterSetName='AllCommandSet', ValueFromPipelineByPropertyName=$true)]
    [Alias('Type')]
    [System.Management.Automation.CommandTypes]
    ${CommandType})
    
    process {
        Get-Command @psboundParameters -Module OperationsManager
    }
}

# .ExternalHelp Microsoft.SystemCenter.OperationsManagerV10.Commands.dll-Help.xml
function Write-SCOMCommand
{
    [CmdletBinding(DefaultParameterSetName='Name')]
    param(    
    [Parameter(Mandatory=$true,ParameterSetName='Name')]
    [String]$Name,
    [Parameter(Mandatory=$true,ParameterSetName='NoName')]
    [Switch]$NoName    
    )
    
    process {
        if ($psCmdlet.ParameterSetName -eq 'Name') {
@"
function $Name {
    param(
    [ValidateNotNullOrEmpty()]
    [Microsoft.SystemCenter.Core.Connection.Connection[]]
    `${SCSession},

    [ValidateNotNullOrEmpty()]
    [System.String[]]
    `${ComputerName},
    
    [System.Management.Automation.PSCredential]
    `${Credential}
    )
    
    process {
        `$managementGroupParameters = @{} + `$psBoundParameters
        foreach (`$k in @(`$managementGroupParameters.Keys)) {
            if ('SCSession', 'ComputerName', 'Credential' -notcontains `$k) {
                `$null = `$managementGroupParameters.Remove(`$k)
            }
        }
        
        `$Group = Get-SCOMManagementGroup @managementGroupParameters
        `$connection = [Microsoft.SystemCenter.OperationsManagerV10.Commands.OMV10Utility]::GetConnectionForManagementGroup(`$Group)        
        # Use `$group to work with the SCOM API: http://msdn.microsoft.com/en-us/library/microsoft.enterprisemanagement.managementgroup.aspx
    }
}
"@
        } else {
@"
param(
[ValidateNotNullOrEmpty()]
[Microsoft.SystemCenter.Core.Connection.Connection[]]
`${SCSession},

[ValidateNotNullOrEmpty()]
[System.String[]]
`${ComputerName},

[System.Management.Automation.PSCredential]
`${Credential}
)

`$managementGroupParameters = @{} + `$psBoundParameters
foreach (`$k in @(`$managementGroupParameters.Keys)) {
    if ('SCSession', 'ComputerName', 'Credential' -notcontains `$k) {
        `$null = `$managementGroupParameters.Remove(`$k)
    }
}

`$Group = Get-SCOMManagementGroup @managementGroupParameters
`$connection = [Microsoft.SystemCenter.OperationsManagerV10.Commands.OMV10Utility]::GetConnectionForManagementGroup(`$Group)        
# Use `$group to work with the SCOM API: http://msdn.microsoft.com/en-us/library/microsoft.enterprisemanagement.managementgroup.aspx
"@
        }
    }
}

# .ExternalHelp Microsoft.SystemCenter.OperationsManagerV10.Commands.dll-Help.xml
function Add-SCOMRunAsAccount
{
    [CmdletBinding(DefaultParameterSetName='Windows', SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param(

    [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName = 'Windows')]
    [Switch]
    ${Windows},

    [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName = 'CommunityString')]
    [Switch]
    ${CommunityString},

    [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName = 'Basic')]
    [Switch]
    ${Basic},

    [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName = 'Digest')]
    [Switch]
    ${Digest},

    [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName = 'Simple')]
    [Switch]
    ${Simple},

    [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName = 'ActionAccount')]
    [Switch]
    ${ActionAccount},

    [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName = 'Binary')]
    [Switch]
    ${Binary},

    [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName = 'SnmpV3')]
    [Switch]
    ${SnmpV3},

    [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName = 'SCXMonitoring')]
    [Switch]
    ${SCXMonitoring},

    [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName = 'SCXMaintenanceSSHKeyPriv')]
    [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName = 'SCXMaintenanceSSHKeyNoPrivSudo')]
    [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName = 'SCXMaintenanceSSHKeyNoPrivSu')]
    [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName = 'SCXMaintenanceUserPassPriv')]
    [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName = 'SCXMaintenanceUserPassNoPrivSudo')]
    [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName = 'SCXMaintenanceUserPassNoPrivSu')]
    [Switch]
    ${SCXMaintenance},

    [Parameter(Mandatory=$true, Position=0, ValueFromPipelineByPropertyName=$true)]
    [Alias('DisplayName')]
    [ValidateNotNullOrEmpty()]
    [System.String]
    ${Name},

    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [System.String]
    ${Description},

    [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true, ParameterSetName='Windows')]
    [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true, ParameterSetName='Basic')]
    [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true, ParameterSetName='Simple')]
    [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true, ParameterSetName='Digest')]
    [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true, ParameterSetName='ActionAccount')]
    [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true, ParameterSetName='SCXMonitoring')]
    [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true, ParameterSetName='SCXMaintenanceUserPassPriv')]
    [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true, ParameterSetName='SCXMaintenanceUserPassNoPrivSudo')]
    [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true, ParameterSetName='SCXMaintenanceUserPassNoPrivSu')]
    [Alias('User')]
    [ValidateNotNullOrEmpty()]
    [System.Management.Automation.PSCredential]
    ${RunAsCredential},

    [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true, ParameterSetName='Binary')]
    [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true, ParameterSetName='SCXMaintenanceSSHKeyPriv')]
    [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true, ParameterSetName='SCXMaintenanceSSHKeyNoPrivSudo')]
    [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true, ParameterSetName='SCXMaintenanceSSHKeyNoPrivSu')]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ $executionContext.SessionState.Path.GetResolvedPSPathFromPSPath($_) })]
    [System.String]
    ${Path},

    [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true, ParameterSetName='CommunityString')]
    [ValidateNotNullOrEmpty()]
    [System.Security.SecureString]
    ${String},

    [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true, ParameterSetName='SnmpV3')]
    [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true, ParameterSetName='SCXMaintenanceSSHKeyPriv')]
    [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true, ParameterSetName='SCXMaintenanceSSHKeyNoPrivSudo')]
    [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true, ParameterSetName='SCXMaintenanceSSHKeyNoPrivSu')]
    [ValidateNotNullOrEmpty()]
    [System.String]
    ${UserName},
    
    [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName='SnmpV3')]
    [ValidateNotNullOrEmpty()]
    [System.Management.Automation.PSCredential]
    ${AuthProtocolAndKey},

    [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName='SnmpV3')]
    [ValidateNotNullOrEmpty()]
    [System.Management.Automation.PSCredential]
    ${PrivacyProtocolAndKey},

    [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName='SnmpV3')]
    [ValidateNotNullOrEmpty()]
    [System.String]
    ${Context},

    [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName='SCXMaintenanceSSHKeyPriv')]
    [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName='SCXMaintenanceSSHKeyNoPrivSudo')]
    [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName='SCXMaintenanceSSHKeyNoPrivSu')]
    [ValidateNotNullOrEmpty()]
    [System.Security.SecureString]
    ${Passphrase} = (new-object System.Security.SecureString),

    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName=$true, ParameterSetName='SCXMaintenanceSSHKeyPriv')]
    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName=$true, ParameterSetName='SCXMaintenanceUserPassPriv')]
    [Switch]
    ${Privileged},

    [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName='SCXMonitoring')]
    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName=$true, ParameterSetName='SCXMaintenanceSSHKeyNoPrivSudo')]
    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName=$true, ParameterSetName='SCXMaintenanceUserPassNoPrivSudo')]
    [Switch]
    ${Sudo},

    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName=$true, ParameterSetName='SCXMaintenanceSSHKeyNoPrivSu')]
    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName=$true, ParameterSetName='SCXMaintenanceUserPassNoPrivSu')]
    [Switch]
    ${Su},

    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName=$true, ParameterSetName='SCXMaintenanceSSHKeyNoPrivSu')]
    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName=$true, ParameterSetName='SCXMaintenanceUserPassNoPrivSu')]
    [ValidateNotNullOrEmpty()]
    [System.Security.SecureString]
    ${SuPassword},

    [ValidateNotNullOrEmpty()]
    [Microsoft.SystemCenter.Core.Connection.Connection[]]
    ${SCSession},

    [ValidateNotNullOrEmpty()]
    [System.String[]]
    ${ComputerName},
    
    [System.Management.Automation.PSCredential]
    ${Credential}
    )

    begin
    {
        $MaintenanceFactory = [Microsoft.SystemCenter.CrossPlatform.ClientLibrary.CredentialManagement.MaintenanceRunAsAccount]::MaintenanceAuthenticationDataFactory
        $MonitoringFactory = [Microsoft.SystemCenter.CrossPlatform.ClientLibrary.CredentialManagement.MonitorRunAsAccount]::MonitorAuthenticationDataFactory
    }    
    process
    {
        $managementGroupParameters = @{} + $psBoundParameters
        foreach ($k in @($managementGroupParameters.Keys))
        {
            if ('SCSession', 'ComputerName', 'Credential' -notcontains $k)
            {
                $null = $managementGroupParameters.Remove($k)
            }
        }

        $Group = Get-SCOMManagementGroup @managementGroupParameters
        $connection = [Microsoft.SystemCenter.OperationsManagerV10.Commands.OMV10Utility]::GetConnectionForManagementGroup($Group)

        if (-not $psCmdlet.ShouldProcess($Name))
        {
            return
        }
        
        if (-not $psBoundParameters.description)
        {
            $description = $name 
        }

        $accountProperties = @{
                Name = $name
                Description = $Description
            }

        $networkCredential = $null
        $typeName = $null

        if($psBoundParameters.ContainsKey("RunAsCredential"))
        {
            $networkCredential = $RunAsCredential.GetNetworkCredential()
            $accountProperties.UserName = $networkCredential.UserName
            $accountProperties.Data = $RunAsCredential.Password
        }

        $errorActionPreference = 'Stop'
        try
        {
            $accountData = $null

            # standard scom accounts
            if($psCmdlet.ParameterSetName -notlike 'SCX*')
            {
                switch ($psCmdlet.ParameterSetName)
                {
                    'Windows'
                    {
                       $typeName = 'WindowsCredentialSecureData'
                       if( $networkCredential.Domain)
                       {
                          $accountProperties.Domain = $networkCredential.Domain
                       }
                    }
                    'Basic' {$typeName = 'BasicCredentialSecureData'}
                    'Simple'{$typeName = 'SimpleCredentialSecureData'}
                    'Digest'{$typeName = 'DigestCredentialSecureData'}
                    'ActionAccount'
                    {
                       $typeName = 'ActionAccountSecureData'
                       if( $networkCredential.Domain)
                       {
                          $accountProperties.Domain = $networkCredential.Domain
                       }
                    }
                    'Binary'
                    {
                       $typeName = 'GenericSecureData'
                       $data = new-object System.Security.SecureString
                       $binPath = $psCmdlet.GetUnresolvedProviderPathFromPSPath($Path)
                       [byte[]]$bytes = [System.IO.File]::ReadAllBytes($binPath)
                       $encoded = [System.Convert]::ToBase64String($bytes)
                       $encoded.ToCharArray() |%{ $data.AppendChar($_) }
                       $accountProperties.Data = $data
                    }
                    'CommunityString'
                    {
                       $typeName = 'CommunityStringSecureData'
                       $accountProperties.Data = $String
                    }
                    'SnmpV3'
                    {
                       $typeName = 'SnmpV3SecureData'
                       $accountProperties.UserName = $UserName
                       $accountProperties.AuthenticationProtocol = 'None'
                       $accountProperties.AuthenticationKey = (new-object System.Security.SecureString)
                       $accountProperties.PrivacyProtocol = 'None'
                       $accountProperties.PrivacyKey = (new-object System.Security.SecureString)

                       if($psBoundParameters.ContainsKey("AuthProtocolAndKey"))
                       {
                          $accountProperties.AuthenticationProtocol = [Microsoft.EnterpriseManagement.Security.SnmpV3AuthenticationFunction] $AuthProtocolAndKey.GetNetworkCredential().UserName
                          $accountProperties.AuthenticationKey = $AuthProtocolAndKey.Password
              
                          if($psBoundParameters.ContainsKey("PrivacyProtocolAndKey"))
                          {
                             $accountProperties.PrivacyProtocol = [Microsoft.EnterpriseManagement.Security.SnmpV3EncryptionAlgorithm ]$PrivacyProtocolAndKey.GetNetworkCredential().UserName
                             $accountProperties.PrivacyKey = $PrivacyProtocolAndKey.Password
                          }
                       }
           
                       if($psBoundParameters.ContainsKey('Context'))
                       {
                           $accountProperties.ContextName = $Context 
                       }
                    }
                }
         
                $accountData = New-Object "Microsoft.EnterpriseManagement.Security.${typeName}" -Property $accountProperties
                Write-Debug 'Inserting Account Data'
                $Group.Security.insertSecureData($accountdata)
                $accountData = $Group.Security.GetSecureData($accountData.Id) | Add-Member -Name 'AccountType' -Value "SCOM${typeName}" -MemberType NoteProperty -PassThru
                              
            }
            # x-plat accounts
            else
            {
                $accountData = $null
                if($psCmdlet.ParameterSetName -eq 'SCXMonitoring')
                {
                    $authenticationData = $MonitoringFactory.Invoke($RunAsCredential.Password, $Sudo.IsPresent)
                    $AccountData = 
                    [Microsoft.SystemCenter.CrossPlatform.ClientLibrary.CredentialManagement.CmdletSupport]::NewMonitorAccount($Connection, $Name, $Description, 
                        $networkCredential.Username, $authenticationData, [guid[]]@())
                }
                elseif ($psCmdlet.ParameterSetName -like 'SCXMaintenance*')
                {
                    Write-Debug 'Creating Maintenance Account Data'
                    $keyFile = $null
                    if($psCmdlet.ParameterSetName -like '*SSHKey*')
                    {
                       $keyFile = $psCmdlet.GetUnresolvedProviderPathFromPSPath($Path) | select -last 1
                    }

                    $authenticationData = 
                        switch($psCmdlet.ParameterSetName)
                        {
                           'SCXMaintenanceSSHKeyPriv'
                           {
                               $MaintenanceFactory.Invoke($keyFile, $PassPhrase, $false)
                           }
                           'SCXMaintenanceSSHKeyNoPrivSudo'
                           {
                               $MaintenanceFactory.Invoke($keyFile, $PassPhrase, $true)
                           }
                           'SCXMaintenanceSSHKeyNoPrivSu'
                           {
                               $MaintenanceFactory.Invoke($keyFile, $PassPhrase, $SuPassword)
                           }
                           'SCXMaintenanceUserPassPriv'
                           {
                               $MaintenanceFactory.Invoke($RunAsCredential.Password, $false)
                           }
                           'SCXMaintenanceUserPassNoPrivSudo'
                           {
                               $MaintenanceFactory.Invoke($RunAsCredential.Password, $true)
                           }
                           'SCXMaintenanceUserPassNoPrivSu'
                           {
                              $MaintenanceFactory.Invoke($RunAsCredential.Password, $SuPassword)
                           }
                        }


                    $AccountData = 
                       [Microsoft.SystemCenter.CrossPlatform.ClientLibrary.CredentialManagement.CmdletSupport]::NewMaintenanceAccount($Connection, $Name, $Description, 
                          $networkCredential.Username, $authenticationData, [guid[]]@())        
                }
                       
            }

            $accountData
        }
        catch
        {
           Write-Error $_
        }       
    }
}

# .ExternalHelp Microsoft.SystemCenter.OperationsManagerV10.Commands.dll-Help.xml
function Update-SCOMRunAsAccount 
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(   
       [Parameter(ValueFromPipeline=$true, Position=0, Mandatory=$true, ParameterSetName='WindowsAccount')]
       [ValidateNotNullOrEmpty()]
       [Microsoft.EnterpriseManagement.Security.WindowsCredentialSecureData]
       $WindowsAccount,
       
       [Parameter(ValueFromPipeline=$true, Position=0, Mandatory=$true, ParameterSetName='BasicAccount')]
       [ValidateNotNullOrEmpty()]
       [Microsoft.EnterpriseManagement.Security.BasicCredentialSecureData]
       $BasicAccount,
       
       [Parameter(ValueFromPipeline=$true, Position=0, Mandatory=$true, ParameterSetName='SimpleAccount')]
       [ValidateNotNullOrEmpty()]
       [Microsoft.EnterpriseManagement.Security.SimpleCredentialSecureData]
       $SimpleAccount,
       
       [Parameter(ValueFromPipeline=$true, Position=0, Mandatory=$true, ParameterSetName='DigestAccount')]
       [ValidateNotNullOrEmpty()]
       [Microsoft.EnterpriseManagement.Security.SimpleCredentialSecureData]
       $DigestAccount,
       
       [Parameter(ValueFromPipeline=$true, Position=0, Mandatory=$true, ParameterSetName='ActionAccount')]
       [ValidateNotNullOrEmpty()]
       [Microsoft.EnterpriseManagement.Security.ActionAccountSecureData]
       $ActionAccount,
       
       [Parameter(ValueFromPipeline=$true, Position=0, Mandatory=$true, ParameterSetName='CommunityStringAccount')]
       [ValidateNotNullOrEmpty()]
       [Microsoft.EnterpriseManagement.Security.CommunityStringSecureData]
       $CommunityStringAccount,
       
       [Parameter(ValueFromPipeline=$true, Position=0, Mandatory=$true, ParameterSetName='BinaryAccount')]
       [ValidateNotNullOrEmpty()]
       [Microsoft.EnterpriseManagement.Security.GenericSecureData]
       $BinaryAccount,

       [Parameter(Mandatory=$true, Position=1, ParameterSetName='WindowsAccount')]
       [Parameter(Mandatory=$true, Position=1, ParameterSetName='BasicAccount')]
       [Parameter(Mandatory=$true, Position=1, ParameterSetName='SimpleAccount')]
       [Parameter(Mandatory=$true, Position=1, ParameterSetName='DigestAccount')]
       [Parameter(Mandatory=$true, Position=1, ParameterSetName='ActionAccount')]
       [ValidateNotNullOrEmpty()]
       [System.Management.Automation.PSCredential]
       ${RunAsCredential},
       
       [Parameter(Mandatory=$true, Position=1, ParameterSetName='CommunityStringAccount')]
       [ValidateNotNullOrEmpty()]
       [System.Security.SecureString]
       ${CommunityString},

       [Parameter(Mandatory=$true, Position=1, ParameterSetName='BinaryAccount')]
       [ValidateNotNullOrEmpty()]
       [ValidateScript({ $executionContext.SessionState.Path.GetResolvedPSPathFromPSPath($_) })]
       [System.String]
       ${Path},

       [Parameter(ValueFromPipelineByPropertyName=$true)]
       [ValidateScript({$_ -notlike "SCX*"})]
       [string]
       $AccountType,
       
       [Parameter()]
       [switch]
       $PassThru,
       
       [ValidateNotNullOrEmpty()]
       [Microsoft.SystemCenter.Core.Connection.Connection[]]
       ${SCSession},

       [ValidateNotNullOrEmpty()]
       [System.String[]]
       ${ComputerName},

       [ValidateNotNullOrEmpty()]
       [System.Management.Automation.PSCredential]
       ${Credential}
    )

    process {
        
        $runAsAccount = Get-Variable $psCmdlet.ParameterSetName -ValueOnly
        
        if($psCmdlet.ShouldProcess($runAsAccount.Name))
        {
        
           if ($psCmdlet.ParameterSetName -eq 'BinaryAccount')
           {
               $data = new-object System.Security.SecureString
               $binPath = $psCmdlet.GetUnresolvedProviderPathFromPSPath($Path)
               [byte[]]$bytes = [System.IO.File]::ReadAllBytes($binPath)
               $encoded = [System.Convert]::ToBase64String($bytes)
               foreach($_ in $encoded.ToCharArray()) { $data.AppendChar($_) }
               $runAsAccount.Data = $data
           } 
           elseif ($psCmdlet.ParameterSetName -eq 'CommunityStringAccount')
           {
               $runAsAccount.Data = $CommunityString
           }
           else
           {
              $networkCredential = $runAsCredential.GetNetworkCredential()
              $runAsAccount.UserName = $networkCredential.UserName
              $runAsAccount.Data = $runAsCredential.Password
              
              if('WindowsAccount','ActionAccount' -contains $psCmdlet.ParameterSetName)
              {
                  if($networkCredential.Domain)
                  {
                    $runAsAccount.Domain = $networkCredential.Domain
                  }
              }
           }
                       
           $runAsAccount.Update()
           
           if($PassThru)
           {
              $runAsAccount
           }
        }
    }
} 


# .ExternalHelp Microsoft.SystemCenter.OperationsManagerV10.Commands.dll-Help.xml
function Get-SCOMRunAsAccount
{
    [CmdletBinding(DefaultParametersetName='EmptyParameterSet')]
    param(
    [Parameter(ParameterSetName='FromRunAsAccountName', Mandatory=$true, Position=0, ValueFromPipeline=$true)]
    [System.String[]]
    ${Name},

    [Parameter(ParameterSetName='FromId', Mandatory=$true, ValueFromPipeline=$true)]
    [System.Guid[]]
    ${Id},

    [ValidateNotNullOrEmpty()]
    [Microsoft.SystemCenter.Core.Connection.Connection[]]
    ${SCSession},

    [ValidateNotNullOrEmpty()]
    [System.String[]]
    ${ComputerName},

    [ValidateNotNullOrEmpty()]
    [System.Management.Automation.PSCredential]
    ${Credential})
    
    process
    {
        $managementGroupParameters = @{} + $psBoundParameters
        foreach ($k in @($managementGroupParameters.Keys))
        {
            if ('SCSession', 'ComputerName', 'Credential' -notcontains $k)
            {
                $null = $managementGroupParameters.Remove($k)
            }
        }

        $Group=  Get-SCOMManagementGroup @managementGroupParameters
        $connection = [Microsoft.SystemCenter.OperationsManagerV10.Commands.OMV10Utility]::GetConnectionForManagementGroup($Group)
        
        $refs = @(if ($psBoundParameters.ContainsKey("Name"))
                {
                   foreach ($ref in $Group.Security.GetSecureData())
                   {
                      foreach($nameWildCard in $name)
                      {
                         if ($Ref.Name -like $nameWildCard)
                         {
                            $ref
                         }
                      }
                   }
                } 
                elseif ($psBoundParameters.ContainsKey("Id"))
                {
                     foreach($refId in $id)
                     {
                         $Group.Security.GetSecureData($refId)
                     }
                }
                else
                {
                    $Group.Security.GetSecureData()
                }
              )
        foreach($ref in $refs)
        {
           $unixRunAs = try {  [Microsoft.SystemCenter.CrossPlatform.ClientLibrary.CredentialManagement.CmdletSupport]::GetScxRunAsAccount($connection, $ref.Id) }
                        catch { }

           $accoutType = ''  
                     
           if ($unixRunAs)
           { 
               $accountType = 'SCX' + $unixRunAs.GetType().Name
           }
           else
           {
               $accountType = 'SCOM' + $ref.GetType().Name
           }
           
           Add-Member -InputObject $ref -Name 'AccountType' -Value $accountType -MemberType NoteProperty -PassThru
        }     
    }
}

# .ExternalHelp Microsoft.SystemCenter.OperationsManagerV10.Commands.dll-Help.xml
function Remove-SCOMRunAsAccount
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
    [Parameter(ValueFromPipeline=$true,Position=0,Mandatory=$true)]
    [Microsoft.EnterpriseManagement.Security.SecureData[]]
    $RunAsAccount,
    
    [ValidateNotNullOrEmpty()]
    [Microsoft.SystemCenter.Core.Connection.Connection[]]
    ${SCSession},

    [ValidateNotNullOrEmpty()]
    [System.String[]]
    ${ComputerName},

    [ValidateNotNullOrEmpty()]
    [System.Management.Automation.PSCredential]
    ${Credential})
    
    process
    {
        $managementGroupParameters = @{} + $psBoundParameters
        foreach ($k in @($managementGroupParameters.Keys))
        {
            if ('SCSession', 'ComputerName', 'Credential' -notcontains $k)
            {
                $null = $managementGroupParameters.Remove($k)
            }
        }

        $Group=  Get-SCOMManagementGroup @managementGroupParameters
        $connection = [Microsoft.SystemCenter.OperationsManagerV10.Commands.OMV10Utility]::GetConnectionForManagementGroup($Group)

        foreach($account in $RunAsAccount)
        {
           if ($psCmdlet.ShouldProcess($account.Name))
           {
               $unixRunAs = try {  [Microsoft.SystemCenter.CrossPlatform.ClientLibrary.CredentialManagement.CmdletSupport]::GetScxRunAsAccount($connection, $account.Id) }
                            catch { }
               if ($unixRunAs)
               {
                  [Microsoft.SystemCenter.CrossPlatform.ClientLibrary.CredentialManagement.CmdletSupport]::RemoveScxRunAsAccount($connection, $account.Id)    
               }
               else
               {
                  $Group.Security.DeleteSecureData($account)
               }
           }
        }        
    }
}

# .ExternalHelp Microsoft.SystemCenter.OperationsManagerV10.Commands.dll-Help.xml
function Get-SCOMRunAsDistribution
{
    param(   
       [Parameter(ValueFromPipeline=$true,Position=0,Mandatory=$true)]
       [ValidateNotNullOrEmpty()]
       [Microsoft.EnterpriseManagement.Security.SecureData[]]
       $RunAsAccount,
       
       [ValidateNotNullOrEmpty()]
       [Microsoft.SystemCenter.Core.Connection.Connection[]]
       ${SCSession},

       [ValidateNotNullOrEmpty()]
       [System.String[]]
       ${ComputerName},

       [ValidateNotNullOrEmpty()]
       [System.Management.Automation.PSCredential]
       ${Credential}
    )

   process
   {
      foreach($runAs in $runAsAccount)
      {
         $group = $runAs.ManagementGroup
         $lessSecure = $true
         [Microsoft.EnterpriseManagement.Monitoring.MonitoringObject[]] $distributionList =
                    [Microsoft.SystemCenter.OperationsManagerV10.Commands.OMV10Utility]::GetSecureDistribution($runAs, [ref] $lessSecure)

         $security  = if($lessSecure){'LessSecure'}else{'MoreSecure'}
          new-object psobject -prop @{
                                       Security = $security
                                       SecureDistribution = $distributionList
                                       RunAsAccount = $runAs
                                     }
       }
   }    
}

# .ExternalHelp Microsoft.SystemCenter.OperationsManagerV10.Commands.dll-Help.xml
function Set-SCOMRunAsDistribution
{

    [CmdletBinding(SupportsShouldProcess = $true)]
    param(   
       [Parameter(ValueFromPipeline=$true,Position=0,Mandatory=$true)]
       [ValidateNotNullOrEmpty()]
       [Microsoft.EnterpriseManagement.Security.SecureData]
       $RunAsAccount,
       
       [Parameter(Mandatory = $true, ParameterSetname = 'LessSecure')]
       [switch]
       $LessSecure,
       
       [Parameter(Mandatory = $true, ParameterSetname = 'MoreSecure')]
       [switch]
       $MoreSecure,

       [Parameter(Mandatory = $true, ParameterSetName = 'Security', ValueFromPipelineByPropertyName = $true)]
       [ValidateSet('MoreSecure', 'LessSecure')]
       [string]
       $Security,
       
       [Parameter(ParameterSetname = 'MoreSecure', ValueFromPipelineByPropertyName = $true)]
       [Parameter(ParameterSetname = 'Security', ValueFromPipelineByPropertyName = $true)]
       [ValidateNotNull()]
       [Object[]]
       $SecureDistribution,
       
       [switch]
       $PassThru,    
       
       [ValidateNotNullOrEmpty()]
       [Microsoft.SystemCenter.Core.Connection.Connection[]]
       ${SCSession},

       [ValidateNotNullOrEmpty()]
       [System.String[]]
       ${ComputerName},

       [ValidateNotNullOrEmpty()]
       [System.Management.Automation.PSCredential]
       ${Credential}
    )

   process {

        $Group=  $runAsAccount.ManagementGroup
        $connection = [Microsoft.SystemCenter.OperationsManagerV10.Commands.OMV10Utility]::GetConnectionForManagementGroup($Group)

        $hsClass = $group.EntityTypes.GetClasses("Name = 'Microsoft.SystemCenter.Healthservice'") |%{ $_ }
        $poolClass = $group.EntityTypes.GetClasses("Name = 'Microsoft.SystemCenter.ManagementServicePool'") |%{ $_ }

        [Microsoft.EnterpriseManagement.Monitoring.MonitoringObject[]] $distributionList = @()
        if($MoreSecure -or ($Security -eq 'MoreSecure'))
        {
           foreach($o in $SecureDistribution)
           {
               if($destination = ($o -as [Microsoft.EnterpriseManagement.Administration.AgentManagedComputer]))
               {
                  $distributionList += $destination.HostedHealthservice
               }
               elseif($destination = ($o -as [Microsoft.EnterpriseManagement.Administration.ManagementServer]))
               {
                  $distributionList += $destination.HostedHealthservice
               }
               elseif($destination = ($o -as [Microsoft.EnterpriseManagement.Administration.ManagementServicePool]))
               {
                  $distributionList += ( Get-SCOMClassInstance -Id $destination.Id -ScSession $connection )
               }
               elseif(($destination = ($o -as [Microsoft.EnterpriseManagement.Monitoring.MonitoringObject])) -and
                       ($destination.IsInstanceOf($hsClass) -or $destination.IsInstanceOf($poolClass)))
               {
                  $distributionList += $destination
               }
               else
               {
                  # write some error
               }
           }
        }
        elseif($LessSecure -or ($Security -eq 'LessSecure'))
        {
           $distributionList = $null
        }

        if($psCmdlet.ShouldProcess($RunAsAccount.Name))
        {
           [Microsoft.SystemCenter.OperationsManagerV10.Commands.OMV10Utility]::ApproveRunasAccountForDistribution($Group, $runAsAccount, $distributionList)

            if($PassThru)
            {
               $runAsAccount                              
            }
        }        
    }    
}

# .ExternalHelp Microsoft.SystemCenter.OperationsManagerV10.Commands.dll-Help.xml
function Get-SCOMTieredManagementGroup
{
    [CmdletBinding(DefaultParameterSetName='Empty', SupportsShouldProcess = $true)]
    param(    
       [Parameter(Mandatory = $true, Position = 0, ParameterSetname = 'Name')]
       [String[]] $Name,
       
       [Parameter(Mandatory = $true, ParameterSetname = 'Id')]
       [Guid[]] $Id,    
           
       [Parameter(ParameterSetname = 'Empty')]
       [Switch]$OnlyForConnector,
       
       [ValidateNotNullOrEmpty()]
       [Microsoft.SystemCenter.Core.Connection.Connection[]]
       ${SCSession},

       [ValidateNotNullOrEmpty()]
       [System.String[]]
       ${ComputerName},

       [ValidateNotNullOrEmpty()]
       [System.Management.Automation.PSCredential]
       ${Credential}
    )
    
    process {
    
        $managementGroupParameters = @{} + $psBoundParameters
        foreach ($k in @($managementGroupParameters.Keys)) {
            if ('SCSession', 'ComputerName', 'Credential' -notcontains $k) {
                $null = $managementGroupParameters.Remove($k)
            }
        }
        $Group=  Get-SCOMManagementGroup @managementGroupParameters
        
        if($pscmdlet.ParameterSetname -eq 'Empty')
        {
           if (-not $onlyForConnector) {        
               $group.Tiering.GetTiers()  
           } else {
               $group.Tiering.GetTiersForConnectors()
           }
        }
        elseif($pscmdlet.ParameterSetname -eq 'Name')
        {
           foreach($tier in $group.Tiering.GetTiers())
           {
              foreach($tierName in $Name)
              {
                 if($tier.Name -like $tierName)
                 {
                    $tier
                 }
              }
           }           
        }
        elseif($pscmdlet.ParameterSetname -eq 'Id')
        {
           foreach($tier in $group.Tiering.GetTiers())
           {
              foreach($tierId in $id)
              {
                 if($tier.Id -eq $tierId)
                 {
                    $tier
                 }
              }
           }
        }
    }
}

# .ExternalHelp Microsoft.SystemCenter.OperationsManagerV10.Commands.dll-Help.xml
function Add-SCOMTieredManagementGroup
{
    [CmdletBinding(DefaultParameterSetName='SimpleAccountTier', SupportsShouldProcess = $true)]
    param(
       [Parameter(Mandatory=$true)]
       [String]$Name,
       
       [Parameter(Mandatory=$true)]
       [String]$ServerName,
       
       [Parameter(Mandatory=$true)]
       [System.Management.Automation.PSCredential] $ConnectionCredential,
       
       [Timespan]$InactivityTimeout = "1:0:0",
       
       [Timespan]$SendReceiveTimeout = "0:30:0",
       
       [Microsoft.EnterpriseManagement.Common.CacheMode]$CacheMode,
       
       [Microsoft.EnterpriseManagement.Common.CacheConfiguration]$CacheConfiguration,
       
       [Parameter(Mandatory=$true,ParameterSetName='RunAsAccountTier')]
       [Microsoft.EnterpriseManagement.Security.WindowsCredentialSecureData]$RunAsAccount,
       
       [Parameter(ParameterSetName='RunAsAccountTier')]
       [Switch]$AvailableForConnectors,
       
       [ValidateNotNullOrEmpty()]
       [Microsoft.SystemCenter.Core.Connection.Connection[]]
       ${SCSession},

       [ValidateNotNullOrEmpty()]
       [System.String[]]
       ${ComputerName},

       [ValidateNotNullOrEmpty()]
       [System.Management.Automation.PSCredential]
       ${Credential}
    )
    
    process {
        $managementGroupParameters = @{} + $psBoundParameters
        foreach ($k in @($managementGroupParameters.Keys)) {
            if ('SCSession', 'ComputerName', 'Credential' -notcontains $k) {
                $null = $managementGroupParameters.Remove($k)
            }
        }
        $Group=  Get-SCOMManagementGroup @managementGroupParameters
        
        $netCred = $connectionCredential.GetNetworkCredential()
   
        $props = @{} + $psBoundParameters
        $null = $props.Remove('AvailableForConnectors')
        $null = $props.Remove('RunAsAccount')
        $null = $props.Remove('Name')
        $null = $props.Remove('ServerName')
        $null = $props.Remove('SCSession')
        $null = $props.Remove('ComputerName')
        $null = $props.Remove('Credential')
        $null = $props.Remove('ConnectionCredential')
        $props.Add('UserName', $netCred.UserName)
        $props.Add('Domain', $netCred.Domain)
        $props.Add('Password', $connectionCredential.Password)
        
        $newTier = New-Object Microsoft.EnterpriseManagement.ManagementGroupConnectionSettings $ServerName -Property $props
        
        if($pscmdlet.ShouldProcess($name))
        {
           if ($RunAsAccount) {
               $group.Tiering.AddTier($name, $newTier, $RunAsAccount, $AvailableForConnectors)
           } else {
               $group.Tiering.AddTier($name, $newTier)
           }
        }
    }
}

# .ExternalHelp Microsoft.SystemCenter.OperationsManagerV10.Commands.dll-Help.xml
function Remove-SCOMTieredManagementGroup
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
       [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
       [ValidateNotNullOrEmpty()]
       [Microsoft.EnterpriseManagement.Tiering.TieredManagementGroup[]]
       $Tier,
       
       [ValidateNotNullOrEmpty()]
       [Microsoft.SystemCenter.Core.Connection.Connection[]]
       ${SCSession},

       [ValidateNotNullOrEmpty()]
       [System.String[]]
       ${ComputerName},

       [ValidateNotNullOrEmpty()]
       [System.Management.Automation.PSCredential]
       ${Credential}        
    )
    
    process {
        $managementGroupParameters = @{} + $psBoundParameters
        foreach ($k in @($managementGroupParameters.Keys)) {
            if ('SCSession', 'ComputerName', 'Credential' -notcontains $k) {
                $null = $managementGroupParameters.Remove($k)
            }
        }
        $Group=  Get-SCOMManagementGroup @managementGroupParameters
        
        foreach($tmg in $tier)
        {
           if ($pscmdlet.ShouldProcess($tmg.Name)) {        
               $group.Tiering.RemoveTier($tmg)
           }
        }
    }
}

# .ExternalHelp Microsoft.SystemCenter.OperationsManagerV10.Commands.dll-Help.xml
function Get-SCOMTierConnector
{
    [CmdletBinding(DefaultParameterSetName = 'Empty')]
    param(
       [Parameter(Mandatory=$true, ParameterSetName = 'Name')]
       [ValidateNotNullOrEmpty()]
       [string[]]
       $Name,
       
       [Parameter(Mandatory=$true, Position = 0, ParameterSetName = 'DisplayName')]
       [ValidateNotNullOrEmpty()]
       [string[]]
       $DisplayName,
    
       [Parameter(Mandatory=$true, ParameterSetName = 'Id')]
       [ValidateNotNullOrEmpty()]
       [Guid[]]
       $Id,
       
       [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
       [ValidateNotNullOrEmpty()]
       [Microsoft.EnterpriseManagement.Tiering.TieredManagementGroup]
       $Tier,
       
       [ValidateNotNullOrEmpty()]
       [Microsoft.SystemCenter.Core.Connection.Connection[]]
       ${SCSession},

       [ValidateNotNullOrEmpty()]
       [System.String[]]
       ${ComputerName},

       [ValidateNotNullOrEmpty()]
       [System.Management.Automation.PSCredential]
       ${Credential}        
    )
    
    process {
       $errorActionPreference = 'Stop'
       try
       {
            $settings = New-Object Microsoft.EnterpriseManagement.TieredManagementGroupConnectionSettings
            $settings.ConnectForConnector = $true
            $settings.CacheMode = 'None'
            
            $mg = $tier.Connect($settings)
            
            if($pscmdlet.ParameterSetName -eq 'Empty')
            {
               $mg.ConnectorFramework.GetConnectors()
            }
            elseif($psCmdlet.ParameterSetName -eq 'Name')
            {
               foreach($connector in $mg.ConnectorFramework.GetConnectors())
               {
                  foreach($connName in $Name)
                  {
                     if($connector.Name -like $connName)
                     {
                        $connector
                     }
                  }
               }
            }
            elseif($psCmdlet.ParameterSetName -eq 'DisplayName')
            {
               foreach($connector in $mg.ConnectorFramework.GetConnectors())
               {
                  foreach($connName in $DisplayName)
                  {
                     if($connector.DisplayName -like $connName)
                     {
                        $connector
                     }
                  }
               }
            }
            elseif($psCmdlet.ParameterSetName -eq 'Id')
            {
               foreach($connector in $mg.ConnectorFramework.GetConnectors())
               {
                  foreach($connId in $Id)
                  {
                     if($connector.Id -eq $connId)
                     {
                        $connector
                     }
                  }
               }
            }            
        }
        catch
        {
           Write-Error $_
        }         
    }
}

# .ExternalHelp Microsoft.SystemCenter.OperationsManagerV10.Commands.dll-Help.xml
function Add-SCOMTierConnector
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
       [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
       [ValidateNotNullOrEmpty()]
       [Microsoft.EnterpriseManagement.ConnectorFramework.MonitoringConnector]
       $Connector,
    
       [Parameter(Mandatory=$true)]
       [ValidateNotNullOrEmpty()]
       [ValidateScript( {$_.IsAvailableForConnectors} )]
       [Microsoft.EnterpriseManagement.Tiering.TieredManagementGroup]
       $Tier,
       
       [switch] $PassThru,
       
       [ValidateNotNullOrEmpty()]
       [Microsoft.SystemCenter.Core.Connection.Connection[]]
       ${SCSession},

       [ValidateNotNullOrEmpty()]
       [System.String[]]
       ${ComputerName},

       [ValidateNotNullOrEmpty()]
       [System.Management.Automation.PSCredential]
       ${Credential}        
    )
    
    process {
       $errorActionPreference = 'Stop'
       try
       {
            $settings = New-Object Microsoft.EnterpriseManagement.TieredManagementGroupConnectionSettings
            $settings.ConnectForConnector = $true
            $settings.CacheMode = 'None'
            
            $mg = $tier.Connect($settings)
            
            $connectorInfo = new-object Microsoft.EnterpriseManagement.ConnectorFramework.ConnectorInfo
            $connectorInfo.Description = $connector.Description
            $connectorInfo.DiscoveryDataIsManaged = $connector.DiscoveryDataIsManaged
            $connectorInfo.DisplayName = $connector.DisplayName
            $connectorInfo.Name = $connector.Name
            
            if($psCmdlet.ShouldProcess($tier.Name))
            {   
              $tieredConnector = $mg.ConnectorFramework.Setup($connectorInfo, $connector.Id)
              
              if($passThru)
              {
                 $tieredConnector
              }        
            }
        }
        catch
        {
           Write-Error $_
        }         
    }
}

# .ExternalHelp Microsoft.SystemCenter.OperationsManagerV10.Commands.dll-Help.xml
function Remove-SCOMTierConnector
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
       [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
       [ValidateNotNullOrEmpty()]
       [Microsoft.EnterpriseManagement.ConnectorFramework.MonitoringConnector]
       $Connector,
    
       [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
       [ValidateNotNullOrEmpty()]
       [ValidateScript( {$_.IsAvailableForConnectors} )]
       [Microsoft.EnterpriseManagement.Tiering.TieredManagementGroup]
       $Tier,
       
       [ValidateNotNullOrEmpty()]
       [Microsoft.SystemCenter.Core.Connection.Connection[]]
       ${SCSession},

       [ValidateNotNullOrEmpty()]
       [System.String[]]
       ${ComputerName},

       [ValidateNotNullOrEmpty()]
       [System.Management.Automation.PSCredential]
       ${Credential}        
    )
    
    process { 
       $errorActionPreference = 'Stop'
       try
       {
            $settings = New-Object Microsoft.EnterpriseManagement.TieredManagementGroupConnectionSettings
            $settings.ConnectForConnector = $true
            $settings.CacheMode = 'None'
           
            $mg = $tier.Connect($settings)
           
            $tieredConnector = $mg.ConnectorFramework.GetConnector($connector.Id)
           
            if($psCmdlet.ShouldProcess($tier.Name))
            {     
              $mg.ConnectorFramework.Cleanup($tieredConnector)        
            }
        }
        catch
        {
           Write-Error $_
        }   
    }
}

Function Import-OperationsManager
{
<# 
 .Synopsis
  Load System Center Service Manager 2012 R2 SDK DLLs

 .Description
  Load System Center Service Manager 2012 R2 SDK DLLs from either the Global Assembly Cache or from the DLLs located in SMSDK PS module directory. It will use GAC if the DLLs are already loaded in GAC.

 .Example
  # Load System Center Service Manager 2012 R2 SDK DLLs
  Import-SMSDK

#>
    #SCSM 2012 R2 SDK DLLs
    $DLLPath = (Get-Module OperationsManager).ModuleBase
    $arrDLLs = @()
    $arrDLLs += 'Microsoft.EnterpriseManagement.Core.dll'
    $arrDLLs += 'Microsoft.EnterpriseManagement.OperationsManager.dll'
    $arrDLLs += 'Microsoft.EnterpriseManagement.Runtime.dll'
    $AssemblyVersion = '7.0.5000.0'
    $PublicKeyToken='31bf3856ad364e35'

    #Load SDKs
    $bSDKLoaded = $true
    Foreach ($DLL in $arrDLLs)
    {
        $AssemblyName = $DLL.TrimEnd('.dll')
        #try load from GAC first
        Try {
            Write-Verbose "Trying to load $AssemblyName from GAC..."
            [Void][System.Reflection.Assembly]::Load("$AssemblyName, Version=$AssemblyVersion, Culture=neutral, PublicKeyToken=$PublicKeyToken")
        } Catch {
            Write-Verbose "Unable to load $AssemblyName from GAC. Trying PowerShell module base folder..."
            #Can't load from GAC, now try PS module folder
            Try {
                $DLLFilePath = Join-Path $DLLPath $DLL
                [Void][System.Reflection.Assembly]::LoadFrom($DLLFilePath)
            } Catch {
                Write-Verbose "Unable to load $DLL from either GAC or the SMSDK Powershell Module base folder. Please verify if the SDK DLLs exist in at least one location!"
                $bSDKLoaded = $false
            }
        }
    }
    $bSDKLoaded
}
Import-OperationsManager
. $psScriptRoot\Functions.ps1


Import-Module $psScriptRoot\OM10.CoreCommands\OM10.CoreCommands.psd1
Import-Module $psScriptRoot\OM10.Commands\OM10.Commands.psd1
. $psScriptRoot\OM10.CrossPlatform.Start.ps1

New-Alias Export-SCOMManagementPack Export-SCManagementPack
New-Alias Get-SCOMClass Get-SCClass
New-Alias Get-SCOMDiscovery Get-SCDiscovery
New-Alias Get-SCOMManagementPack Get-SCManagementPack
New-Alias Get-SCOMRelationship Get-SCRelationship
New-Alias Get-SCOMRelationshipInstance Get-SCRelationshipInstance
New-Alias Import-SCOMManagementPack Import-SCManagementPack
New-Alias Remove-SCOMManagementPack Remove-SCManagementPack
New-Alias Get-SCOMManagementGroupConnection Get-SCManagementGroupConnection
New-Alias New-SCOMManagementGroupConnection New-SCManagementGroupConnection
New-Alias Remove-SCOMManagementGroupConnection Remove-SCManagementGroupConnection
New-Alias Set-SCOMManagementGroupConnection Set-SCManagementGroupConnection
New-Alias Get-SCOMMonitoringObject Get-SCOMClassInstance

$parentParent = Split-Path $psScriptRoot
$assemblyNames = [AppDomain]::CurrentDomain.GetAssemblies() |%{ $_.GetName().Name }

if($assemblyNames -cnotcontains 'Microsoft.SystemCenter.CrossPlatform.ClientLibrary.CredentialManagement')
{
   $xPlatDll = Get-ChildItem $psScriptRoot -Recurse -Filter 'Microsoft.SystemCenter.CrossPlatform.ClientLibrary.CredentialManagement.dll' -ErrorAction 0 |
       Select-Object -ExpandProperty Fullname | select-object -first 1

   if($xPlatDll)
   {
      Add-Type -Path $xPlatDll
   }
}

if($assemblyNames -cnotcontains 'Microsoft.EnterpriseManagement.DataAccessService.Core')
{
   $serverDASCore = Get-ChildItem "$psScriptRoot\..\..\Server" -Recurse -Filter 'Microsoft.EnterpriseManagement.DataAccessService.Core.dll' -ErrorAction 0 |
       Select-Object -ExpandProperty Fullname | select-object -first 1
       
   if($serverDASCore)
   {
      Add-Type -Path $serverDASCore
   }
}

Export-ModuleMember -Alias * -Function * -Cmdlet *

$myInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    Remove-Module OM10.CoreCommands
    Remove-Module OM10.Commands
}

