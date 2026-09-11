#
# OneViewMaintenanceMode.ps1 - HPE OneView maintenance-mode operations
#
# Contains: OneViewClient class, Test-OneViewConnection helper,
#           and standalone OneView maintenance cmdlets.
#

function Test-OneViewConnection {
    <#
    .SYNOPSIS
        Tests one view connection.
    #>

    param(
        [string]$Appliance,
        [string]$Username,
        [string]$Password,
        [string]$ModuleName = 'HPEOneView.1000',
        [Parameter(ParameterSetName = 'Help')][switch]$Help
    )
    if ($Help) { Get-CommandHelp -Name 'Test-OneViewConnection'; return }
    
    try {
        $cred = [System.Management.Automation.PSCredential]::new(
            $Username,
            (ConvertTo-SecureString $Password -AsPlainText -Force))
        $connResult = Connect-OneViewSession -Appliance $Appliance -Credential $cred
        return $connResult.Connected
    } catch {
        Write-Warning "OneView connection test failed: $($_.Exception.Message)"
        return $false
    }
}

class OneViewClient {
    [hashtable] $Config
    [string]    $Appliance
    [string]    $ModuleName
    [bool]      $UseWinRM
    [string]    $WinRMServer
    [string]    $Username
    [string]    $Password

    OneViewClient([hashtable]$Config) {
        $ovConfig = $Config.Get_Item('oneview') ?? @{}
        $this.Config = $ovConfig
        $this.Appliance = $ovConfig.Get_Item('appliance') ?? 'oneview.example.com'
        $this.ModuleName = $this._DetectRecommendedModule($this.Appliance)
        $this._ValidateModuleCompat($this.ModuleName, $this.Appliance)
        $this.UseWinRM = [bool]($ovConfig.Get_Item('use_winrm') ?? $false)
        if ($this.UseWinRM) {
            $winrmCfg = $ovConfig.Get_Item('winrm') ?? @{}
            $this.WinRMServer = $winrmCfg.Get_Item('server') ?? $this.Appliance
        }
        $credCfg = $ovConfig.Get_Item('credentials') ?? @{}
        $userEnv = $credCfg.Get_Item('username_env') ?? 'ONEVIEW_USER'
        $passEnv = $credCfg.Get_Item('password_env') ?? 'ONEVIEW_PASSWORD'
        $this.Username = [System.Environment]::GetEnvironmentVariable($userEnv)
        $this.Password = [System.Environment]::GetEnvironmentVariable($passEnv)
    }

    hidden static [hashtable[]] $OneViewModuleApplianceMap = @(
        @{ Module = 'HPEOneView.1000'; MinAppliance = '10.00'; PsVersion = '7.0'; Note = 'Requires PS 7+' },
        @{ Module = 'HPEOneView.910'; MinAppliance = '9.10'; PsVersion = '7.0'; Note = 'Requires PS 7+' },
        @{ Module = 'HPEOneView.900'; MinAppliance = '9.00'; PsVersion = '7.0'; Note = 'Requires PS 7+' },
        @{ Module = 'HPEOneView.860'; MinAppliance = '8.60'; PsVersion = '7.0'; Note = 'Requires PS 7+' },
        @{ Module = 'HPEOneView.840'; MinAppliance = '8.40'; PsVersion = '7.0'; Note = 'Requires PS 7+' },
        @{ Module = 'HPEOneView.830'; MinAppliance = '8.30'; PsVersion = '7.0'; Note = 'Requires PS 7+' },
        @{ Module = 'HPEOneView.800'; MinAppliance = '8.00'; PsVersion = '7.0'; Note = 'Requires PS 7+' },
        @{ Module = 'HPEOneView.720'; MinAppliance = '7.20'; PsVersion = '5.1'; Note = 'PS 5.1/7 compatible' },
        @{ Module = 'HPEOneView.710'; MinAppliance = '7.10'; PsVersion = '5.1'; Note = 'PS 5.1/7 compatible' },
        @{ Module = 'HPEOneView.700'; MinAppliance = '7.00'; PsVersion = '5.1'; Note = 'PS 5.1/7 compatible' }
    )

    [string] _DetectRecommendedModule([string]$Appliance) {
        $resolved = Resolve-PinnedOneViewModule
        if ($resolved) { return $resolved }
        $apiVer = $this._ResolveApplianceApiVersion($Appliance)
        if (-not $apiVer) { return 'HPEOneView.1000' }
        foreach ($entry in [OneViewClient]::OneViewModuleApplianceMap) {
            if ([Version]$apiVer -ge [Version]$entry.MinAppliance) { return $entry.Module }
        }
        return 'HPEOneView.1000'
    }

    [void] _ValidateModuleCompat([string]$ModuleName, [string]$Appliance) {
        $moduleInfo = $null
        if ($ModuleName -match 'HPEOneView\.(\d+)') {
            $moduleInfo = [OneViewClient]::OneViewModuleApplianceMap | Where-Object { $_.Module -eq $ModuleName }
        } elseif ($ModuleName -match 'HPOneView\.(\d+)') {
            $moduleInfo = [OneViewClient]::OneViewModuleApplianceMap | Where-Object { $_.Module -eq $ModuleName }
            if (-not $moduleInfo) {
                Write-Warning "Legacy module name detected: '$ModuleName'. Consider updating config to HPEOneView.Xxx format."
            }
        }

        if ($moduleInfo -and $moduleInfo.Note -match 'PS 7\+') {
            $psVerTable = Get-Variable -Name PSVersionTable -Scope Global -ErrorAction SilentlyContinue
            if ($psVerTable -and $psVerTable.Value.PSVersion.Major -lt 7) {
                $psVer = $psVerTable.Value.PSVersion.ToString()
                Write-Warning "Module '$ModuleName' requires PowerShell 7.0+. Current: $psVer. Use HPEOneView.720 or earlier for PS 5.1 compatibility."
            }
        }
    }

    [hashtable] _ResolveApplianceApiVersion([string]$Appliance) {
        $url = "https://$Appliance/rest/login-sessions"
        try {
            $r = Invoke-RestMethod -Uri $url -Method Post -ContentType 'application/json' -Body '{}' -ErrorAction Stop
            if ($r.'Api-Version') { return $r.'Api-Version' }
            if ($r.apiVersion) { return $r.apiVersion }
            if ($r.APIVersion) { return $r.APIVersion }
        } catch { }
        return $null
    }

    [hashtable] SetMaintenance([object]$Target, [string]$TargetType, [DateTime]$StartDt, [DateTime]$EndDt, [bool]$DryRun) {
        if ($this.UseWinRM) {
            return $this._SetViaWinRM($Target, $TargetType, $StartDt, $EndDt, $DryRun)
        }
        return $this._SetViaModule($Target, $TargetType, $StartDt, $EndDt, $DryRun)
    }

    [hashtable] _SetViaModule([object]$Target, [string]$TargetType, [DateTime]$StartDt, [DateTime]$EndDt, [bool]$DryRun) {
        $ovModule = $this.ModuleName
        $ovAppliance = $this.Appliance
        if ($DryRun) {
            return @{ Success = $true; Message = "[DRY RUN] OneView maintenance for $TargetType '$Target'"; Objects = @() }
        }
        $scriptContent = @"
param([string]`$OVUser = `$env:OV_CONN_USER, [string]`$OVPwd = `$env:OV_CONN_PASS)
 Get-Module -Name 'HPEOneView.*','HPOneView.*' -ErrorAction SilentlyContinue | Where-Object { `$_.Name -ne '$ovModule' } | Remove-Module -Force -ErrorAction SilentlyContinue
Import-Module $ovModule -ErrorAction Stop
`$existingSession = `$ConnectedSessions | Where-Object { `$_.Connected -eq `$true } | Select-Object -First 1
if (-not `$existingSession) {
    `$securePass = ConvertTo-SecureString `$OVPwd -AsPlainText -Force
    `$cred = New-Object System.Management.Automation.PSCredential(`$OVUser, `$securePass)
    Connect-OVMgmt -Appliance '$ovAppliance' -Credential `$cred -ErrorAction Stop
}
`$objects = @()
`$success = 0
`$failed = 0
`$alreadyInMaintenance = 0
if ('$TargetType' -eq 'ServerHardware') {
    `$server = Get-OVServer -Name '$Target' -ErrorAction Stop
    `$obj = @{
        Name = `$server.Name
        Type = `$server.Type
        Status = 'unknown'
        Message = ''
    }
    try {
        if (`$server.maintenanceMode) {
            `$obj.Status = 'already_in_maintenance'
            `$obj.Message = 'Already in maintenance mode'
            `$alreadyInMaintenance++
        } else {
            Enable-OVMaintenanceMode -InputObject `$server -ErrorAction Stop | Out-Null
            `$obj.Status = 'success'
            `$obj.Message = 'Maintenance mode enabled'
            `$success++
        }
    } catch {
        `$obj.Status = 'failed'
        `$obj.Message = `$_.Exception.Message
        `$obj.NackReason = 'OneView API error: ' + `$_.Exception.Message
        `$obj.Resolution = 'Check OneView appliance logs and permissions'
        `$failed++
    }
    `$objects += `$obj
} elseif ('$TargetType' -eq 'Scope') {
    `$scope = Get-OVScope -Name '$Target' -ErrorAction Stop
    `$servers = `$scope.Members | Where-Object { `$_.Type -eq 'ServerHardware' }
    foreach (`$member in `$servers) {
        `$server = Get-OVServer -Name `$member.Name -ErrorAction SilentlyContinue
        if (-not `$server) { continue }
        `$obj = @{
            Name = `$server.Name
            Type = `$server.Type
            Status = 'unknown'
            Message = ''
        }
        try {
            if (`$server.maintenanceMode) {
                `$obj.Status = 'already_in_maintenance'
                `$obj.Message = 'Already in maintenance mode'
                `$alreadyInMaintenance++
            } else {
                Enable-OVMaintenanceMode -InputObject `$server -ErrorAction Stop | Out-Null
                `$obj.Status = 'success'
                `$obj.Message = 'Maintenance mode enabled'
                `$success++
            }
        } catch {
            `$obj.Status = 'failed'
            `$obj.Message = `$_.Exception.Message
            `$obj.NackReason = 'OneView API error: ' + `$_.Exception.Message
            `$obj.Resolution = 'Check OneView appliance logs and permissions'
            `$failed++
        }
        `$objects += `$obj
    }
}
`$out = @{
    Success      = `$failed -eq 0
    Objects      = `$objects
    Total        = `$objects.Count
    SuccessCount = `$success
    FailedCount  = `$failed
    AlreadyCount = `$alreadyInMaintenance
    Appliance    = '$ovAppliance'
    Module       = '$ovModule'
    TargetType   = '$TargetType'
    Target       = '$Target'
    StartTime    = '$($StartDt.ToString('o'))'
    EndTime      = '$($EndDt.ToString('o'))'
    DryRun       = '$DryRun'
    Message      = "OneView maintenance mode enabled: `$success succeeded, `$failed failed, `$alreadyInMaintenance already in maintenance (total `$(`$objects.Count))"
}
`$out | ConvertTo-Json -Depth 5
"@
        try {
            $output = $null
            if ($this.UseWinRM) {
                $session = New-PSSession -ComputerName $this.WinRMServer
                $output = Invoke-Command -Session $session -ScriptBlock ([scriptblock]::Create($scriptContent)) -ArgumentList @($this.Username, $this.Password)
                Remove-PSSession $session
            } else {
                $env:OV_CONN_USER = $this.Username
                $env:OV_CONN_PASS = $this.Password
                try {
                    $output = Invoke-Expression $scriptContent
                } finally {
                    Remove-Item Env:OV_CONN_USER, Env:OV_CONN_PASS -ErrorAction SilentlyContinue
                }
            }
            $result = $output | ConvertFrom-Json
            return @{
                Success      = [bool]$result.Success
                Objects      = @($result.Objects)
                Total        = [int]$result.Total
                SuccessCount = [int]$result.SuccessCount
                FailedCount  = [int]$result.FailedCount
                AlreadyCount = [int]$result.AlreadyCount
                Appliance    = $result.Appliance
                Module       = $result.Module
                TargetType   = $result.TargetType
                Target       = $result.Target
                StartTime    = $result.StartTime
                EndTime      = $result.EndTime
                DryRun       = [bool]$result.DryRun
                Message      = $result.Message
            }
        } catch {
            return @{
                Success      = $false
                Objects      = @()
                Total        = 0
                SuccessCount = 0
                FailedCount  = 0
                AlreadyCount = 0
                Appliance    = $ovAppliance
                Module       = $ovModule
                TargetType   = $TargetType
                Target       = $Target
                StartTime    = $StartDt.ToString('o')
                EndTime      = $EndDt.ToString('o')
                DryRun       = $DryRun
                Message      = "OneView maintenance mode enable failed: $($_.Exception.Message)"
            }
        }
    }

    [hashtable] _SetViaWinRM([object]$Target, [string]$TargetType, [DateTime]$StartDt, [DateTime]$EndDt, [bool]$DryRun) {
        $ovModule = $this.ModuleName
        $ovAppliance = $this.Appliance
        $winrmSrv = $this.WinRMServer
        if ($DryRun) {
            return @{ Success = $true; Message = "[DRY RUN] OneView maintenance for $TargetType '$Target' via WinRM"; Objects = @() }
        }
        $scriptContent = @"
param([string]`$OVUser, [string]`$OVPwd)
 `$ErrorActionPreference = 'Stop'
 Get-Module -Name 'HPEOneView.*','HPOneView.*' -ErrorAction SilentlyContinue | Where-Object { `$_.Name -ne '$ovModule' } | Remove-Module -Force -ErrorAction SilentlyContinue
Import-Module $ovModule -ErrorAction Stop
`$existingSession = `$ConnectedSessions | Where-Object { `$_.Connected -eq `$true } | Select-Object -First 1
if (-not `$existingSession) {
    `$securePass = ConvertTo-SecureString `$OVPwd -AsPlainText -Force
    `$cred = New-Object System.Management.Automation.PSCredential(`$OVUser, `$securePass)
    Connect-OVMgmt -Appliance '$ovAppliance' -Credential `$cred -ErrorAction Stop
}
`$objects = @()
`$success = 0
`$failed = 0
`$alreadyInMaintenance = 0
if ('$TargetType' -eq 'ServerHardware') {
    `$server = Get-OVServer -Name '$Target' -ErrorAction Stop
    `$obj = @{ Name = `$server.Name; Type = `$server.Type; Status = 'unknown'; Message = '' }
    try {
        if (`$server.maintenanceMode) {
            `$obj.Status = 'already_in_maintenance'
            `$obj.Message = 'Already in maintenance mode'
            `$alreadyInMaintenance++
        } else {
            Enable-OVMaintenanceMode -InputObject `$server -ErrorAction Stop | Out-Null
            `$obj.Status = 'success'
            `$obj.Message = 'Maintenance mode enabled'
            `$success++
        }
    } catch {
        `$obj.Status = 'failed'
        `$obj.Message = `$_.Exception.Message
        `$obj.NackReason = 'OneView API error: ' + `$_.Exception.Message
        `$obj.Resolution = 'Check OneView appliance logs and permissions'
        `$failed++
    }
    `$objects += `$obj
} elseif ('$TargetType' -eq 'Scope') {
    `$scope = Get-OVScope -Name '$Target' -ErrorAction Stop
    `$servers = `$scope.Members | Where-Object { `$_.Type -eq 'ServerHardware' }
    foreach (`$member in `$servers) {
        `$server = Get-OVServer -Name `$member.Name -ErrorAction SilentlyContinue
        if (-not `$server) { continue }
        `$obj = @{ Name = `$server.Name; Type = `$server.Type; Status = 'unknown'; Message = '' }
        try {
            if (`$server.maintenanceMode) {
                `$obj.Status = 'already_in_maintenance'
                `$obj.Message = 'Already in maintenance mode'
                `$alreadyInMaintenance++
            } else {
                Enable-OVMaintenanceMode -InputObject `$server -ErrorAction Stop | Out-Null
                `$obj.Status = 'success'
                `$obj.Message = 'Maintenance mode enabled'
                `$success++
            }
        } catch {
            `$obj.Status = 'failed'
            `$obj.Message = `$_.Exception.Message
            `$obj.NackReason = 'OneView API error: ' + `$_.Exception.Message
            `$obj.Resolution = 'Check OneView appliance logs and permissions'
            `$failed++
        }
        `$objects += `$obj
    }
}
`$out = @{
    Success      = `$failed -eq 0
    Objects      = `$objects
    Total        = `$objects.Count
    SuccessCount = `$success
    FailedCount  = `$failed
    AlreadyCount = `$alreadyInMaintenance
    Appliance    = '$ovAppliance'
    Module       = '$ovModule'
    TargetType   = '$TargetType'
    Target       = '$Target'
    StartTime    = '$($StartDt.ToString('o'))'
    EndTime      = '$($EndDt.ToString('o'))'
    DryRun       = '$DryRun'
    Message      = "OneView maintenance mode enabled: `$success succeeded, `$failed failed, `$alreadyInMaintenance already in maintenance (total `$(`$objects.Count))"
}
`$out | ConvertTo-Json -Depth 5
"@
        try {
            $output = $null
            $session = New-PSSession -ComputerName $winrmSrv
            $output = Invoke-Command -Session $session -ScriptBlock ([scriptblock]::Create($scriptContent)) -ArgumentList @($this.Username, $this.Password)
            Remove-PSSession $session
            $result = $output | ConvertFrom-Json
            return @{
                Success      = [bool]$result.Success
                Objects      = @($result.Objects)
                Total        = [int]$result.Total
                SuccessCount = [int]$result.SuccessCount
                FailedCount  = [int]$result.FailedCount
                AlreadyCount = [int]$result.AlreadyCount
                Appliance    = $result.Appliance
                Module       = $result.Module
                TargetType   = $result.TargetType
                Target       = $result.Target
                StartTime    = $result.StartTime
                EndTime      = $result.EndTime
                DryRun       = [bool]$result.DryRun
                Message      = $result.Message
            }
        } catch {
            return @{
                Success      = $false
                Objects      = @()
                Total        = 0
                SuccessCount = 0
                FailedCount  = 0
                AlreadyCount = 0
                Appliance    = $ovAppliance
                Module       = $ovModule
                TargetType   = $TargetType
                Target       = $Target
                StartTime    = $StartDt.ToString('o')
                EndTime      = $EndDt.ToString('o')
                DryRun       = $DryRun
                Message      = "OneView maintenance mode enable failed (WinRM): $($_.Exception.Message)"
            }
        }
    }

    [hashtable] DisableMaintenance([object]$Target, [string]$TargetType, [bool]$DryRun) {
        if ($this.UseWinRM) {
            return $this._DisableViaWinRM($Target, $TargetType, $DryRun)
        }
        return $this._DisableViaModule($Target, $TargetType, $DryRun)
    }

    [hashtable] _DisableViaModule([object]$Target, [string]$TargetType, [bool]$DryRun) {
        $ovModule = $this.ModuleName
        $ovAppliance = $this.Appliance
        if ($DryRun) {
            return @{ Success = $true; Message = "[DRY RUN] OneView maintenance disable for $TargetType '$Target'"; Objects = @() }
        }
        $scriptContent = @"
param([string]`$OVUser = `$env:OV_CONN_USER, [string]`$OVPwd = `$env:OV_CONN_PASS)
 `$ErrorActionPreference = 'Stop'
 Get-Module -Name 'HPEOneView.*','HPOneView.*' -ErrorAction SilentlyContinue | Where-Object { `$_.Name -ne '$ovModule' } | Remove-Module -Force -ErrorAction SilentlyContinue
Import-Module $ovModule -ErrorAction Stop
`$existingSession = `$ConnectedSessions | Where-Object { `$_.Connected -eq `$true } | Select-Object -First 1
if (-not `$existingSession) {
    `$securePass = ConvertTo-SecureString `$OVPwd -AsPlainText -Force
    `$cred = New-Object System.Management.Automation.PSCredential(`$OVUser, `$securePass)
    Connect-OVMgmt -Appliance '$ovAppliance' -Credential `$cred -ErrorAction Stop
}
`$objects = @()
`$success = 0
`$failed = 0
`$notInMaintenance = 0
if ('$TargetType' -eq 'ServerHardware') {
    `$server = Get-OVServer -Name '$Target' -ErrorAction Stop
    `$obj = @{
        Name = `$server.Name
        Type = `$server.Type
        Status = 'unknown'
        Message = ''
    }
    try {
        if (-not `$server.maintenanceMode) {
            `$obj.Status = 'already_not_in_maintenance'
            `$obj.Message = 'Already not in maintenance mode'
            `$notInMaintenance++
        } else {
            Disable-OVMaintenanceMode -InputObject `$server -ErrorAction Stop | Out-Null
            `$obj.Status = 'success'
            `$obj.Message = 'Maintenance mode disabled'
            `$success++
        }
    } catch {
        `$obj.Status = 'failed'
        `$obj.Message = `$_.Exception.Message
        `$failed++
    }
    `$objects += `$obj
} elseif ('$TargetType' -eq 'Scope') {
    `$scope = Get-OVScope -Name '$Target' -ErrorAction Stop
    `$servers = `$scope.Members | Where-Object { `$_.Type -eq 'ServerHardware' }
    foreach (`$member in `$servers) {
        `$server = Get-OVServer -Name `$member.Name -ErrorAction SilentlyContinue
        if (-not `$server) { continue }
        `$obj = @{
            Name = `$server.Name
            Type = `$server.Type
            Status = 'unknown'
            Message = ''
        }
        try {
            if (-not `$server.maintenanceMode) {
                `$obj.Status = 'already_not_in_maintenance'
                `$obj.Message = 'Already not in maintenance mode'
                `$notInMaintenance++
            } else {
                Disable-OVMaintenanceMode -InputObject `$server -ErrorAction Stop | Out-Null
                `$obj.Status = 'success'
                `$obj.Message = 'Maintenance mode disabled'
                `$success++
            }
        } catch {
            `$obj.Status = 'failed'
            `$obj.Message = `$_.Exception.Message
            `$failed++
        }
        `$objects += `$obj
    }
}
`$out = @{
    Success        = `$failed -eq 0
    Objects        = `$objects
    Total          = `$objects.Count
    SuccessCount   = `$success
    FailedCount    = `$failed
    NotInCount     = `$notInMaintenance
    Appliance      = '$ovAppliance'
    Module         = '$ovModule'
    TargetType     = '$TargetType'
    Target         = '$Target'
    DryRun         = '$DryRun'
    Message        = "OneView maintenance mode disabled: `$success succeeded, `$failed failed, `$notInMaintenance already not in maintenance (total `$(`$objects.Count))"
}
`$out | ConvertTo-Json -Depth 5
"@
        try {
            $output = $null
            if ($this.UseWinRM) {
                $session = New-PSSession -ComputerName $this.WinRMServer
                $output = Invoke-Command -Session $session -ScriptBlock ([scriptblock]::Create($scriptContent)) -ArgumentList @($this.Username, $this.Password)
                Remove-PSSession $session
            } else {
                $env:OV_CONN_USER = $this.Username
                $env:OV_CONN_PASS = $this.Password
                try {
                    $output = Invoke-Expression $scriptContent
                } finally {
                    Remove-Item Env:OV_CONN_USER, Env:OV_CONN_PASS -ErrorAction SilentlyContinue
                }
            }
            $result = $output | ConvertFrom-Json
            return @{
                Success        = [bool]$result.Success
                Objects        = @($result.Objects)
                Total          = [int]$result.Total
                SuccessCount   = [int]$result.SuccessCount
                FailedCount    = [int]$result.FailedCount
                NotInCount     = [int]$result.NotInCount
                Appliance      = $result.Appliance
                Module         = $result.Module
                TargetType     = $result.TargetType
                Target         = $result.Target
                DryRun         = [bool]$result.DryRun
                Message        = $result.Message
            }
        } catch {
            return @{
                Success        = $false
                Objects        = @()
                Total          = 0
                SuccessCount   = 0
                FailedCount    = 0
                NotInCount     = 0
                Appliance      = $ovAppliance
                Module         = $ovModule
                TargetType     = $TargetType
                Target         = $Target
                DryRun         = $DryRun
                Message        = "OneView maintenance mode disable failed: $($_.Exception.Message)"
            }
        }
    }

    [hashtable] _DisableViaWinRM([object]$Target, [string]$TargetType, [bool]$DryRun) {
        $ovModule = $this.ModuleName
        $ovAppliance = $this.Appliance
        $winrmSrv = $this.WinRMServer
        if ($DryRun) {
            return @{ Success = $true; Message = "[DRY RUN] OneView maintenance disable for $TargetType '$Target' via WinRM"; Objects = @() }
        }
        $scriptContent = @"
param([string]`$OVUser, [string]`$OVPwd)
 `$ErrorActionPreference = 'Stop'
 Get-Module -Name 'HPEOneView.*','HPOneView.*' -ErrorAction SilentlyContinue | Where-Object { `$_.Name -ne '$ovModule' } | Remove-Module -Force -ErrorAction SilentlyContinue
Import-Module $ovModule -ErrorAction Stop
`$existingSession = `$ConnectedSessions | Where-Object { `$_.Connected -eq `$true } | Select-Object -First 1
if (-not `$existingSession) {
    `$securePass = ConvertTo-SecureString `$OVPwd -AsPlainText -Force
    `$cred = New-Object System.Management.Automation.PSCredential(`$OVUser, `$securePass)
    Connect-OVMgmt -Appliance '$ovAppliance' -Credential `$cred -ErrorAction Stop
}
`$objects = @()
`$success = 0
`$failed = 0
`$notInMaintenance = 0
if ('$TargetType' -eq 'ServerHardware') {
    `$server = Get-OVServer -Name '$Target' -ErrorAction Stop
    `$obj = @{ Name = `$server.Name; Type = `$server.Type; Status = 'unknown'; Message = '' }
    try {
        if (-not `$server.maintenanceMode) {
            `$obj.Status = 'already_not_in_maintenance'
            `$obj.Message = 'Already not in maintenance mode'
            `$notInMaintenance++
        } else {
            Disable-OVMaintenanceMode -InputObject `$server -ErrorAction Stop | Out-Null
            `$obj.Status = 'success'
            `$obj.Message = 'Maintenance mode disabled'
            `$success++
        }
    } catch {
        `$obj.Status = 'failed'
        `$obj.Message = `$_.Exception.Message
        `$failed++
    }
    `$objects += `$obj
} elseif ('$TargetType' -eq 'Scope') {
    `$scope = Get-OVScope -Name '$Target' -ErrorAction Stop
    `$servers = `$scope.Members | Where-Object { `$_.Type -eq 'ServerHardware' }
    foreach (`$member in `$servers) {
        `$server = Get-OVServer -Name `$member.Name -ErrorAction SilentlyContinue
        if (-not `$server) { continue }
        `$obj = @{ Name = `$server.Name; Type = `$server.Type; Status = 'unknown'; Message = '' }
        try {
            if (-not `$server.maintenanceMode) {
                `$obj.Status = 'already_not_in_maintenance'
                `$obj.Message = 'Already not in maintenance mode'
                `$notInMaintenance++
            } else {
                Disable-OVMaintenanceMode -InputObject `$server -ErrorAction Stop | Out-Null
                `$obj.Status = 'success'
                `$obj.Message = 'Maintenance mode disabled'
                `$success++
            }
        } catch {
            `$obj.Status = 'failed'
            `$obj.Message = `$_.Exception.Message
            `$failed++
        }
        `$objects += `$obj
    }
}
`$out = @{
    Success        = `$failed -eq 0
    Objects        = `$objects
    Total          = `$objects.Count
    SuccessCount   = `$success
    FailedCount    = `$failed
    NotInCount     = `$notInMaintenance
    Appliance      = '$ovAppliance'
    Module         = '$ovModule'
    TargetType     = '$TargetType'
    Target         = '$Target'
    DryRun         = '$DryRun'
    Message        = "OneView maintenance mode disabled: `$success succeeded, `$failed failed, `$notInMaintenance already not in maintenance (total `$(`$objects.Count))"
}
`$out | ConvertTo-Json -Depth 5
"@
        try {
            $output = $null
            $session = New-PSSession -ComputerName $winrmSrv
            $output = Invoke-Command -Session $session -ScriptBlock ([scriptblock]::Create($scriptContent)) -ArgumentList @($this.Username, $this.Password)
            Remove-PSSession $session
            $result = $output | ConvertFrom-Json
            return @{
                Success        = [bool]$result.Success
                Objects        = @($result.Objects)
                Total          = [int]$result.Total
                SuccessCount   = [int]$result.SuccessCount
                FailedCount    = [int]$result.FailedCount
                NotInCount     = [int]$result.NotInCount
                Appliance      = $result.Appliance
                Module         = $result.Module
                TargetType     = $result.TargetType
                Target         = $result.Target
                DryRun         = [bool]$result.DryRun
                Message        = $result.Message
            }
        } catch {
            return @{
                Success        = $false
                Objects        = @()
                Total          = 0
                SuccessCount   = 0
                FailedCount    = 0
                NotInCount     = 0
                Appliance      = $ovAppliance
                Module         = $ovModule
                TargetType     = $TargetType
                Target         = $Target
                DryRun         = $DryRun
                Message        = "OneView maintenance mode disable failed (WinRM): $($_.Exception.Message)"
            }
        }
    }

    [hashtable] GetMaintenanceStatus([string]$Target, [string]$TargetType) {
        if ($this.UseWinRM) {
            return $this._StatusViaWinRM($Target, $TargetType)
        }
        return $this._StatusViaModule($Target, $TargetType)
    }

    [hashtable] _StatusViaModule([string]$Target, [string]$TargetType) {
        $ovModule = $this.ModuleName
        $ovAppliance = $this.Appliance
        $scriptContent = @"
param([string]`$OVUser = `$env:OV_CONN_USER, [string]`$OVPwd = `$env:OV_CONN_PASS)
 `$ErrorActionPreference = 'Stop'
 Get-Module -Name 'HPEOneView.*','HPOneView.*' -ErrorAction SilentlyContinue | Where-Object { `$_.Name -ne '$ovModule' } | Remove-Module -Force -ErrorAction SilentlyContinue
Import-Module $ovModule -ErrorAction Stop
`$existingSession = `$ConnectedSessions | Where-Object { `$_.Connected -eq `$true } | Select-Object -First 1
if (-not `$existingSession) {
    `$securePass = ConvertTo-SecureString `$OVPwd -AsPlainText -Force
    `$cred = New-Object System.Management.Automation.PSCredential(`$OVUser, `$securePass)
    Connect-OVMgmt -Appliance '$ovAppliance' -Credential `$cred -ErrorAction Stop
}
`$out = @{ Success = `$false; Objects = @(); Message = '' }
if ('$TargetType' -eq 'ServerHardware') {
    `$server = Get-OVServer -Name '$Target' -ErrorAction Stop
    `$out.Success = `$true
    `$out.Objects += @{
        Name              = `$server.Name
        Type              = `$server.Type
        InMaintenanceMode = [bool]`$server.maintenanceMode
        MaintenanceModeState = if (`$server.maintenanceMode) { 'Enabled' } else { 'Disabled' }
    }
} elseif ('$TargetType' -eq 'Scope') {
    `$scope = Get-OVScope -Name '$Target' -ErrorAction Stop
    `$servers = `$scope.Members | Where-Object { `$_.Type -eq 'ServerHardware' }
    foreach (`$member in `$servers) {
        `$server = Get-OVServer -Name `$member.Name -ErrorAction SilentlyContinue
        if (-not `$server) { continue }
        `$out.Success = `$true
        `$out.Objects += @{
            Name              = `$server.Name
            Type              = `$server.Type
            InMaintenanceMode = [bool]`$server.maintenanceMode
            MaintenanceModeState = if (`$server.maintenanceMode) { 'Enabled' } else { 'Disabled' }
        }
    }
}
`$out | ConvertTo-Json -Depth 5
"@
        try {
            $output = $null
            if ($this.UseWinRM) {
                $session = New-PSSession -ComputerName $this.WinRMServer
                $output = Invoke-Command -Session $session -ScriptBlock ([scriptblock]::Create($scriptContent)) -ArgumentList @($this.Username, $this.Password)
                Remove-PSSession $session
            } else {
                $env:OV_CONN_USER = $this.Username
                $env:OV_CONN_PASS = $this.Password
                try {
                    $output = Invoke-Expression $scriptContent
                } finally {
                    Remove-Item Env:OV_CONN_USER, Env:OV_CONN_PASS -ErrorAction SilentlyContinue
                }
            }
            $result = $output | ConvertFrom-Json
            return @{
                Success       = [bool]$result.Success
                Objects       = @($result.Objects)
                Message       = $result.Message
                Appliance     = $ovAppliance
                Module        = $ovModule
            }
        } catch {
            return @{
                Success       = $false
                Objects       = @()
                Message       = "OneView status query failed: $($_.Exception.Message)"
                Appliance     = $ovAppliance
                Module        = $ovModule
            }
        }
    }

    [hashtable] _StatusViaWinRM([string]$Target, [string]$TargetType) {
        $ovModule = $this.ModuleName
        $ovAppliance = $this.Appliance
        $winrmSrv = $this.WinRMServer
        $scriptContent = @"
param([string]`$OVUser, [string]`$OVPwd)
 `$ErrorActionPreference = 'Stop'
 Get-Module -Name 'HPEOneView.*','HPOneView.*' -ErrorAction SilentlyContinue | Where-Object { `$_.Name -ne '$ovModule' } | Remove-Module -Force -ErrorAction SilentlyContinue
Import-Module $ovModule -ErrorAction Stop
`$existingSession = `$ConnectedSessions | Where-Object { `$_.Connected -eq `$true } | Select-Object -First 1
if (-not `$existingSession) {
    `$securePass = ConvertTo-SecureString `$OVPwd -AsPlainText -Force
    `$cred = New-Object System.Management.Automation.PSCredential(`$OVUser, `$securePass)
    Connect-OVMgmt -Appliance '$ovAppliance' -Credential `$cred -ErrorAction Stop
}
`$out = @{ Success = `$false; Objects = @(); Message = '' }
if ('$TargetType' -eq 'ServerHardware') {
    `$server = Get-OVServer -Name '$Target' -ErrorAction Stop
    `$out.Success = `$true
    `$out.Objects += @{
        Name = `$server.Name
        Type = `$server.Type
        InMaintenanceMode = [bool]`$server.maintenanceMode
        MaintenanceModeState = if (`$server.maintenanceMode) { 'Enabled' } else { 'Disabled' }
    }
} elseif ('$TargetType' -eq 'Scope') {
    `$scope = Get-OVScope -Name '$Target' -ErrorAction Stop
    `$servers = `$scope.Members | Where-Object { `$_.Type -eq 'ServerHardware' }
    foreach (`$member in `$servers) {
        `$server = Get-OVServer -Name `$member.Name -ErrorAction SilentlyContinue
        if (-not `$server) { continue }
        `$out.Success = `$true
        `$out.Objects += @{
            Name = `$server.Name
            Type = `$server.Type
            InMaintenanceMode = [bool]`$server.maintenanceMode
            MaintenanceModeState = if (`$server.maintenanceMode) { 'Enabled' } else { 'Disabled' }
        }
    }
}
`$out | ConvertTo-Json -Depth 5
"@
        try {
            $output = $null
            $session = New-PSSession -ComputerName $winrmSrv
            $output = Invoke-Command -Session $session -ScriptBlock ([scriptblock]::Create($scriptContent)) -ArgumentList @($this.Username, $this.Password)
            Remove-PSSession $session
            $result = $output | ConvertFrom-Json
            return @{
                Success       = [bool]$result.Success
                Objects       = @($result.Objects)
                Message       = $result.Message
                Appliance     = $ovAppliance
                Module        = $ovModule
            }
        } catch {
            return @{
                Success       = $false
                Objects       = @()
                Message       = "OneView status query failed (WinRM): $($_.Exception.Message)"
                Appliance     = $ovAppliance
                Module        = $ovModule
            }
        }
    }

    [hashtable] _ResolveServerByName([string]$Name) {
        $ovModule = $this.ModuleName
        $ovAppliance = $this.Appliance
        $scriptContent = @"
Get-Module -Name 'HPEOneView.*','HPOneView.*' -ErrorAction SilentlyContinue | Where-Object { `$_.Name -ne '$ovModule' } | Remove-Module -Force -ErrorAction SilentlyContinue
Import-Module $ovModule -ErrorAction Stop
`$existingSession = `$ConnectedSessions | Where-Object { `$_.Connected -eq `$true } | Select-Object -First 1
if (-not `$existingSession) {
    Connect-OVMgmt -Appliance '$ovAppliance' -Credential (New-Object System.Management.Automation.PSCredential('$($this.Username)', (ConvertTo-SecureString '$($this.Password)' -AsPlainText -Force))) -ErrorAction Stop
}
`$server = Get-OVServer -Name '$Name' -ErrorAction Stop
`$out = @{
    Name         = `$server.name
    SerialNumber = `$server.serialNumber
    Model        = `$server.model
    State        = `$server.state
}
`$out | ConvertTo-Json -Depth 5
"@
        try {
            $output = $null
            if ($this.UseWinRM) {
                $session = New-PSSession -ComputerName $this.WinRMServer
                $output = Invoke-Command -Session $session -ScriptBlock ([scriptblock]::Create($scriptContent)) -ArgumentList @($this.Username, $this.Password)
                Remove-PSSession $session
            } else {
                $env:OV_CONN_USER = $this.Username
                $env:OV_CONN_PASS = $this.Password
                try {
                    $output = Invoke-Expression $scriptContent
                } finally {
                    Remove-Item Env:OV_CONN_USER, Env:OV_CONN_PASS -ErrorAction SilentlyContinue
                }
            }
            $result = $output | ConvertFrom-Json
            return @{
                Success    = $true
                ServerName = $result.Name
                SerialNumber = $result.SerialNumber
                Model      = $result.Model
                State      = $result.State
            }
        } catch {
            return @{ Success = $false; ServerName = $null; SerialNumber = $null; Message = $_.Exception.Message }
        }
    }

    [hashtable] _ResolveServerBySerial([string]$SerialNumber) {
        $ovModule = $this.ModuleName
        $ovAppliance = $this.Appliance
        $scriptContent = @"
param([string]`$OVUser = `$env:OV_CONN_USER, [string]`$OVPwd = `$env:OV_CONN_PASS)
 `$ErrorActionPreference = 'Stop'
 Get-Module -Name 'HPEOneView.*','HPOneView.*' -ErrorAction SilentlyContinue | Where-Object { `$_.Name -ne '$ovModule' } | Remove-Module -Force -ErrorAction SilentlyContinue
Import-Module $ovModule -ErrorAction Stop
`$existingSession = `$ConnectedSessions | Where-Object { `$_.Connected -eq `$true } | Select-Object -First 1
if (-not `$existingSession) {
    `$securePass = ConvertTo-SecureString `$OVPwd -AsPlainText -Force
    `$cred = New-Object System.Management.Automation.PSCredential(`$OVUser, `$securePass)
    Connect-OVMgmt -Appliance '$ovAppliance' -Credential `$cred -ErrorAction Stop
}
`$apiVersion = `$null
`$restOk = `$false
try {
    `$headers = @{ 'X-API-Version' = '1200'; 'Content-Type' = 'application/json' }
    `$r = Invoke-RestMethod -Uri "https://$ovAppliance/rest/server-hardware?filter=serialNumber='$SerialNumber'" -Headers `$headers -Method Get -ErrorAction Stop
    if (`$r.members -and `$r.members.Count -gt 0) {
        `$restMember = `$r.members[0]
        `$server = @{
            Name         = `$restMember.name
            SerialNumber = `$restMember.serialNumber
            Model        = `$restMember.model
            State        = `$restMember.state
        }
        `$apiVersion = '1200'
        `$restOk = `$true
    }
} catch { }

if (-not `$restOk) {
    try {
        `$cmd = Get-Command Get-OVServer -ErrorAction Stop
        if (`$cmd.Parameters.ContainsKey('SerialNumber')) {
            `$ovServer = Get-OVServer -SerialNumber '$SerialNumber' -ErrorAction SilentlyContinue | Select-Object -First 1
            if (`$ovServer) {
                `$server = @{
                    Name         = `$ovServer.name
                    SerialNumber = `$ovServer.serialNumber
                    Model        = `$ovServer.model
                    State        = `$ovServer.state
                }
            }
        } else {
            `$allServers = Get-OVServer -ErrorAction Stop
            `$ovServer = `$allServers | Where-Object { `$_.serialNumber -eq '$SerialNumber' } | Select-Object -First 1
            if (`$ovServer) {
                `$server = @{
                    Name         = `$ovServer.name
                    SerialNumber = `$ovServer.serialNumber
                    Model        = `$ovServer.model
                    State        = `$ovServer.state
                }
            }
        }
    } catch {
        Write-Verbose "Module cmdlet fallback failed: $($_.Exception.Message)"
    }
}

if (`$server) {
    `$out = @{ Success = `$true; ServerName = `$server.Name; SerialNumber = `$server.SerialNumber; Model = `$server.Model; State = `$server.State; ApiVersion = `$apiVersion; Message = "Resolved via OneView API (v`$apiVersion)" }
    `$out | ConvertTo-Json -Depth 5
} else {
    `$out = @{ Success = `$false; ServerName = `$null; SerialNumber = '$SerialNumber'; ApiVersion = `$apiVersion; Message = "No server found with serial number '$SerialNumber' in OneView appliance '$ovAppliance' (module $ovModule, API version resolved: `$apiVersion)" }
    `$out | ConvertTo-Json -Depth 3
}
"@
        try {
            $output = $null
            if ($this.UseWinRM) {
                $session = New-PSSession -ComputerName $this.WinRMServer
                $output = Invoke-Command -Session $session -ScriptBlock ([scriptblock]::Create($scriptContent)) -ArgumentList @($this.Username, $this.Password)
                Remove-PSSession $session
            } else {
                $env:OV_CONN_USER = $this.Username
                $env:OV_CONN_PASS = $this.Password
                try {
                    $output = Invoke-Expression $scriptContent
                } finally {
                    Remove-Item Env:OV_CONN_USER, Env:OV_CONN_PASS -ErrorAction SilentlyContinue
                }
            }
            $result = $output | ConvertFrom-Json
            return @{
                Success      = $result.Success
                ServerName   = $result.ServerName
                SerialNumber = $result.SerialNumber
                Model        = $result.Model
                State        = $result.State
                ApiVersion   = $result.ApiVersion
                Message      = $result.Message
            }
        } catch {
            return @{
                Success      = $false
                ServerName   = $null
                SerialNumber = $SerialNumber
                ApiVersion   = $null
                Message      = "Resolve by serial failed: $($_.Exception.Message)"
            }
        }
    }
}

function Enable-OneViewMaintenanceMode {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][string] $TargetId,
        [Parameter(Mandatory, ParameterSetName = 'Run', Position = 1)][ValidateSet('ServerHardware', 'Scope')][string] $TargetType = 'ServerHardware',
        [ValidateSet('Test', 'Prod')][string] $Environment,
        [Alias('OVHost')][string] $OneViewHost,
        [Alias('Srl')][string] $SerialNumber,
        [string] $Start,
        [string] $End,
        [Alias('CfgDir')][string] $ConfigDir = 'configs',
        [Alias('Dry')][switch] $DryRun,
        [Alias('NoSchedule')][switch] $NoSchedule,
        [Alias('Json')][switch] $Json,
        [Alias('PT')][switch] $PassThru,
        [Parameter(ParameterSetName = 'Help')][switch]$Help
    )
    if ($Help) { Get-CommandHelp -Name 'Enable-OneViewMaintenanceMode'; return }

    $ovConfig = $null
    if ($PSBoundParameters.ContainsKey('ConfigDir')) {
        $effectiveConfigDir = Resolve-EffectiveConfigDir -ConfigDir $ConfigDir `
            -MarkerFile 'oneview_config.json' `
            -ExplicitlyBound:$PSBoundParameters.ContainsKey('ConfigDir')
        $ovCfgPath = Join-Path $effectiveConfigDir 'oneview_config.json'
        if (Test-Path $ovCfgPath) {
            $ovConfig = Import-JsonConfig -Path $ovCfgPath -Required:$false
        }
    }

    $ovHost = $null
    if ($PSBoundParameters.ContainsKey('OneViewHost')) {
        $ovHost = $OneViewHost
    } elseif ($ovConfig -and $ovConfig.ContainsKey('oneview') -and $ovConfig['oneview'].ContainsKey('appliance')) {
        $ovHost = $ovConfig['oneview']['appliance']
    }

    if (-not $ovHost) {
        Write-Error "OneView appliance host not supplied. Pass -OneViewHost or set appliance in oneview_config.json."
        return @{ Success = $false; Message = 'OneView appliance host not configured' }
    }

    $credUser = $null; $credPass = $null
    if ($ovConfig -and $ovConfig.ContainsKey('oneview') -and $ovConfig['oneview'].ContainsKey('credentials')) {
        $credUser = [System.Environment]::GetEnvironmentVariable($ovConfig['oneview']['credentials']['username_env'])
        $credPass = [System.Environment]::GetEnvironmentVariable($ovConfig['oneview']['credentials']['password_env'])
    }

    $oneviewMgr = [OneViewClient]::new(@{
        oneview = @{
            appliance   = $ovHost
            credentials = @{ username = $credUser; password = $credPass }
        }
    })

    $resolvedTarget = $TargetId
    $resolvedType = $TargetType
    if ($SerialNumber) {
        $resolved = $oneviewMgr._ResolveServerBySerial($SerialNumber)
        if ($resolved.Success) {
            $resolvedTarget = $resolved.ServerName
            $resolvedType = 'ServerHardware'
        } else {
            Write-Error "Serial number '$SerialNumber' not found in OneView: $($resolved.Message)"
            return @{ Success = $false; Message = $resolved.Message }
        }
    }

    $startDt = $null; $endDt = $null
    if ($Start -and $End) {
        $startDt = _Parse-Datetime $Start
        $endDt   = _Parse-Datetime $End
    } elseif ($Start) {
        $startDt = _Parse-Datetime $Start
        $endDt   = _Compute-DefaultEnd $startDt
    }

    $result = $oneviewMgr.SetMaintenance($resolvedTarget, $resolvedType, $startDt, $endDt, $DryRun)
    $result['TargetId']   = $TargetId
    $result['SerialNumber'] = $SerialNumber
    $result['ResolvedTarget'] = $resolvedTarget
    $result['ResolvedType']   = $resolvedType
    $result['Appliance']      = $ovHost

    if ($Json) { return $result | ConvertTo-Json -Depth 64 }
    if ($PassThru) { return $result }
    return $result
}

function Disable-OneViewMaintenanceMode {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][string] $TargetId,
        [Parameter(Mandatory, ParameterSetName = 'Run', Position = 1)][ValidateSet('ServerHardware', 'Scope')][string] $TargetType = 'ServerHardware',
        [ValidateSet('Test', 'Prod')][string] $Environment,
        [Alias('OVHost')][string] $OneViewHost,
        [Alias('Srl')][string] $SerialNumber,
        [Alias('WaitSec')][ValidateRange(0, 3600)][int] $PostDisableWaitSeconds = 0,
        [Alias('CfgDir')][string] $ConfigDir = 'configs',
        [Alias('Dry')][switch] $DryRun,
        [Alias('NoSchedule')][switch] $NoSchedule,
        [Alias('Json')][switch] $Json,
        [Alias('PT')][switch] $PassThru,
        [Parameter(ParameterSetName = 'Help')][switch]$Help
    )
    if ($Help) { Get-CommandHelp -Name 'Disable-OneViewMaintenanceMode'; return }

    $ovConfig = $null
    if ($PSBoundParameters.ContainsKey('ConfigDir')) {
        $effectiveConfigDir = Resolve-EffectiveConfigDir -ConfigDir $ConfigDir `
            -MarkerFile 'oneview_config.json' `
            -ExplicitlyBound:$PSBoundParameters.ContainsKey('ConfigDir')
        $ovCfgPath = Join-Path $effectiveConfigDir 'oneview_config.json'
        if (Test-Path $ovCfgPath) {
            $ovConfig = Import-JsonConfig -Path $ovCfgPath -Required:$false
        }
    }

    $ovHost = $null
    if ($PSBoundParameters.ContainsKey('OneViewHost')) {
        $ovHost = $OneViewHost
    } elseif ($ovConfig -and $ovConfig.ContainsKey('oneview') -and $ovConfig['oneview'].ContainsKey('appliance')) {
        $ovHost = $ovConfig['oneview']['appliance']
    }

    if (-not $ovHost) {
        Write-Error "OneView appliance host not supplied. Pass -OneViewHost or set appliance in oneview_config.json."
        return @{ Success = $false; Message = 'OneView appliance host not configured' }
    }

    $credUser = $null; $credPass = $null
    if ($ovConfig -and $ovConfig.ContainsKey('oneview') -and $ovConfig['oneview'].ContainsKey('credentials')) {
        $credUser = [System.Environment]::GetEnvironmentVariable($ovConfig['oneview']['credentials']['username_env'])
        $credPass = [System.Environment]::GetEnvironmentVariable($ovConfig['oneview']['credentials']['password_env'])
    }

    $oneviewMgr = [OneViewClient]::new(@{
        oneview = @{
            appliance   = $ovHost
            credentials = @{ username = $credUser; password = $credPass }
        }
    })

    $resolvedTarget = $TargetId
    $resolvedType = $TargetType
    if ($SerialNumber) {
        $resolved = $oneviewMgr._ResolveServerBySerial($SerialNumber)
        if ($resolved.Success) {
            $resolvedTarget = $resolved.ServerName
            $resolvedType = 'ServerHardware'
        } else {
            Write-Error "Serial number '$SerialNumber' not found in OneView: $($resolved.Message)"
            return @{ Success = $false; Message = $resolved.Message }
        }
    }

    if ($PostDisableWaitSeconds -gt 0) {
        Write-Warning "PostDisableWaitSeconds=$PostDisableWaitSeconds is accepted but not enforced in the OneView path (OneView does not define an equivalent stabilization delay)."
    }

    $result = $oneviewMgr.DisableMaintenance($resolvedTarget, $resolvedType, $DryRun)
    $result['TargetId']        = $TargetId
    $result['SerialNumber']    = $SerialNumber
    $result['ResolvedTarget']  = $resolvedTarget
    $result['ResolvedType']    = $resolvedType
    $result['Appliance']       = $ovHost

    if ($Json) { return $result | ConvertTo-Json -Depth 64 }
    if ($PassThru) { return $result }
    return $result
}

function Get-OneViewMaintenanceMode {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][string] $TargetId,
        [Parameter(Mandatory, ParameterSetName = 'Run', Position = 1)][ValidateSet('ServerHardware', 'Scope')][string] $TargetType = 'ServerHardware',
        [ValidateSet('Test', 'Prod')][string] $Environment,
        [Alias('OVHost')][string] $OneViewHost,
        [Alias('Srl')][string] $SerialNumber,
        [Alias('MockState')][ValidateSet('enable', 'disable', 'partial')][string] $MockMaintenanceState = 'disable',
        [Alias('CfgDir')][string] $ConfigDir = 'configs',
        [Alias('Dry')][switch] $DryRun,
        [Alias('Json')][switch] $Json,
        [Alias('PT')][switch] $PassThru,
        [Parameter(ParameterSetName = 'Help')][switch]$Help
    )
    if ($Help) { Get-CommandHelp -Name 'Get-OneViewMaintenanceMode'; return }

    $ovConfig = $null
    if ($PSBoundParameters.ContainsKey('ConfigDir')) {
        $effectiveConfigDir = Resolve-EffectiveConfigDir -ConfigDir $ConfigDir `
            -MarkerFile 'oneview_config.json' `
            -ExplicitlyBound:$PSBoundParameters.ContainsKey('ConfigDir')
        $ovCfgPath = Join-Path $effectiveConfigDir 'oneview_config.json'
        if (Test-Path $ovCfgPath) {
            $ovConfig = Import-JsonConfig -Path $ovCfgPath -Required:$false
        }
    }

    $ovHost = $null
    if ($PSBoundParameters.ContainsKey('OneViewHost')) {
        $ovHost = $OneViewHost
    } elseif ($ovConfig -and $ovConfig.ContainsKey('oneview') -and $ovConfig['oneview'].ContainsKey('appliance')) {
        $ovHost = $ovConfig['oneview']['appliance']
    }

    if (-not $ovHost) {
        Write-Error "OneView appliance host not supplied. Pass -OneViewHost or set appliance in oneview_config.json."
        return @{ Success = $false; Message = 'OneView appliance host not configured' }
    }

    $credUser = $null; $credPass = $null
    if ($ovConfig -and $ovConfig.ContainsKey('oneview') -and $ovConfig['oneview'].ContainsKey('credentials')) {
        $credUser = [System.Environment]::GetEnvironmentVariable($ovConfig['oneview']['credentials']['username_env'])
        $credPass = [System.Environment]::GetEnvironmentVariable($ovConfig['oneview']['credentials']['password_env'])
    }

    $oneviewMgr = [OneViewClient]::new(@{
        oneview = @{
            appliance   = $ovHost
            credentials = @{ username = $credUser; password = $credPass }
        }
    })

    $resolvedTarget = $TargetId
    $resolvedType = $TargetType
    if ($SerialNumber) {
        $resolved = $oneviewMgr._ResolveServerBySerial($SerialNumber)
        if ($resolved.Success) {
            $resolvedTarget = $resolved.ServerName
            $resolvedType = 'ServerHardware'
        } else {
            Write-Error "Serial number '$SerialNumber' not found in OneView: $($resolved.Message)"
            return @{ Success = $false; Message = $resolved.Message }
        }
    }

    $result = $oneviewMgr.GetMaintenanceStatus($resolvedTarget, $resolvedType)
    $result['TargetId']       = $TargetId
    $result['SerialNumber']   = $SerialNumber
    $result['ResolvedTarget'] = $resolvedTarget
    $result['ResolvedType']   = $resolvedType
    $result['Appliance']      = $ovHost

    if ($Json) { return $result | ConvertTo-Json -Depth 64 }
    if ($PassThru) { return $result }
    return $result
}
