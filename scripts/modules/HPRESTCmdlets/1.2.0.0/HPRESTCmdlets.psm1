<# (c) Copyright 2015-2017 Hewlett Packard Enterprise Development LP #>

<# NOTE: See typical usage examples in the HPRESTExamples.ps1 file installed with this module. #>

# ShowLicense.ps1 is listed in ScriptsToProcess, and PowerShell runs those files
# BEFORE this root module. It already defines AsyncPipeline, so an unconditional
# Add-Type here failed with "Cannot add type. The type name 'AsyncPipeline' already
# exists" and aborted every import of the module. Guard the duplicate and keep the
# licensee's license acceptance flow (ShowLicense.ps1) unchanged.
if (-not ('AsyncPipeline' -as [type])) {
    Add-Type @'
public class AsyncPipeline
{
    public System.Management.Automation.PowerShell Pipeline ;
    public System.IAsyncResult AsyncResult ;
}
'@
}

Add-Type -TypeDefinition @"
   public enum AddressType
   {
      IPv4,
      IPv6,
      Hostname
   }
"@

function Get-Message
{
    Param
    (
        [Parameter(Mandatory=$true)][String]$MsgID
    )
	$LocalizedStrings=@{
	    'MSG_PROGRESS_ACTIVITY'='Receiving Results'
	    'MSG_PROGRESS_STATUS'='Percent Complete'
	    'MSG_SENDING_TO'='Sending to {0}'
	    'MSG_FAIL_HOSTNAME'='DNS name translation not available for {0} - Host name left blank.'
	    'MSG_FAIL_IPADDRESS'='Invalid Hostname: IP Address translation not available for hostname {0}.'
	    'MSG_PARAMETER_INVALID_TYPE'="Error : `"{0}`" is not supported for parameter `"{1}`"."
	    'MSG_INVALID_USE'='Error : Invalid use of cmdlet. Please check your input again'
	    'MSG_INVALID_RANGE'='Error : The Range value is invalid'
	    'MSG_INVALID_PARAMETER'="`"{0}`" is invalid, it will be ignored."
        'MSG_INVALID_SESSION_OBJECT'='Error : The session object is invalid.'
	    'MSG_INVALID_TIMEOUT'='Error : The Timeout value is invalid'
	    'MSG_FIND_LONGTIME'='It might take a while to search for all the HPE REST sources if the input is a very large range. Use Verbose for more information.'
	    'MSG_USING_THREADS_FIND'='Using {0} threads for search.'
	    'MSG_FIND_NO_SOURCE'='No HPE Rest source at {0}'
	    'MSG_INVALID_CREDENTIALS'='Invalid credentials'
        'MSG_SCHEMA_NOT_FOUND'='Schema not found for {0}'
	    'MSG_FORMATDIR_LOCATION'='Location'
	    "MSG_PARAMETER_MISSING"="Error : Invalid use of cmdlet. `"{0}`" parameter is missing"
	    'MSG_INVALID_OEM'='HPRESTCmdlets only work with the Hewlett Packard Enterprise RESTful API'
        'MSG_ERROR_INVALID_ADDRESS_FORMAT' = 'Input string was not in a correct format'
        'MSG_MESSAGEID_NOTFOUND' = "MessageID {0} cannot be found"
        'MSG_INVALID_TYPE' = "Type {0} is in an invalid format"
	}
    $Message = ''
    try
    {
        $Message = $RM.GetString($MsgID)
        if($null -eq $Message)
        {
            $Message = $LocalizedStrings[$MsgID]
        }
    }
    catch
    {
        #throw $_
		$Message = $LocalizedStrings[$MsgID]
    }

    if($null -eq $Message)
    {
		#or unknown
        $Message = 'Fail to get the message'
    }
    return $Message
}

function Create-ThreadPool
{
    [Cmdletbinding()]
    Param
    (
        [Parameter(Position=0,Mandatory=$true)][int]$PoolSize,
        [Parameter(Position=1,Mandatory=$False)][Switch]$MTA
    )
    
    $pool = [RunspaceFactory]::CreateRunspacePool(1, $PoolSize)	
    
    If(!$MTA) { $pool.ApartmentState = 'STA' }
    
    $pool.Open()
    
    return $pool
}

function Start-ThreadScriptBlock
{
    [Cmdletbinding()]
    Param
    (
        [Parameter(Position=0,Mandatory=$True)]$ThreadPool,
        [Parameter(Position=1,Mandatory=$True)][ScriptBlock]$ScriptBlock,
        [Parameter(Position=2,Mandatory=$False)][Object[]]$Parameters
    )
    
    $Pipeline = [System.Management.Automation.PowerShell]::Create() 

	$Pipeline.RunspacePool = $ThreadPool
	    
    $Pipeline.AddScript($ScriptBlock) | Out-Null
    
    Foreach($Arg in $Parameters)
    {
        $Pipeline.AddArgument($Arg) | Out-Null
    }
    
	$AsyncResult = $Pipeline.BeginInvoke() 
	
	$Output = New-Object AsyncPipeline 
	
	$Output.Pipeline = $Pipeline
	$Output.AsyncResult = $AsyncResult
	
	$Output
}

function Get-ThreadPipelines
{
    [Cmdletbinding()]
    Param
    (
        [Parameter(Position=0,Mandatory=$True)][AsyncPipeline[]]$Pipelines,
		[Parameter(Position=1,Mandatory=$false)][Switch]$ShowProgress
    )
	
	# incrementing for Write-Progress
    $i = 1 
	
    foreach($Pipeline in $Pipelines)
    {
		
		try
		{
        	$Pipeline.Pipeline.EndInvoke($Pipeline.AsyncResult)
			
			If($Pipeline.Pipeline.Streams.Error)
			{
				Throw $Pipeline.Pipeline.Streams.Error
			}
        } catch {
			$_
		}
        $Pipeline.Pipeline.Dispose()
		
		If($ShowProgress)
		{
            Write-Progress -Activity $(Get-Message('MSG_PROGRESS_ACTIVITY')) -PercentComplete $(($i/$Pipelines.Length) * 100) `
                -Status $(Get-Message('MSG_PROGRESS_STATUS'))
		}
		$i++
    }
}

function Get-IPArrayFromIPSection {
      param (
      [parameter(Mandatory=$true)][String] $stringIPSection,
      [parameter(Mandatory=$false)] [ValidateSet('IPv4','IPv6')] [String]$IPType = 'IPv4'
   )

    $returnarray=@()   
    try
    {
        $errMsg = "Failed to get $IPType array from IP section $stringIPSection"
        $by_commas = $stringIPSection.split(',')

        if($IPType -eq 'IPV4')
        {
        foreach($by_comma in $by_commas)
        {
            $by_comma_dashs = $by_comma.split('-')
            $by_comma_dash_ele=[int]($by_comma_dashs[0])
            $by_comma_dash_ele_end = [int]($by_comma_dashs[$by_comma_dashs.Length-1])
            if($by_comma_dash_ele -gt $by_comma_dash_ele_end)
            {
                $by_comma_dash_ele = $by_comma_dash_ele_end
                $by_comma_dash_ele_end = [int]($by_comma_dashs[0])                   
            }

            for(; $by_comma_dash_ele -le $by_comma_dash_ele_end;$by_comma_dash_ele++)
            {
                $returnarray+=[String]($by_comma_dash_ele)
                
            }
         }
        }

        if($IPType -eq 'IPv6')
        {
        foreach($by_comma in $by_commas)
        {
            $by_comma_dashs = $by_comma.split('-')
            $by_comma_dash_ele=[Convert]::ToInt32($by_comma_dashs[0], 16)
            $by_comma_dash_ele_end = ([Convert]::ToInt32($by_comma_dashs[$by_comma_dashs.Length-1], 16))
            if($by_comma_dash_ele -gt $by_comma_dash_ele_end)
            {
                $by_comma_dash_ele = $by_comma_dash_ele_end
                $by_comma_dash_ele_end = [Convert]::ToInt32($by_comma_dashs[0], 16)                   
            }

            for(; $by_comma_dash_ele -le $by_comma_dash_ele_end;$by_comma_dash_ele++)
            {
                $returnarray+=[Convert]::ToString($by_comma_dash_ele,16);
                
            }
         }
    }
   }
   catch
   {
         Write-Error "Error - $errmsg"
   }
   return ,$returnarray
   }

#A common function for both IPv4/IPv6 , which will firstly make sure all the sections of IPv4/IPv6 is complete before calling this function)   
#input is a IPv4 address(separeated by ".") or IPv6 address(separeated by ":") and in each section, there might be "," and "-", like "1,2,3-4"
#return the array of all the possible IP adreesses parsed from the input string
function Get-IPArrayFromString {
      param (
      [parameter(Mandatory=$true)][String] $stringIP,
      [parameter(Mandatory=$false)] [ValidateSet('IPv4','IPv6')] [String]$IPType = 'IPv4',
      [parameter(Mandatory=$false)] [String]$PreFix = '',
      [parameter(Mandatory=$false)] [String]$PostFix = ''
   )

    #$returnarray=@()
    try
    {
    $errMsg = "Invalid format of IP string $stringIP to get $IPType array"
    $IPSectionArray = New-Object System.Collections.ArrayList
    $returnarray = New-Object 'System.Collections.ObjectModel.Collection`1[System.String]'

    $IPdelimiter='.'
    if($IPType -eq 'IPv6')
    {
        $IPdelimiter=':'
    }
    
    $sections_bycolondot = $stringIP.Split($IPdelimiter)
    for($x=0; ($x -lt $sections_bycolondot.Length -and ($null -ne $sections_bycolondot[$x] -and $sections_bycolondot[$x] -ne '')) ; $x++)
    {
        $section=@()		
        $section= Get-IPArrayFromIPSection -stringIPSection $sections_bycolondot[$x] -IPType $IPType
        $x=$IPSectionArray.Add($section)        
    }
    
    if($IPSectionArray.Count -eq 1)
    {
        for($x=0; $x -lt $IPSectionArray[0].Count; $x++)
        {
            $returnarray.Add($PreFix+$IPSectionArray[0][$x]+$PostFix)
        }
    }
    if($IPSectionArray.Count -eq 2)
    {
        for($x=0; $x -lt $IPSectionArray[0].Count; $x++)
        {
            for($y=0; $y -lt $IPSectionArray[1].Count; $y++)
            {
                $returnarray.Add($PreFix+$IPSectionArray[0][$x]+$IPdelimiter+$IPSectionArray[1][$y]+$PostFix)
            }
        }
    }
    if($IPSectionArray.Count -eq 3)
    {
        for($x=0; $x -lt $IPSectionArray[0].Count; $x++)
        {
            for($y=0; $y -lt $IPSectionArray[1].Count; $y++)
            {
                for($z=0; $z -lt $IPSectionArray[2].Count; $z++)
                {
                    $returnarray.Add($PreFix+$IPSectionArray[0][$x]+$IPdelimiter+$IPSectionArray[1][$y]+$IPdelimiter+$IPSectionArray[2][$z]+$PostFix)
                }
            }
        }
    }
    if($IPSectionArray.Count -eq 4)
    {
        for($x=0; $x -lt $IPSectionArray[0].Count; $x++)
        {
            for($y=0; $y -lt $IPSectionArray[1].Count; $y++)
            {
                for($z=0; $z -lt $IPSectionArray[2].Count; $z++)
                {
                    for($a=0; $a -lt $IPSectionArray[3].Count; $a++)
                    {  
                        $returnarray.Add($PreFix+$IPSectionArray[0][$x]+$IPdelimiter+$IPSectionArray[1][$y]+$IPdelimiter+$IPSectionArray[2][$z]+$IPdelimiter+$IPSectionArray[3][$a]+$PostFix)
                    }
                }
            }
        }
    }

    if($IPSectionArray.Count -eq 5)
    {
        for($x=0; $x -lt $IPSectionArray[0].Count; $x++)
        {
            for($y=0; $y -lt $IPSectionArray[1].Count; $y++)
            {
                for($z=0; $z -lt $IPSectionArray[2].Count; $z++)
                {
                    for($a=0; $a -lt $IPSectionArray[3].Count; $a++)
                    {
                        for($b=0; $b -lt $IPSectionArray[4].Count; $b++)
                        {
                            $returnarray.Add($PreFix+$IPSectionArray[0][$x]+$IPdelimiter+$IPSectionArray[1][$y]+$IPdelimiter+$IPSectionArray[2][$z]+$IPdelimiter+$IPSectionArray[3][$a]+$IPdelimiter+$IPSectionArray[4][$b]+$PostFix)
                        }
                    }
                }
            }
        }
    }

    if($IPSectionArray.Count -eq 6)
    {
        for($x=0; $x -lt $IPSectionArray[0].Count; $x++)
        {
            for($y=0; $y -lt $IPSectionArray[1].Count; $y++)
            {
                for($z=0; $z -lt $IPSectionArray[2].Count; $z++)
                {
                    for($a=0; $a -lt $IPSectionArray[3].Count; $a++)
                    {
                        for($b=0; $b -lt $IPSectionArray[4].Count; $b++)
                        {
                            for($c=0; $c -lt $IPSectionArray[5].Count; $c++)
                            {
                                $returnarray.Add($PreFix+$IPSectionArray[0][$x]+$IPdelimiter+$IPSectionArray[1][$y]+$IPdelimiter+$IPSectionArray[2][$z]+$IPdelimiter+$IPSectionArray[3][$a]+$IPdelimiter+$IPSectionArray[4][$b]+$IPdelimiter+$IPSectionArray[5][$c]+$PostFix)
                            }
                        }
                    }
                }
            }
        }
    }
    if($IPSectionArray.Count -eq 7)
    {
        for($x=0; $x -lt $IPSectionArray[0].Count; $x++)
        {
            for($y=0; $y -lt $IPSectionArray[1].Count; $y++)
            {
                for($z=0; $z -lt $IPSectionArray[2].Count; $z++)
                {
                    for($a=0; $a -lt $IPSectionArray[3].Count; $a++)
                    {
                        for($b=0; $b -lt $IPSectionArray[4].Count; $b++)
                        {
                            for($c=0; $c -lt $IPSectionArray[5].Count; $c++)
                            {
                                for($d=0; $d -lt $IPSectionArray[6].Count; $c++)
                                {
                                    $returnarray.Add($PreFix+$IPSectionArray[0][$x]+$IPdelimiter+$IPSectionArray[1][$y]+$IPdelimiter+$IPSectionArray[2][$z]+$IPdelimiter+$IPSectionArray[3][$a]+$IPdelimiter+$IPSectionArray[4][$b]+$IPdelimiter+$IPSectionArray[5][$c]+$IPdelimiter+$IPSectionArray[6][$d]+$PostFix)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if($IPSectionArray.Count -eq 8)
    {
        for($x=0; $x -lt $IPSectionArray[0].Count; $x++)
        {
            for($y=0; $y -lt $IPSectionArray[1].Count; $y++)
            {
                for($z=0; $z -lt $IPSectionArray[2].Count; $z++)
                {
                    for($a=0; $a -lt $IPSectionArray[3].Count; $a++)
                    {
                        for($b=0; $b -lt $IPSectionArray[4].Count; $b++)
                        {
                            for($c=0; $c -lt $IPSectionArray[5].Count; $c++)
                            {
                                for($d=0; $d -lt $IPSectionArray[6].Count; $d++)
                                {
                                    for($e=0; $e -lt $IPSectionArray[7].Count; $e++)
                                    {
                                        $returnarray.Add($PreFix+$IPSectionArray[0][$x]+$IPdelimiter+$IPSectionArray[1][$y]+$IPdelimiter+$IPSectionArray[2][$z]+$IPdelimiter+$IPSectionArray[3][$a]+$IPdelimiter+$IPSectionArray[4][$b]+$IPdelimiter+$IPSectionArray[5][$c]+$IPdelimiter+$IPSectionArray[6][$d]+$IPdelimiter+$IPSectionArray[7][$e]+$PostFix)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    if($IPSectionArray.Count -eq 9)
    {
        for($x=0; $x -lt $IPSectionArray[0].Count; $x++)
        {
            for($y=0; $y -lt $IPSectionArray[1].Count; $y++)
            {
                for($z=0; $z -lt $IPSectionArray[2].Count; $z++)
                {
                    for($a=0; $a -lt $IPSectionArray[3].Count; $a++)
                    {
                        for($b=0; $b -lt $IPSectionArray[4].Count; $b++)
                        {
                            for($c=0; $c -lt $IPSectionArray[5].Count; $c++)
                            {
                                for($d=0; $d -lt $IPSectionArray[6].Count; $c++)
                                {
                                    for($e=0; $e -lt $IPSectionArray[7].Count; $e++)
                                    {
                                        for($f=0; $f -lt $IPSectionArray[8].Count; $f++)
                                        {
                                            $returnarray.Add($PreFix+$IPSectionArray[0][$x]+$IPdelimiter+$IPSectionArray[1][$y]+$IPdelimiter+$IPSectionArray[2][$z]+$IPdelimiter+$IPSectionArray[3][$a]+$IPdelimiter+$IPSectionArray[4][$b]+$IPdelimiter+$IPSectionArray[5][$c]+$IPdelimiter+$IPSectionArray[6][$d]+$IPdelimiter+$IPSectionArray[7][$e]+$IPdelimiter+$IPSectionArray[8][$f]+$PostFix)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    }
    catch
    {
         Write-Error "Error - $errmsg"
    }

   return ,$returnarray
   }

#for ipv6 support in cmdlets other than Find-HPRest
function Get-IPv6FromString {
      param (
      [parameter(Mandatory=$true)][String] $stringIP,
	  [parameter(Mandatory=$false)] [switch] $AddSquare
	  
   )
            $percentpart=''
            $ipv4array=@()
            #$ipv6array=@()
            #$returnstring=@()
            $returnstring = New-Object 'System.Collections.ObjectModel.Collection`1[System.String]'
            $ipv6array = New-Object 'System.Collections.ObjectModel.Collection`1[System.String]'
			$preFix=''
			$postFix=''
			if($AddSquare)
			{
				$preFix='['
				$postFix=']'
			}
            try
            {
            $errMsg = "Invalid format of IP string $stringIP to get IPv6 address"
            #it could have ::, :,., % inside it, have % in it            
            if($stringIP.LastIndexOf('%') -ne -1)  
            {
                $sections = $stringIP.Split('%')
                $percentpart='%'+$sections[1]
                $stringIP=$sections[0]                
            }

            #it could have ::, :,.inside it, have ipv4 in it
            if($stringIP.IndexOf('.') -ne -1) 
            {
                [int]$nseperate = $stringIP.LastIndexOf(':')
				#to get the ipv4 part
                $mappedIpv4 = $stringIP.SubString($nseperate + 1) 
				$ipv4array=Get-IPArrayFromString -stringIP $mappedIpv4 -IPType 'IPV4' 

                #to get the first 6 sections, including :: or :
				$stringIP = $stringIP.Substring(0, $nseperate + 1) 
            }

				#it could have ::,: inside it             
                $stringIP = $stringIP -replace '::', '|' 
                $sectionsby_2colon=@()
				#suppose to get a 2 element array
                $sectionsby_2colon = $stringIP.Split('|') 
				#no :: in it
                if($sectionsby_2colon.Length -eq 1) 
                {
                    $ipv6array=Get-IPArrayFromString -stringIP $sectionsby_2colon[0] -IPType 'IPv6' 
                }
                elseif($sectionsby_2colon.Length -gt 1)
                {
					#starting with ::
                    if(($sectionsby_2colon[0] -eq '')) 
                    {
                        if(($sectionsby_2colon[1] -eq ''))
                        {
                            $ipv6array=@('::')
                        }
                        else
                        {
                            $ipv6array=Get-IPArrayFromString -stringIP $sectionsby_2colon[1] -IPType 'IPv6' -PreFix '::'
                        }
                    }
					#not starting with ::, may in the middle or in the ending
                    else 
                    {
                        if(($sectionsby_2colon[1] -eq ''))
                        {
                            $ipv6array=Get-IPArrayFromString -stringIP $sectionsby_2colon[0] -IPType 'IPv6' -PostFix '::'
                        }
                        else
                        {
                            $ipv6array1=Get-IPArrayFromString -stringIP $sectionsby_2colon[0] -IPType 'IPv6'  -PostFix '::'                            
                            $ipv6array2=Get-IPArrayFromString -stringIP $sectionsby_2colon[1] -IPType 'IPv6' 
                            foreach($x1 in $ipv6array1)
                            {
                                foreach($x2 in $ipv6array2)
                                {
                                    $ipv6array.Add($x1 + $x2)
                                }
                            }
                        }                        
                    }
                }        

        foreach($ip1 in $ipv6array)
        {
            if($ipv4array.Count -ge 1)
            {
                foreach($ip2 in $ipv4array)
                {
                    if($ip1.SubString($ip1.Length-1) -eq ':')
                    {
                        $returnstring.Add($preFix+$ip1+$ip2+$percentpart+$postFix)
                    }
                    else
                    {
                        $returnstring.Add($preFix+$ip1+':'+$ip2+$percentpart+$postFix)
                    }
                }
            }
            else
            {
                $returnstring.Add($preFix+$ip1+$percentpart+$postFix)
            }            
        }
        }
        catch
        {
            Write-Error "Error - $errmsg"
        }
    return $returnstring    
}

#called from Find-HPRest, complete all the sections for one IPv4 address, 
#$arrayforip returns an array with 4 items, which map to the 4 sections of IPv4 address. 
#for example, if input $strIP="x", the $arrayforip will be @("x","0-255","0-255","0-255")
function Complete-IPv4{
    param (
        [parameter(Mandatory=$true)] [String] $strIP
        #[parameter(Mandatory=$true)] [ref] $arrayforip
    )
    $arrayfor = @()
    $arrayfor += '0-255'
    $arrayfor += '0-255'
    $arrayfor += '0-255'
    $arrayfor += '0-255'

             #with the new format, 1..., or .1, at most 5 items in $sections, but might have empty values  
             $sections = $strIP.Split('.')
			 
			 #no "." in it
             if($sections.length -eq 1)
             {              
                $arrayfor[0]=$sections[0]					
			 }
			#might have empty item when input is "x." or ".x"
			elseif($sections.length -eq 2)
			{
                if($sections[0] -ne '')
                {
                    $arrayfor[0]=$sections[0]
                    if($sections[1] -ne '')
                    {
                        $arrayfor[1]=$sections[1]   
                    }
                }
                else
                {
                    if($sections[1] -ne '')
                    {
                        $arrayfor[3]=$sections[1]
                    }
                }				
			}
            elseif($sections.length -eq 3) 
			{
				#"1..", "1.1.","1.1.1" "1..1"
                if($sections[0] -ne '')
                {
                    $arrayfor[0]=$sections[0]
                    if($sections[1] -ne '')
                    {
                        $arrayfor[1]=$sections[1]
                        if($sections[2] -ne '')
                        {
                            $arrayfor[2]=$sections[2]
                        }
                    }
                    else
                    {
                        if($sections[2] -ne '')
                        {
                            $arrayfor[3]=$sections[2]
                        }
                    }

                }                                
                else
                { 
					#.1.1
                    if($sections[2] -ne '') 
                    {
                        $arrayfor[3]=$sections[2]
                        if($sections[1] -ne '')
                        {
                            $arrayfor[2]=$sections[1]
                        }                                      
                    }
                    else
                    {
						#the 1 and 3 items are empty ".1."
                        if($sections[1] -ne '')
                        {
                            $arrayfor[1]=$sections[1]
                        }
                    }
                }							
			}
			#1.1.1., 1..., ...1, 1...1, .x.x.x, x..x.x, x.x..x,..x. 
            elseif($sections.length -eq 4)
			{
				#1st is not empty
                if($sections[0] -ne '')
                {
                    $arrayfor[0]=$sections[0]
					#2nd is not empty
                    if($sections[1] -ne '')
                    {
                        $arrayfor[1]=$sections[1]
						#3rd is not empty
                        if($sections[2] -ne '')
                        {
                            $arrayfor[2]=$sections[2]
							#4th is not empty
                            if($sections[3] -ne '')
                            {
                                $arrayfor[3]=$sections[3]
                            }
                        }
						#3rd is empty 1.1..1
                        else 
                        {
							#4th is not empty
                            if($sections[3] -ne '')
                            {
                                $arrayfor[3]=$sections[3]
                            }                            
                        }

                    }
					#2nd is empty, 1..1., 1...
                    else 
                    {
						#4th is not empty
                        if($sections[3] -ne '')
                        {
                            $arrayfor[3]=$sections[3]
							#3rd is not empty
                            if($sections[2] -ne '')
                            {
                                $arrayfor[2]=$sections[2]
                            }  
                        }  
						#4th is empty
                        else 
                        {
							#3rd is not empty
                            if($sections[2] -ne '')
                            {
                                $arrayfor[2]=$sections[2]
                            } 
                        }                        
                    }
                }
				#1st is empty
                else 
                {
					#4th is not empty
                    if($sections[3] -ne '')
                    {
                        $arrayfor[3]=$sections[3]
						#3rd is not empty
                        if($sections[2] -ne '')
                        {
                            $arrayfor[2]=$sections[2]
							#2rd is not empty
                            if($sections[1] -ne '')
                            {
                                $arrayfor[1]=$sections[1]
                            }                            
                        }
                        else
                        {
							#2rd is not empty
                            if($sections[1] -ne '')
                            {
                                $arrayfor[1]=$sections[1]
                            }  
                        }
                    }
					#4th is empty .1.1., ..1., .1..
                    else 
                    {
						#3rd is not empty
                        if($sections[2] -ne '')
                        {
                            $arrayfor[2]=$sections[2]                                                      
                        }
						
						#2nd is not empty
                        if($sections[1] -ne '')
                        {
                            $arrayfor[1]=$sections[1]                                                      
                        }
                    }                    
                }			
			}
			#x.x.x.., ..x.x.x, x.x.x.x
            elseif($sections.length -eq 5) 
			{
				#1st is not empty
				if($sections[0] -ne '')
                {
                    $arrayfor[0]=$sections[0]
                    if($sections[1] -ne '') 
                    {
                        $arrayfor[1]=$sections[1]
                    }
                    if($sections[2] -ne '') 
                    {
                        $arrayfor[2]=$sections[2]
                    }
                    if($sections[3] -ne '') 
                    {
                        $arrayfor[3]=$sections[3]
                    }
                                                    
                }
				#1st is empty
                else 
                {                    
                    if($sections[4] -ne '')
                    {
                        $arrayfor[3]=$sections[4]
                    }
                    if($sections[3] -ne '') 
                    {
                        $arrayfor[2]=$sections[3]
                    }
                    if($sections[2] -ne'')
                    {
                        $arrayfor[1]=$sections[2]
                    }
                    if($sections[1] -ne '') 
                    {
                        $arrayfor[0]=$sections[1]
                    }
                }		
			}

            #$arrayforip.Value = $arrayfor;
            return $arrayfor[0]+'.'+$arrayfor[1]+'.'+$arrayfor[2]+'.'+$arrayfor[3]
}

#called from Find-HPRest, a helper function to check whether input IPv4 is valid or not
#returns the total number of "." in an IPv4 address
#for example: if input $strIP is "1...1", the return value is 3
function Get-IPv4-Dot-Num{
    param (
        [parameter(Mandatory=$true)] [String] $strIP
    )
    [int]$dotnum = 0
    for($i=0;$i -lt $strIP.Length; $i++)
    {
        if($strIP[$i] -eq '.')
        {
            $dotnum++
        }
    }
    
    return $dotnum
}

#called from Find-HPRest, complete the all sections for one IPv6 address
#$arrayforip returns an array with 8 or more items, which map to the sections of IPv6 address. 
#for example, if input $strIP="x:x:x", the $arrayforip will be @("x","x","x","0-FFFF","0-FFFF","0-FFFF","0-FFFF","0-FFFF")
function Complete-IPv6{
    param (
        [parameter(Mandatory=$true)] [String] $strIP,
        #[parameter(Mandatory=$true)] [ref] $arrayforip,
        [parameter(Mandatory=$false)] [Int] $MaxSecNum=8
    )
            $arrayfor = @()
            $arrayfor+=@('0-FFFF')
            $arrayfor+=@('0-FFFF')
            $arrayfor+=@('0-FFFF')
            $arrayfor+=@('0-FFFF')
            $arrayfor+=@('0-FFFF')
            $arrayfor+=@('0-FFFF')
			
			#used for ipv4-mapped,also used for ipv6 if not in ipv4 mapped format
            $arrayfor+=@('0-FFFF') 
			
			#used for ipv4-mapped,also used for ipv6 if not in ipv4 mapped format
            $arrayfor+=@('0-FFFF') 
			
			#used for ipv4-mapped
            $arrayfor+=@('') 
			
			#used for ipv4-mapped
            $arrayfor+=@('')  
			
			#used for %
            $arrayfor+=@('') 
			
            #$strIP = $strIP -replace "::", "|" 
            $returnstring=''
			
			#have % in it 
            if($strIP.LastIndexOf('%') -ne -1)  
            {
                $sections = $strIP.Split('%')
                $arrayfor[10]='%'+$sections[1]
                $strIP=$sections[0]                
            }
            #it could have ::, :, %, . inside it, have ipv4 in it
            if($strIP.IndexOf('.') -ne -1) 
            {
            
                [int]$nseperate = $strIP.LastIndexOf(':')	
				#to get the ipv4 part				
                $mappedIpv4 = $strIP.SubString($nseperate + 1) 
				$ipv4part = Complete-IPv4 -strIP $mappedIpv4                				
				
				#to get the first 6 sections
                $strIP = $strIP.Substring(0, $nseperate + 1)  
                $ipv6part = Complete-IPv6 -strIP $strIP -MaxSecNum 6 
                $returnstring += $ipv6part+':'+$ipv4part
            }
			#no ipv4 part in it, to get the 8 sections
            else 
            {
                $strIP = $strIP -replace '::', '|' 
                $parsedipv6sections=@()
				#suppose to get a 2 element array
                $bigsections = $strIP.Split('|') 
				#no :: in it
                if($bigsections.Length -eq 1) 
                {
                    $parsedipv6sections = $bigsections[0].Split(':')
                    for($x=0; ($x -lt $parsedipv6sections.Length) -and ($x -lt $MaxSecNum); $x++)
                    {
                        $arrayfor[$x] = $parsedipv6sections[$x]
                    }
                }
                elseif($bigsections.Length -gt 1)
                {
					#starting with ::
                    if(($bigsections[0] -eq '')) 
                    {
                        $parsedipv6sections = $bigsections[1].Split(':')
                        $Y=$MaxSecNum-1
                        for($x=$parsedipv6sections.Length; ($parsedipv6sections[$x-1] -ne '') -and ($x -gt 0) -and ($y -gt -1); $x--, $y--)
                        {
                            $arrayfor[$y] = $parsedipv6sections[$x-1]
                        }
                        for(; $y -gt -1; $y--)
                        {
                            $arrayfor[$y]='0'
                        }
                        
                    }
					#not starting with ::, may in the middle or in the ending
                    else 
                    {
                        $parsedipv6sections = $bigsections[0].Split(':')
                        $x=0
                        for(; ($x -lt $parsedipv6sections.Length) -and ($x -lt $MaxSecNum); $x++)
                        {
                            $arrayfor[$x] = $parsedipv6sections[$x]
                        }
                        
                        $y=$MaxSecNum-1
                        if($bigsections[1] -ne '')
                        {
                            $parsedipv6sections2 = $bigsections[1].Split(':')                            
                            for($z=$parsedipv6sections2.Length;  ($parsedipv6sections2[$z-1] -ne '')-and ($z -gt 0) -and ($y -gt ($x-1)); $y--,$z--)
                            {
                                $arrayfor[$y] = $parsedipv6sections2[$z-1]
                            }
                        }
                        for(;$x -lt ($y+1); $x++)
                        {
                              $arrayfor[$x]='0' 
                        }
                    }
                }
            if($MaxSecNum -eq 6)
            {
                $returnstring = $returnstring = $arrayfor[0]+':'+$arrayfor[1]+':'+$arrayfor[2]+':'+$arrayfor[3]+':'+$arrayfor[4]+':'+$arrayfor[5]
            }
            if($MaxSecNum -eq 8)
            {
                $appendingstring=''
                if($arrayfor[8] -ne '')
                {
                    $appendingstring=':'+$arrayfor[8]
                }
                if($arrayfor[9] -ne '')
                {
                    if($appendingstring -ne '')
                    {
                        $appendingstring = $appendingstring + ':'+$arrayfor[9]
                    }
                    else
                    {
                        $appendingstring=':'+$arrayfor[9]
                    }
                }
                if($arrayfor[10] -ne '')
                {
                    if($appendingstring -ne '')
                    {
                        $appendingstring = $appendingstring + $arrayfor[10]
                    }
                    else
                    {
                        $appendingstring=$arrayfor[10]
                    }
                }
                
                $returnstring = $arrayfor[0]+':'+$arrayfor[1]+':'+$arrayfor[2]+':'+$arrayfor[3]+':'+$arrayfor[4]+':'+$arrayfor[5]+':'+$arrayfor[6]+':'+$arrayfor[7]+$appendingstring
            }
            }
    #$arrayforip.Value= $arrayfor
    return $returnstring
}

function Get-HPRESTDataPropRecurse
{
    param
    (
        [PSObject]
        $Data,

        [PSObject]
        $Schema,

        [Hashtable]
        $Headers,

        [PSObject]
        $Session,

        [String]
        $DataType,
	
        [String]
        $Language = 'en',

        [System.Collections.Hashtable]
        $DictionaryOfSchemas
    )
    #$DataProperties = New-Object PSObject

    $PROP = 'Value'
    $PROP1 = 'Schema_Description'
    $SCHEMAPROP1a = 'description'  #'description' prop name in schema
    $SCHEMAPROP1b = 'longDescription'
    $PROP2 = 'Schema_AllowedValue'
    $SCHEMAPROP2 = 'enum'         #'enum' prop name in schema
    $PROP3 = 'Schema_Type'
    $SCHEMAPROP3 = 'type'         #'type' prop name in schema
    $PROP4 = 'Schema_ReadOnly'
    $SCHEMAPROP4 = 'readonly'     #'readonly' prop name in schema
    $dataInSchema = $false

    if($Data.Type -ne "" -and $null -ne $Data.Type)
    {
        $DataType = $Data.Type
    }

    foreach($dataProp in $data.PSObject.Properties)
    {
        foreach($schProp in $Schema.Properties.PSObject.Properties)
        {
            if($schProp.Name -eq $dataProp.Name)
            {
                $dataInSchema = $true
                if($dataProp.TypeNameOfValue -eq 'System.String' -or $dataProp.TypeNameOfValue -eq 'System.Int32')
                {
                    
                    $outputObj = New-Object PSObject
                    $schToUse = $null
                    if($schProp.value.PSObject.properties.Name.Contains("`$ref"))
                    {
                        $subpath = ''
                        if($schProp.value.'$ref'.contains('.json#/'))
                        {
                            $startInd = $schProp.value.'$ref'.IndexOf('.json#/')
                            $firstPart = $schProp.value.'$ref'.Substring(0,$startInd+6)
                            $subpath = $firstPart.replace('#','')
                            $lastPart = $schProp.value.'$ref'.Substring($schProp.value.'$ref'.IndexOf('.json#/')+6)
                            $propPath = $lastPart -split '/'

                            $schemaJSONLink = Get-HPRESTSchemaExtref -Type $subpath.replace('.json','') -Session $Session -Language $Language -Headers $Headers
                            $index = $schemaJSONLink.LastIndexOf('/')
                            $prefix = $schemaJSONLink.SubString(0,$index+1)
                            $newLink = $prefix + $subpath
                            $refSchema = Get-HPRESTDataRaw -Href $newLink -Headers $Headers -Session $session
                            for($i=1;$i-lt$propPath.length;$i++)
                            {
                                $refSchema = $refSchema.($propPath[$i])
                            }
                            $schToUse = $refSchema
                        }
                        else
                        {
                            $subpath = $schProp.value.'$ref'.replace('#','')
                            $schemaJSONLink = Get-HPRESTSchemaExtref -Type $subpath.replace('.json','') -Session $Session -Language $Language -Headers $Headers
                            $index = $schemaJSONLink.LastIndexOf('/')
                            $prefix = $schemaJSONLink.SubString(0,$index+1)
                            $newLink = $prefix + $subpath
                            $schToUse = Get-HPRESTDataRaw -Href $newLink -Headers $Headers -Session $session
                        }
                    }
                    else
                    {
                        $schToUse = $schProp.Value
                    }
                    $desc = ""
                    if(-not($schToUse.$SCHEMAPROP1b -eq '' -or $null -eq $schToUse.$SCHEMAPROP1b))
                    {
                        $desc += $schToUse.$SCHEMAPROP1b
                    }
                    if(-not($schToUse.$SCHEMAPROP1a -eq '' -or $null -eq $schToUse.$SCHEMAPROP1a))
                    {
                        $desc += $schToUse.$SCHEMAPROP1a
                    }
                    if($desc -ne "")
                    {
                        $outputObj | Add-Member NoteProperty $PROP1 $desc
                    }

                    if($schToUse.PSObject.Properties.Name.Contains('enum') -eq $true)
                    {
                        $outputObj | Add-Member NoteProperty $PROP2 $schToUse.$SCHEMAPROP2
                    }
                    if($schToUse.PSObject.Properties.Name.Contains('enumDescriptions') -eq $true)
                    {    
                        $outputObj | Add-Member NoteProperty 'schema_enumDescriptions' $schToUse.enumDescriptions
                    }
                    <#if($schToUse.PSObject.Properties.Name.Contains('enum') -eq $true)
                    {
                        $outputObj | Add-Member NoteProperty 'schema_valueType' $schToUse.type
                    }#>
                    if(-not($schToUse.$SCHEMAPROP3 -eq '' -or $null -eq $schToUse.$SCHEMAPROP3))
                    {
                        $outputObj | Add-Member NoteProperty $PROP3 $schToUse.$SCHEMAPROP3
                    }
                    if($schToUse.$SCHEMAPROP4 -eq $true -or $schToUse.$SCHEMAPROP4 -eq $false) # readonly is true or false 
                    {
                        $outputObj | Add-Member NoteProperty $PROP4 $schToUse.$SCHEMAPROP4
                    }
                    if(-not ($DictionaryOfSchemas.ContainsKey($dataProp.Name)))
                    {
                        $DictionaryOfSchemas.Add($dataProp.Name, $outputObj)
                    }
                }
                elseif($dataProp.TypeNameOfValue -eq 'System.Object[]')
                {
                    $dataList = @()
                    for($i=0;$i-lt$dataProp.value.Length;$i++)
                    {
                        $dataPropElement = ($dataProp.Value)[$i]
                        if($dataPropElement.GetType().ToString() -eq 'System.String' -or $dataPropElement.GetType().ToString() -eq 'System.Int32')
                        {
                            $dataList += $dataPropElement                            if(-not ($DictionaryOfSchemas.ContainsKey($dataProp.Name)))
                            {

                                if($schprop.value.items.PSObject.Properties.name.Contains('anyOf'))
                                {
                                    $x = $schProp.Value.items.anyOf
                                }
                                else
                                {
                                    $x = $schProp.Value.items
                                }
                                $outputObj = New-Object PSObject
                                if(-not($schema.Properties.($schprop.Name).$SCHEMAPROP1 -eq '' -or $null -eq $schema.Properties.($schprop.Name).$SCHEMAPROP1))
                                {
                                    $outputObj | Add-Member NoteProperty $PROP1 $schema.Properties.($schprop.Name).$SCHEMAPROP1
                                }
                                if($x.PSObject.Properties.Name.Contains('enum') -eq $true)
                                {
                                    $outputObj | Add-Member NoteProperty $PROP2 $x.enum
                                }
                                if($x.PSObject.Properties.Name.Contains('enumDescriptions') -eq $true)
                                {    
                                    $outputObj | Add-Member NoteProperty 'schema_enumDescriptions' $x.enumDescriptions
                                }
                                <#if($schToUse.PSObject.Properties.Name.Contains('enum') -eq $true)
                                {
                                    $outputObj | Add-Member NoteProperty 'schema_valueType' $schToUse.type
                                }#>
                                if(-not($x.$SCHEMAPROP3 -eq '' -or $null -eq $x.$SCHEMAPROP3))
                                {
                                    $outputObj | Add-Member NoteProperty $PROP3 $x.$SCHEMAPROP3
                                }
                                if($x.$SCHEMAPROP4 -eq $true -or $x.$SCHEMAPROP4 -eq $false) # readonly is true or false 
                                {
                                    $outputObj | Add-Member NoteProperty $PROP4 $x.$SCHEMAPROP4
                                }                            
                                $DictionaryOfSchemas.Add($dataProp.Name, $outputObj)
                            }
                        }
                        elseif($dataPropElement.GetType().ToString() -eq 'System.Management.Automation.PSCustomObject')
                        {
                            $psObj = New-Object PSObject
                            if($schprop.Value.PSObject.Properties.name.Contains("items"))
                            {
                                if($schprop.value.items.PSObject.Properties.name.Contains('anyOf'))
                                {
                                    $x = $schProp.Value.items.anyOf
                                }
                                else
                                {
                                    $x = $schProp.Value.items
                                }
                            }
                            else
                            {
                                $x = $schProp.value
                            }
                            if($x.PSObject.properties.Name.Contains("`$ref"))
                            {
                                $subpath = ''
                                if($x.'$ref'.contains('.json#/'))
                                {
                                    $startInd = $x.'$ref'.IndexOf('.json#/')
                                    $subpath = $x.'$ref'.Substring(0,$startInd+6)
                                    $subpath = $subpath.replace('#','')
                                    $schemaJSONLink = Get-HPRESTSchemaExtref -Type $subpath.replace('.json','') -Session $Session -Language $Language -Headers $Headers
                                    $index = $schemaJSONLink.LastIndexOf('/')
                                    $prefix = $schemaJSONLink.SubString(0,$index+1)
                                    $newLink = $prefix + $subpath

                                    $sch = Get-HPRESTDataRaw -Href $newLink -Session $session -Headers $Headers
                                }
                                elseif($x.'$ref'.Contains('#'))
                                {
                                    if($x.'$ref'.IndexOf('#') -eq 0)
                                    {
                                        $laterPath = $x.'$ref'.Substring(2)
                                        $sch = Get-HPRESTSchema -Type $DataType -Session $Session -Language $Language -Headers $Headers 
                                    }
                                    else
                                    {
                                        $subpath = $x.'$ref'.replace('#','')
                                        $schemaJSONLink = Get-HPRESTSchemaExtref -Type $subpath.replace('.json','') -Session $Session -Language $Language -Headers $Headers
                                        $index = $schemaJSONLink.LastIndexOf('/')
                                        $prefix = $schemaJSONLink.SubString(0,$index+1)
                                        $newLink = $prefix + $subpath

                                        $sch = Get-HPRESTDataRaw -Href $newLink -Session $session -Headers $Headers
                                    }
                                }

                                $schToUse = $sch
                                if($laterPath -ne '')
                                {
                                    $tmp = $laterPath.Replace('/','.')
                                    $schToUse = $sch
                                    foreach($x in $tmp.split('.'))
                                    {
                                        $schToUse = $schToUse.$x
                                    }
                                }
                            }
                            else
                            {
                                $schToUse = $x
                            }
                            $DictionaryOfSchemas = Get-HPRESTDataPropRecurse -Data $dataPropElement -Schema $schToUse -Session $Session -DictionaryOfSchemas $DictionaryOfSchemas -DataType $DataType -Headers $Headers
                            $dataList += $opObj
                        }
                    }
                    #$DataProperties | Add-Member NoteProperty $dataProp.Name $dataList #$outputObj
                }
                elseif($dataProp.TypeNameOfValue -eq 'System.Management.Automation.PSCustomObject')
                {
                    $psObj = New-Object PSObject
                    if($schProp.value.PSObject.properties.Name.Contains("`$ref"))
                    {
                        
                        $laterPath = ''
                        $subpath = ''
                        if($schProp.value.'$ref'.contains('.json#/'))
                        {
                            $startInd = $schProp.value.'$ref'.IndexOf('.json#/')
                            $laterPath = $schProp.value.'$ref'.Substring($startInd+7)
                            $subpath = $schProp.value.'$ref'.Substring(0,$startInd+6)
                            $subpath = $subpath.replace('#','')
                            $schemaJSONLink = Get-HPRESTSchemaExtref -Type $subpath.replace('.json','') -Session $Session -Headers $Headers
                            $index = $schemaJSONLink.LastIndexOf('/')
                            $prefix = $schemaJSONLink.SubString(0,$index+1)
                            $newLink = $prefix + $subpath
                            $refSchema = Get-HPRESTDataRaw -Href $newLink -Headers $Headers -Session $session
                        }
                        elseif($schProp.value.'$ref'.Contains('#'))
                        {
                            if($schProp.Value.'$ref'.IndexOf('#') -eq 0)
                            {
                                $laterPath = $schProp.value.'$ref'.Substring(2)
                                $refSchema = Get-HPRESTSchema -Type $DataType -Headers $Headers -Session $session
                            }
                            else
                            {
                                $subpath = $schProp.value.'$ref'.replace('#','')
                                $schemaJSONLink = Get-HPRESTSchemaExtref -Type $subpath.replace('.json','') -Session $Session -Headers $Headers
                                $index = $schemaJSONLink.LastIndexOf('/')
                                $prefix = $schemaJSONLink.SubString(0,$index+1)
                                $newLink = $prefix + $subpath
                                $refSchema = Get-HPRESTDataRaw -Href $newLink -Headers $Headers -Session $session
                            }
                        }
                        
                        if($laterPath -eq '')
                        {
                            $sch = $refSchema
                        }
                        else
                        {
                            $tmp = $laterPath.Replace('/','.')
                            $sch = $refSchema
                            foreach($x in $tmp.split('.'))
                            {
                                $sch = $sch.$x
                            }
                        }
                        $DictionaryOfSchemas = Get-HPRESTDataPropRecurse -Data $dataProp.Value -Schema $sch -Session $Session -DictionaryOfSchemas $DictionaryOfSchemas -schemaLink $newLink -DataType $DataType -Headers $Headers
                        
                    }
                    else
                    {
                        $DictionaryOfSchemas  = Get-HPRESTDataPropRecurse -Data $dataProp.Value -Schema $schProp.Value -Session $Session -DictionaryOfSchemas $DictionaryOfSchemas -DataType $DataType -Headers $Headers
                    }
                }
                break;
            }
        }
        
        if($dataInSchema -eq $false)
        {
            if(-not ($DictionaryOfSchemas.ContainsKey($dataProp.Name)))
            {
                $DictionaryOfSchemas.Add($dataProp.Name, $null)
            }
        }
    }
    return $DictionaryOfSchemas
}

function Get-HPRESTTypePrefix
{
    param
    (
        [System.String]
        $Type
    )

    if($Type.IndexOf('.') -eq -1)
    {
        return $Type
    }
    else
    {
        return ($Type.Split('.'))[0]
    }
}

function Compare-HPRESTSchemaVersion
{
<#
.SYNOPSIS
Compares Type fields of data and schema.

.DESCRIPTION
Compares Type field of data and schema and returns True if the schema and data have same major version and False if not. Type includes a name as well as version information. Version information is major.minor.errata (for example, SystemRoot.0.9.5). Anything but a major version is backward compatible, so a new property added to an object might result in minor Type increments (for example, Chassis.1.0.0 becomes Chassis.1.1.0). Moving to a major version change (for example, Chassis.2.0.0) is a breaking change without backward compatibility, and the HPE iLO development team will be careful before making a big break like this. 

.PARAMETER DataType
Type field retrieved from the Data.

.PARAMETER SchemaType
Type field retrieved from Schema.

.EXAMPLE
PS C:\> Compare-HPRESTSchemaVersion -DataType ComputerSystem.0.9.5 -SchemaType ComputerSystem.0.9.5
True

The major version values are 0 for both data and schema. This example shows that when same major version values of the data and schema are same, the cmdlet returns true.

.EXAMPLE
PS c:\> Compare-HPRESTSchemaVersion -DataType ComputerSystem.0.9.5 -SchemaType ComputerSystem.1.0.0
False

The major version values are 0 and 1 for both data and schema respectively. This example shows that when same major version values of the data and schema are different, the cmdlet returns false.
#>
    param
    (

        [System.String]
        $DataType,

        [System.String]
        $SchemaType
    )

    $schMaxVer = $SchemaType.split('.')
    $datMaxVer = $DataType.Split('.')

    if($DataType.IndexOf($SchemaType) -gt -1 -or $SchemaType.IndexOf($DataType) -gt -1)
    {
        return $true
    }

    if([int]$schMaxVer[1] -ne [int]$datMaxVer[1])
    {
        return $false
    }
    else
    {
        <#
        if([int]$schMaxVer[2] -lt [int]$datMaxVer[2])
        {
            return $false
        }
        if(([int]$schMaxVer[2] -eq [int]$datMaxVer[2]) -and ([int]$schMaxVer[3] -lt [int]$datMaxVer[3]))
        {
            return $false
        }
        #>
        return $true
    }
}

function Merge-HPRESTPage
{
    param
    (
        [PSObject]
        $FinalObj,
	
        [PSObject]
        $ThisPage,

        [PSObject]
        $Session,

        [Hashtable]
        $Headers
    )

    if($ThisPage.links.PSObject.Properties.Name -contains 'NextPage')
    {
        $self = $ThisPage.links.self.href
        $uri = $self.Substring(0,$self.length-1)
        $page = [int]$self.Substring($self.length-1)
        $nextPageURI = $uri+($page+1)

        # get http data and convert to PSObject from JSON string
        try
        {
            $uri = Get-HPRESTUriFromHref -Session $Session -Href $nextPageURI
            $Method = 'GET'
            $cmdletName = 'Get-HPRESTDataRaw'
			
			if($Session.DisableCertificateAuthentication.IsPresent -eq $false)
            {
                $resp = Invoke-HttpWebRequest -Uri $uri -Method $Method -CmdletName $cmdletName -Session $Session -Headers $Headers
            }
            else
            {
               $resp = Invoke-HttpWebRequest -Uri $uri -Method $Method -CmdletName $cmdletName -Session $Session -Headers $Headers -DisableCertificateAuthentication
            }


            $rs = $resp.GetResponseStream();
            [System.IO.StreamReader] $sr = New-Object System.IO.StreamReader -argumentList $rs;
            $results = ''
            [string]$results = $sr.ReadToEnd();
            $nextPageData = $results|Convert-JsonToPSObject
            $sr.Close()
			$rs.Close()
			$resp.Close()

            # concatenate data into the final object
            foreach($i in $nextPageData.Items)
            {
                $FinalObj.Items += $i
            }
            foreach($m in $nextPageData.links.member)
            {
                $FinalObj.links.member += $m
            }
        }
        finally
        {
		    if ($null -ne $sr -and $sr -is [System.IDisposable]){$sr.Close()}
			if ($null -ne $rs -and $rs -is [System.IDisposable]){$rs.Close()}
            if ($null -ne $resp -and $resp -is [System.IDisposable]){$resp.Close()}          
        }

        if($nextPageData.links.PSObject.Properties.Name -contains ('NextPage'))
        {
            Merge-HPRESTPage -FinalObj $FinalObj -ThisPage $nextPageData -Session $Session -Headers $Headers
        }

        $newLinks = New-Object PSObject
        foreach($mem in $FinalObj.links.PSObject.Properties)
        {
            if($mem.Name -ne 'NextPage')
            {
                $newLinks|Add-Member $mem.Name $mem.Value
            }
        }
        $FinalObj.links = $newLinks
        $FinalObj.links.self.href = $self.Substring(0,$self.IndexOf('?'))
    }
}

function Set-Message
{
    param
    (
        [System.String]
        $Message,
	
        [System.Object]
        $MessageArg
    )

    $m = $Message
    for($i = 0; $i -lt $MessageArg.count; $i++)
    {
        $placeHolder = '%'+($i+1)
        $value = $MessageArg[$i]
        $m =  $m -replace $placeHolder, $value
    }
    return $m
}

function Get-ErrorRecord
{
    param
    (
        [System.Net.HttpWebResponse]
        $WebResponse,
	
        [System.String]
        $CmdletName
    )

    $webStream = $webResponse.GetResponseStream()
    $respReader = New-Object System.IO.StreamReader($webStream)
    $respJSON = $respReader.ReadToEnd()
	$resp = $respJSON|Convert-JsonToPSObject
	$respReader.Close()
    $webStream.Close() 
    $webResponse.Close()
            
    $noValidSession = $false
    $msg = ''
    if($resp.Messages.Count -gt 0)
    {
        foreach($msgID in $resp.Messages)
        {
            if($msgID.MessageId -match 'NoValidSession')
            {
                $noValidSession = $true
                $msg = $msg + $msgID.messageID + "`n"
                break
            }
        }
        if($noValidSession -eq $false)
        {
            foreach($msgID in $resp.Messages)
            {
                $msg = $msg + "`n" + $msgID.messageID + "`n"
                $status = Get-HPRESTMessage -MessageID $msgID.MessageID -MessageArg $msgID.MessageArgs -Headers $Headers -Session $session
                foreach($mem in $status.PSObject.Properties)
                {
                    $msg = $msg + $mem.Name + ': ' + $mem.value + "`n"
                }
            }
        }
    }

    $message = $msg + ($_| Format-Table | Out-String)
    $targetObject = $CmdletName
    try{
        $exception = New-Object $_.Exception $message
        $errorID = $_.FullyQualifiedErrorId
        $errorCategory = $_.CategoryInfo.Category
    }
    catch
    {
        $exception = New-Object System.InvalidOperationException $message
        $errorID = 'InvocationException'
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
    }
        

    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorID, $errorCategory, $targetObject
    return $errorRecord
}

function Get-BlockIndex
{
    param
    (
        [System.String]$InputJSONString,
        [System.Int32]$PropertyIndex
    )
    
    $bracketCounter = 0
    $blockStartIndex = 0
    $blockEndIndex = $InputJSONString.Length-1
    for($i=$PropertyIndex; $i-gt0; $i--)
    {
        if($InputJSONString[$i] -eq "}") { $bracketCounter = $bracketCounter + 1 }
        elseif($InputJSONString[$i] -eq "{")
        {
            if($bracketCounter -eq 0)
            {
                $blockStartIndex = $i
                break
            }
            else { $bracketCounter = $bracketCounter - 1 }
        }
    }
    for($i=$PropertyIndex; $i-lt$InputJSONString.Length; $i++)
    {
        if($InputJSONString[$i] -eq "{") { $bracketCounter = $bracketCounter + 1 }
        elseif($InputJSONString[$i] -eq "}")
        {
            if($bracketCounter -eq 0)
            {
                $blockEndIndex = $i+1
                break
            }
            else { $bracketCounter = $bracketCounter - 1 }
        }
    }
    return $blockStartIndex,$blockEndIndex
}

function Get-BlockEnd
{
    param
    (
        [System.String]$InputJSONString,
        [System.Int32]$PropertyIndex,
        [System.String]$BracketType = '{'
    )
    
    $bracketCounter = 0
    $blockStartIndex = 0
    $blockEndIndex = $InputJSONString.Length-1
    $PropertyIndex = $PropertyIndex+1

    $startBracket = '{'
    $endBracket = '}'

    if($BracketType -eq '[')
    {
        $startBracket = '['
        $endBracket = ']'
    }

    for($i=$PropertyIndex; $i-lt$InputJSONString.Length; $i++)
    {
        if($InputJSONString[$i] -eq $startBracket) { $bracketCounter = $bracketCounter + 1 }
        elseif($InputJSONString[$i] -eq $endBracket)
        {
            if($bracketCounter -eq 0)
            {
                $blockEndIndex = $i
                break
            }
            else { $bracketCounter = $bracketCounter - 1 }
        }
    }

    $i = $blockEndIndex + 1
    return $i
}

function Get-FullRemoveableSubString
{
    param
    (
        [System.String]
        $InputJSONString,

        [System.String]
        $Property
    )

    
    $propertyStartIndex = $InputJSONString.IndexOf($Property)
    $propertyEndIndex = $propertyStartIndex + $Property.Length
    

    $postCommaFoundFlag = $false
    $i=$propertyEndIndex
    while($InputJSONString[$i]-ne "{" -and $InputJSONString[$i]-ne "}" -and $InputJSONString[$i]-ne "[" -and $InputJSONString[$i] -ne "]")
    {
        if($InputJSONString[$i] -eq ",")
        {
            $postCommaFoundFlag = $true;
            $propertyEndIndex = $i
            break
        }        
        $i++
    }

    if($postCommaFoundFlag -eq $false)
    {
        $preCommaFoundFlag = $false
        $i=$propertyStartIndex
        # attach each char till previous comma
        while($InputJSONString[$i]-ne "{" -and $InputJSONString[$i]-ne "}" -and $InputJSONString[$i]-ne "[" -and $InputJSONString[$i] -ne "]")
        {
            if($InputJSONString[$i] -eq ",")
            {
                $preCommaFoundFlag = $true;
                $propertyStartIndex = $i
                break
            }        
            $i--
        }
    }

    $fullRemSubString = $InputJSONString.Substring($propertyStartIndex, $propertyEndIndex-$propertyStartIndex+1)
    return $fullRemSubString

}

function Remove-PropertyDuplicate
{
    param
    (
        [System.String]
        $InputJSONString,

        [System.String]
        $Property
    )

    $block = ""
    $blockStart = 0
    $blockEnd = $InputJSONString.Length
    
    $block = $InputJSONString.Substring($blockStart,$blockEnd-$blockStart)

    $matchedObjects = $InputJSONString| Select-String -Pattern "`"$property`": " -AllMatches

    for($i=0; $i-lt$matchedObjects.Matches.Count; $i++)
    {
        $start,$end = Get-BlockIndex $InputJSONString $matchedObjects.Matches[$i].Index
        $matchedObjects.Matches[$i]|Add-Member blockstart $start
        $matchedObjects.Matches[$i]|Add-Member blockend $end
    }

    $propList = @{}
    for($i=0; $i-lt$matchedObjects.Matches.Count; $i++)
    {
        try
        {
            $prop = $matchedObjects.Matches[$i]
            $propList.Add($prop.blockstart,$prop)#$prop.Value.Substring(1,$prop.val))
        }
        catch
        {
            if($_.Exception.Message -match "Item has already been added.")
            {
                $prop1 = $propList[$matchedObjects.Matches[$i].blockstart]
                $prop2 = $matchedObjects.Matches[$i]
            
                $startChar = '{'
                $jsonStart = 0
                $jsonEnd = 0
                $startIndex = $prop1.Index+$prop1.Value.Length
                if($InputJSONString.Substring($startIndex,1) -eq '[')
                {
                    $startChar = '['
                }
                $endIndex = Get-BlockEnd -InputJSONString $InputJSONString -PropertyIndex $startIndex -BracketType $startChar
                $prop1ValueJson = $InputJSONString.Substring($startIndex, $endIndex-$startIndex)
                $prop1ValueObj = $prop1ValueJson | ConvertFrom-Json

                $fullRemovableSubstring = ""
                if($prop1ValueObj.PSObject.Properties.Name -match 'Deprecated')
                {
                    $substringToRemove = $InputJSONString.Substring($prop1.Index, $endIndex-$prop1.Index)
                    $fullRemovableSubstring = Get-FullRemoveableSubString -InputJSONString $InputJSONString -Property $substringToRemove
                }
                else
                {
                    $startChar = '{'
                    $jsonStart = 0
                    $jsonEnd = 0
                    $startIndex = $prop2.Index+$prop2.Value.Length
                    if($InputJSONString.Substring($startIndex,1) -eq '[')
                    {
                        $startChar = '['
                    }
                    $endIndex = Get-BlockEnd -InputJSONString $InputJSONString -PropertyIndex $startIndex -BracketType $startChar
                    $substringToRemove = $InputJSONString.Substring($prop2.Index, $endIndex-$prop2.Index)
                    $fullRemovableSubstring = Get-FullRemoveableSubString -InputJSONString $InputJSONString -Property $substringToRemove
                }
                $InputJSONString = $InputJSONString.Replace($fullRemovableSubstring,"")
                
                for($j=$i+1; $j-lt$matchedObjects.Matches.Count; $j++)
                {
                    $matchedObjects.Matches[$j].blockstart = $matchedObjects.Matches[$j].blockstart - $fullRemovableSubstring.Length
                    $matchedObjects.Matches[$j].blockend = $matchedObjects.Matches[$j].blockend - $fullRemovableSubstring.Length
                    $matchedObjects.Matches[$j].Index = $matchedObjects.Matches[$j].Index - $fullRemovableSubstring.Length
                }
            }
        }
    }
    return $InputJSONString
}

# use this method instead of ConvertFrom-Json to remove duplicates
function Convert-JsonToPSObject
{
    param
    (
        [System.String]
        [parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        $JsonString
    )
    
    try
    {
        $convertedPsobject = ConvertFrom-Json -InputObject $JsonString

    }
    catch [System.InvalidOperationException]
    {
        if($_.FullyQualifiedErrorId -eq "DuplicateKeysInJsonString,Microsoft.PowerShell.Commands.ConvertFromJsonCommand")
        {
            $spl = $_.Exception.Message.Split("'")
            $propToRemove = $spl[1]
            $global:Error.RemoveAt(0)
            $jsonStringRemProp = Remove-PropertyDuplicate -InputJSONString $JsonString -Property $propToRemove
            $convertedPsobject = Convert-JsonToPSObject -JsonString $jsonStringRemProp
        }
        else
        {
            throw $_
        }
    }
    return $convertedPsobject
    
}

function Get-FinalHrefForPutPatch
{
    param
    (
        [System.String]
        [parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        $Href,

        [System.String]
        [parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        $CmdletName,

        [System.String]
        [parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        $MethodToExecute,

        [PSObject]
        [parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        $Session,

        [Hashtable]
        [parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        $Headers
    )
    
    try
        {
            $uri = Get-HPRESTUriFromHref -Session $Session -Href $Href
            $Method = 'GET'

            if($Session.DisableCertificateAuthentication.IsPresent -eq $false)
            {
                $resp = Invoke-HttpWebRequest -Uri $uri -Method $Method -CmdletName $CmdletName -Session $Session -Headers $Headers
            }
            else
            {
                $resp = Invoke-HttpWebRequest -Uri $uri -Method $Method -CmdletName $CmdletName -Session $Session -Headers $Headers -DisableCertificateAuthentication
            }

            $finalHref = $Href

            # if the web response headder 'Allow' field does not have PATCH, then search for Settings href in links field of the data. If the settings field is present, then 
            if(($resp.Headers['Allow'] -split ',').Trim() -notcontains $MethodToExecute)
            {
                $rs = $resp.GetResponseStream();
                [System.IO.StreamReader] $sr = New-Object System.IO.StreamReader -argumentList $rs;
                $results = ''
                [string]$jsonResults = $sr.ReadToEnd();
        
                $results = $jsonResults|Convert-JsonToPSObject
                if($results.links.PSObject.Properties.Name -contains 'Settings')
                {
                    $finalHref = $results.links.Settings.href
                }
                $sr.Close()
				$rs.Close()
            }
            $resp.Close()
        }
        finally
        {
			if ($null -ne $sr -and $sr -is [System.IDisposable]){$sr.Dispose()}
            if ($null -ne $rs -and $rs -is [System.IDisposable]){$rs.Dispose()}
			if ($null -ne $resp -and $resp -is [System.IDisposable]){$resp.Dispose()}            
        }
    return $finalHref
    
}

function Invoke-HttpWebRequest
{
    param
    (
        [System.String]
        $Uri,

        [System.String]
        $Method,

        [System.Object]
        $Payload,

        [System.String]
        $CmdletName,

        [Int32]
        $Timeout,

        [Hashtable]
        $Headers,

        [PSObject]
        $Session,

        [Switch]
        $DisableCertificateAuthentication

    )

    Start-Sleep -Milliseconds 300
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Ssl3

    if($null -ne $wr)
    {
        $wr = $null
    }
    if($null -ne $httpWebRequest)
    {
        $httpWebRequest = $null
    }

    
    $uriObject = [Uri]$Uri

    $HostDetails = Get-UriAddressDetail -URI $uri
    $hostnamePort = ""
    if($DisableCertificateAuthentication.IsPresent -eq $false -and $HostDetails.PSObject.Properties.Name.Contains('Hostname') -and $null -ne $HostDetails.Hostname -and [String]::Empty -ne $HostDetails.Hostname)
    {
        $hostnamePort = $hostnamePort + $HostDetails.Hostname
    }
    else
    {
        if($HostDetails.AddressType -eq [AddressType]::IPv6)
        {
            $hostnamePort = $hostnamePort + '[' +$HostDetails.IP + ']'
        }
        else
        {
            $hostnamePort = $hostnamePort + $HostDetails.IP
        }
    }
    
    if($HostDetails.PSObject.Properties.Name.Contains('Port'))
    {
        $hostnamePort = $hostnamePort + ':' + $HostDetails.Port
    }
    else
    {
        $hostnamePort = $hostnamePort + ':' + $uriObject.Port
    }
    

    $useUri = $requestUri = $uriObject.Scheme + '://' + $hostnamePort + ($uriObject.Segments -join '') + $uriObject.Query
    
    $wr = [System.Net.WebRequest]::Create($useUri)
    $httpWebRequest = [System.Net.HttpWebRequest]$wr
    if($Headers.Count -gt 0)
    {
        foreach($entry in $Headers.Keys)
        {
            $httpWebRequest.Headers.Add($entry,$Headers[$entry])
        }
    }
    $httpWebRequest.Method = $Method
    $httpWebRequest.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip
    $httpWebRequest.KeepAlive = $false
    $httpWebRequest.CachePolicy = New-Object System.Net.Cache.RequestCachePolicy -ArgumentList ([System.Net.Cache.RequestCacheLevel]::NoCacheNoStore)
    $httpWebRequest.ServicePoint.Expect100Continue = $false
    if($CmdletName -ne 'Connect-HPREST')
    {
        $httpWebRequest.Headers.Add('X-Auth-Token',$Session.'X-Auth-Token')
    }
    
    if($null -ne $Timeout -and $Timeout -gt 0)
    {
        $httpWebRequest.Timeout = $Timeout * 1000
    }
    elseif($null -ne $session -and $session.PSObject.Properties.Name.Contains("Timeout"))
    {
        $httpWebRequest.Timeout = $Session.Timeout * 1000
    }
    
    if($DisableCertificateAuthentication.IsPresent -eq $true)
    {
        $httpWebRequest.ServerCertificateValidationCallback = {$true}
    }
    if($method -in @('PUT','POST','PATCH'))
    {
        if($null -eq $Payload -or $Payload -eq '')
        {
            $Payload = '{}'
        }
        $httpWebRequest.ContentType = 'application/json'
        $httpWebRequest.ContentLength = $Payload.length

        $reqWriter = New-Object System.IO.StreamWriter($httpWebRequest.GetRequestStream(), [System.Text.Encoding]::ASCII)
        $reqWriter.Write($Payload)
        $reqWriter.Close()
    }
        
    try
    {
        [System.Net.WebResponse] $resp = $httpWebRequest.GetResponse()
        return $resp
    }
    catch
    {
        if($CmdletName -in @("Disconnect-HPREST","Connect-HPREST"))
        {
            $webResponse = $_.Exception.InnerException.Response
            $msg = $_
            if($null -ne $webResponse)
            {
                $webStream = $webResponse.GetResponseStream();
                [System.IO.StreamReader] $respReader = New-Object System.IO.StreamReader -argumentList $webStream;
                $resultJSON = $respReader.ReadToEnd();
                $result = $resultJSON|ConvertFrom-Json
				$respReader.Close()
                $webStream.Close()
				$webResponse.Close()
                
                $msg = $_.Exception.Message
                if($result.Messages.Count -gt 0)
                {
                    foreach($msgID in $result.Messages)
                    {
                        $msg = $msg + "`n" + $msgID.messageID
                    }
                }
            }
            $Global:Error.RemoveAt(0)
            throw $msg
        }
        else
        {
            $webResponse = $_.Exception.InnerException.Response
            if($null -ne $webResponse)
            {
                if($webResponse.StatusCode.ToString() -eq '308')
                {
                    $uri = $webResponse.Headers['Location']
                    $wr = [System.Net.WebRequest]::Create($uri)
                    $httpWebRequest = [System.Net.HttpWebRequest]$wr
                    $httpWebRequest.Method = $Method
                    $httpWebRequest.ContentType = 'application/json'
                    $httpWebRequest.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip
					$httpWebRequest.KeepAlive = $false
                    $httpWebRequest.CachePolicy = New-Object System.Net.Cache.RequestCachePolicy -ArgumentList ([System.Net.Cache.RequestCacheLevel]::NoCacheNoStore)
                    $httpWebRequest.ServicePoint.Expect100Continue = $false
                    $httpWebRequest.Headers.Add('X-Auth-Token',$Session.'X-Auth-Token')
                    if($DisableCertificateAuthentication.IsPresent -eq $true)
                    {
                        $httpWebRequest.ServerCertificateValidationCallback = {$true}
                    }
                    Write-Verbose "Redirecting to $uri"
                    [System.Net.WebResponse] $resp = $httpWebRequest.GetResponse()
                    $Global:Error.RemoveAt(0)
                    return $resp
                }
                else
                {   
                    $webResponse = $_.Exception.InnerException.Response
                    if($null -ne $webResponse)
                    {
                        $errorRecord = Get-ErrorRecord -WebResponse $webResponse -CmdletName $CmdletName
                        $Global:Error.RemoveAt(0)
                        throw $errorRecord
                    }
                    else
                    {
                        throw $_
                    }
                }
            }
            else
            {
                throw $_
            }
        }
    }
    finally
    {
        if ($null -ne $reqWriter -and $reqWriter -is [System.IDisposable]){$reqWriter.Dispose()}
    }
}

function Get-IPHostname
{
    param
    (
        [PSObject]
        $Address
    )

    if($Address.AddressType -eq [AddressType]::IPv6 -or $Address.AddressType -eq [AddressType]::IPv4)
    {
        try
        {
            $ipHostEntry = [System.Net.Dns]::GetHostEntry($Address.IP)
            $hostname = $ipHostEntry.Hostname
            $Address | Add-Member NoteProperty 'Hostname' $hostname
        }
        catch
        {
            Write-Warning -Message $([string]::Format($(Get-Message('MSG_FAIL_HOSTNAME')), $Address.IP))
        }
    }
    else #if($Address.AddressType -eq [AddressType]::Hostname)
    {
        try
        {
            $ipAddress = [System.Net.Dns]::GetHostAddresses($Address.hostname)
            $ipToUse = [string]$ipAddress.IPAddressToString
            $Address | Add-Member NoteProperty 'IP' $ipToUse
        }
        catch
        {
            Write-Warning -Message $([string]::Format($(Get-Message('MSG_FAIL_IPADDRESS')),$address.Hostname))
        }
    }
    return $Address
}
      
function Get-UriAddressDetail
{
    param
    (
        [URI]
        $URI
    )
    
    $address = $URI.Authority #ip or hostname with the port if the port is entered by the user

    $ret = New-Object PSObject
    [IPAddress]$ipAddress = $null
    $colonMatches = [regex]::Matches($address, ':')
    
    if($colonMatches.count -eq 0)
    {
        if([IPAddress]::TryParse($Address, [ref]$ipAddress))
        {
            $ret | Add-Member NoteProperty 'IP' $ipAddress.IPAddressToString
            $ret | Add-Member NoteProperty 'AddressType' ([AddressType]::IPv4)
        }
        else
        {
            $ret | Add-Member NoteProperty 'Hostname' $Address
            $ret | Add-Member NoteProperty 'AddressType' ([AddressType]::Hostname)
        }
    }
    elseif($colonMatches.count -eq 1)
    {
        $split = $Address -split ':'
        if([IPAddress]::TryParse($split[0], [ref]$ipAddress))
        {
            $ret | Add-Member NoteProperty 'IP' $ipAddress.IPAddressToString
            $ret | Add-Member NoteProperty 'Port' $split[1]
            $ret | Add-Member NoteProperty 'AddressType' ([AddressType]::IPv4)
        }
        else
        {
            $ret | Add-Member NoteProperty 'Hostname' $split[0]
            $ret | Add-Member NoteProperty 'Port' $split[1]
            $ret | Add-Member NoteProperty 'AddressType' ([AddressType]::Hostname)
        }
    }
    else #if($colonMatches.count -gt 1)
    {
        if([IPAddress]::TryParse($Address, [ref]$ipAddress))
        {
            if($ipAddress.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6)
            {
                $ret | Add-Member NoteProperty 'IP' $ipAddress.IPAddressToString

                $bracketMatches = [regex]::Matches($Address, ']:')
                if($bracketMatches.count -gt 0)
                {
                    $port = ($Address -split ']:')[1]
                    $ret | Add-Member NoteProperty 'Port' $port
                }

                $ret | Add-Member NoteProperty 'AddressType' ([AddressType]::IPv6)
            }
        }
        else
        {
            throw [ArgumentException]::new((Get-Message('MSG_ERROR_INVALID_ADDRESS_FORMAT')), 'Address')
        }
    }

    $returnObject = Get-IPHostname -Address $ret

    return $returnObject
}



#-------------------------------------------------------------------------------------------------#
#-----------------------------------------HP REST Cmdlets-----------------------------------------#
#-------------------------------------------------------------------------------------------------#

function Connect-HPREST
{
<#
.SYNOPSIS
Creates a session between PowerShell client and the REST source.

.DESCRIPTION
Creates a session between the PowerShell client and the REST source using HTTP POST method and returns a session object. The session object has the following members:
· 'IP' of target address.
· 'Hostname' of target server.
· 'Port' of HTTP connection.
· 'Timeout' of HTTP connection in seconds.
· 'X-Auth-Token' to identify the session.
· 'RootURI' of the REST source.
· 'Location' which is used for logging out of the session.
· 'RootData' includes data from 'rest/v1'. It includes the rest details and the links to components like systems, chassis, etc.
· 'DisableCertificateAuthentication' to identify whether the connection is established using server certificate authentication or not.
· 'IsConnected' to identify whether the session is valid or not.

.PARAMETER Address
IP address or Hostname of the target HPE REST source.

.PARAMETER Username
Username of iLO account to access the HPE REST source.

.PARAMETER Password
Password of iLO account to access the iLO.

.PARAMETER Credential
PowerShell PSCredential object having username and passwword of iLO account to access the iLO.

.PARAMETER Timeout
Integer value that sets the timeout of the HTTP WebRequest object in seconds. The default value is 25 seconds. The value should be range from 25 to 600.

.PARAMETER Headers
A list of Key-Value pairs in the form of a hashtable to be included in the HTTP web request.

.PARAMETER DisableCertificateAuthentication
If this switch parameter is present then server certificate authentication is disabled for the execution of this cmdlet. If not present it will execute according to the global certificate authentication setting. The default behavior is to authenticate server certificates.

.NOTES
See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.INPUTS
System.String
You can pipe the Address i.e. the hostname or IP address to Connect-HPREST.

.OUTPUTS
System.Management.Automation.PSCustomObject
Connect-HPREST returns a PSObject that has session details - X-Auth-Token, RootURI, Location and RootData.

.EXAMPLE
PS C:\> $session = Connect-HPREST -Address 10.20.30.1 -Username admin -Password admin123


PS C:\> $session |fl


RootUri                          : https://10.20.30.1/rest/v1
IP                               : 10.20.30.1
Hostname                         : abc1.domain.com
Port                             : 443
Timeout                          : 25
X-Auth-Token                     : 142ddfc3cbdef055aa36a3a9ed094dac
Location                         : https://10.20.30.1/rest/v1/SessionService/Sessions/admin00067c4595810625
DisableCertificateAuthentication : False
RootData                         : @{@odata.context=/redfish/v1/$metadata#ServiceRoot; @odata.id=/redfish/v1/; @odata.type=#ServiceRoot.1.0.0.ServiceRoot; AccountService=; Chassis=; EventService=; Id=v1; 
                                   JsonSchemas=; Managers=; Name=HP RESTful Root Service; Oem=; RedfishVersion=1.0.0; Registries=; ServiceVersion=1.0.0; SessionService=; Systems=; Time=1970-01-05T22:03:50Z; 
                                   Type=ServiceRoot.1.0.0; UUID=8a8d2473-219f-579c-a992-d28aab7fbae5; links=}
IsConnected                      : True


.EXAMPLE
PS C:\> $cred = Get-Credential
PS C:\> $session = Connect-HPREST -Address 10.20.30.2 -Credential $cred
PS C:\> $session | fl


RootUri                          : https://10.20.30.2/rest/v1
IP                               : 10.20.30.2
Hostname                         : abc2.domain.com
Port                             : 443
Timeout                          : 25
X-Auth-Token                     : a5657bdsgfsdg3650f9ebc64d33c3262
Location                         : https://10.20.30.2/rest/v1/SessionService/Sessions/admin75675856ad6g25fg6
DisableCertificateAuthentication : False
RootData                         : @{@odata.context=/redfish/v1/$metadata#ServiceRoot; @odata.id=/redfish/v1/; @odata.type=#ServiceRoot.1.0.0.ServiceRoot; AccountService=; Chassis=; EventService=; Id=v1; 
                                   JsonSchemas=; Managers=; Name=HP RESTful Root Service; Oem=; RedfishVersion=1.0.0; Registries=; ServiceVersion=1.0.0; SessionService=; Systems=; Time=1970-01-05T22:03:50Z; 
                                   Type=ServiceRoot.1.0.0; UUID=8a8d2473-219f-579c-a992-d28aab7fbae5; links=}
IsConnected                      : True

.LINK
http://www.hpe.com/servers/powershell

#>
    [cmdletbinding(DefaultParameterSetName='UsernamePasswordSessionSet')]
    param
    (
        [System.String]
        [parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
        $Address,

        [System.String]
        [parameter(ParameterSetName = "UsernamePasswordSessionSet", Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=1)]
        $Username,
        
        [System.String]
        [AllowEmptyString()]
        [parameter(ParameterSetName = "UsernamePasswordSessionSet", Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=2)]
        $Password,

        [alias("Cred")] 
        [PSCredential]
        [parameter(ParameterSetName = "PSCredentialSessionSet", Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=1)]
        $Credential,

        [Int32]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateRange(25,600)]
        $Timeout = 25,
        
        [Hashtable]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Headers,
        
        [switch]
        [parameter(Mandatory=$false)]
        $DisableCertificateAuthentication
    )

    try
    {
        $session = $null
        $wr = $null
        $httpWebRequest = $null
        $IsConnected = $false

        if($null -ne $Credential)
        {
            $un = $Credential.UserName
            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password)
            $pw = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        }
        elseif($username -ne '')
        {
            $un = $username
            $pw = $password
        }
        else
        {
            throw $(Get-Message('MSG_INVALID_CREDENTIALS'))
        }
    
        $unpw = @{'UserName'=$un; 'Password'=$pw}
        $jsonStringData = $unpw|ConvertTo-Json
        $session = $null

        [IPAddress]$ipAddress = $null
        if([IPAddress]::TryParse($Address, [ref]$ipAddress))
        {
            if($ipAddress.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6 -and $Address.IndexOf('[') -eq -1)
            {
                $Address = '['+$Address+']'
            }
        }

        $uri = "https://$Address/rest/v1/sessions"
        $method = "POST"
        $payload = $jsonStringData
        $cmdletName = "Connect-HPREST"
    
        if($DisableCertificateAuthentication.IsPresent -eq $false)
        {
            $webResponse = Invoke-HttpWebRequest -Uri $uri -Method $method -Payload $payload -CmdletName $cmdletName -Timeout $Timeout -Headers $Headers
            $IsConnected = $true
        }
        else
        {
            $webResponse = Invoke-HttpWebRequest -Uri $uri -Method $method -Payload $payload -CmdletName $cmdletName -Timeout $Timeout -Headers $Headers -DisableCertificateAuthentication
            $IsConnected = $true
        }

        $HostDetails = Get-UriAddressDetail -URI $uri
        $uriObj = [URI]$uri
        $targetPort = $null
        if($HostDetails.PSObject.Properties.Name.Contains('Port'))
        {
            $targetPort = $HostDetails.Port
        }
        else
        {
            $targetPort = $uriObj.Port
        }

        $session = New-Object PSObject   
        $session|Add-Member -MemberType NoteProperty 'RootUri' ('https://'+ $Address +'/rest/v1')
        $session|Add-Member -MemberType NoteProperty 'IP' $HostDetails.IP
        $session|Add-Member -MemberType NoteProperty 'Hostname' $HostDetails.Hostname
        $session|Add-Member -MemberType NoteProperty 'Port' $targetPort
        $session|Add-Member -MemberType NoteProperty 'Timeout' $Timeout
        $session|Add-Member -MemberType NoteProperty 'X-Auth-Token' $webResponse.Headers['X-Auth-Token']
        $session|Add-Member -MemberType NoteProperty 'Location' $webResponse.Headers['Location']
        $session|Add-Member -MemberType NoteProperty 'DisableCertificateAuthentication' $DisableCertificateAuthentication.IsPresent

        
        $rootData = Get-HPRESTDataRaw -href '/rest/v1' -Session $session -Headers $Headers
        if($rootData.Oem.PSObject.Properties.name.Contains('Hp') -eq $false)
        {
            throw $(Get-Message('MSG_INVALID_OEM'))
        }
        $session|Add-Member -MemberType NoteProperty 'RootData' $rootData
        $session|Add-Member -MemberType NoteProperty 'IsConnected' $IsConnected

        $webResponse.Close()

        return $Session
    }
    finally
    {
    }
}

function Disconnect-HPREST
{
<#
.SYNOPSIS
Disconnects specified session between PowerShell client and REST source.

.DESCRIPTION
Disconnects the session between the PowerShell client and REST source by deleting the session information from location pointed to by Location field in Session object passed as parameter. Uses HTTP DELETE method for removing session information from location.

.PARAMETER Session
Session object that has Location information obtained by executing Connect-HPREST cmdlet.

.PARAMETER Headers
A list of Key-Value pairs in the form of a hashtable to be included in the HTTP web request.

.NOTES
The variable storing the session object will not become null/blank but cmdlets cannot not be executed using the session object.

.INPUTS
System.String
You can pipe the session object to Disconnect-HPREST. The session object is obtained from executing Connect-HPREST.

.OUTPUTS
This cmdlet does not generate any output.

.NOTES
See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.EXAMPLE
PS C:\> Disconnect-HPREST -Session $session

.LINK
http://www.hpe.com/servers/powershell

#>
    param
    (
        [PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session,

        [Hashtable]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Headers
    )

    try
    {
        if($null -eq $session -or $session -eq '')
        {
            throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,'Session'))
        }

        $uri = $Session.Location
        $method = "DELETE"
        $cmdletName = "Disconnect-HPREST"
        
        if($Session.DisableCertificateAuthentication.IsPresent -eq $false)
        {
            $webResponse = Invoke-HttpWebRequest -Uri $uri -Method $method -CmdletName $cmdletName -Session $Session
        }
        else
        {
            $webResponse = Invoke-HttpWebRequest -Uri $uri -Method $method -CmdletName $cmdletName -Session $Session -DisableCertificateAuthentication
        }

        $webResponse.Close()

        if($null -ne $Session.RootUri)
        {
            $Session.RootUri = [System.String]::Empty
        }

        if($null -ne $Session.IP)
        {
            $Session.IP = [System.String]::Empty
        }

        $Session.Hostname = [System.String]::Empty

        if($null -ne $Session.Port)
        {
            $Session.Port = $null
        }

        if($null -ne $Session.Timeout)
        {
            $Session.Timeout = $null
        }

        if($null -ne $Session.'X-Auth-Token')
        {
            $Session.'X-Auth-Token' = [System.String]::Empty
        }

        if($null -ne $Session.Location)
        {
            $Session.Location = [System.String]::Empty
        }

        if($null -ne $Session.RootData)
        {
            $Session.RootData = $null
        }

        if($null -ne $Session.DisableCertificateAuthentication)
        {
            $Session.DisableCertificateAuthentication = $null
        }

        if($null -ne $Session.IsConnected)
        {
            $Session.IsConnected = $false
        }
    }
    finally
    {
    }
}

function Edit-HPRESTData
{
<#
.SYNOPSIS
Executes HTTP PUT method on the destination server.

.DESCRIPTION
Executes HTTP PUT method on the desitination server with the data from InputObject parameter. Used for setting BIOS default settings.

.PARAMETER Session
Session PSObject returned by executing Connect-HPREST cmdlet. It must have RootURI and X-Auth-Token for executing this cmdlet.

.PARAMETER Href
Specifies the value of Href of REST source where the HTTP PUT request is sent. Href is of the format 'rest/v1/xxxx' where xxxx is the path to the resource. An example value of the Href parameter is 'rest/v1/systems/1'. The URI to which the HTTP web request is sent is created using the protocol and host information from the session object and the value of this Href parameter.

.PARAMETER Setting
Data to be 'PUT' in name-value pair format. The parameter can be a hashtable with multiple name-value pairs.

.PARAMETER Headers
A list of Key-Value pairs in the form of a hashtable to be included in the HTTP web request.

.NOTES
- Edit-HPRESTData is for HTTP PUT method.
- Invoke-HPRESTAction is for HTTP POST method.
- Remove-HPRESTData is for HTTP DELETE method.
- Set-HPRESTData is for HTTP PATCH method.

See typical usage examples in the HPRESTExamples.ps1 file installed with this module.


.INPUTS
System.String
You can pipe the Href to Edit-HPRESTData. Href points to the location where the PUT method is to be executed.

.OUTPUTS
System.Management.Automation.PSCustomObject
Edit-HPRESTData returns a PSObject that has message from the HTTP response. The response may be informational or may have a message requiring an action like server reset.

.EXAMPLE
PS C:\> $newBiosSetting=@{'BaseConfig'='Default'}
PS C:\> $ret = Edit-HPRESTData -Session $session -Href rest/v1/systems/1/bios/Settings -Setting $newBiosSetting
PS C:\> $ret

Messages                    Name                        Type                       
--------                    ----                        ----                       
{@{MessageID=iLO.0.10.Sy... Extended Error Information  ExtendedError.0.9.6        


PS C:\> $ret.Messages

MessageID                                                                          
---------                                                                          
iLO.0.10.SystemResetRequired                                                       


This example shows updating BIOS config to factory defaults.

.LINK
http://www.hpe.com/servers/powershell

#>
    param
    (
		[PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session,

        [System.String]
        [parameter(Mandatory=$true,  ValueFromPipelineByPropertyName=$true)]
        $Href,

        [System.Object]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Setting,  

        [Hashtable]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Headers
    )
  
<#
    Edit-HPRESTData is for HTTP PUT method
    Invoke-HPRESTAction is for HTTP POST method
    Remove-HPRESTData is for HTTP DELETE method
    Set-HPRESTData is for HTTP PATCH method
#>
    if($null -eq $session -or $session -eq '')
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,'Session'))
    }
    if(($null -ne $Setting) -and $Setting.GetType().ToString() -notin @('System.Collections.Hashtable', 'System.String'))
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_INVALID_TYPE')), $Setting.GetType().ToString() ,'Setting'))
    }
    if($session.IsConnected -eq $false)
    {
        throw $([string]::Format($(Get-Message('MSG_INVALID_SESSION_OBJECT'))))
    }

    try
    {
        $jsonStringData = ''

        $hr = Get-FinalHrefForPutPatch -Href $Href -CmdletName 'Edit-HPRESTData' -MethodToExecute 'PUT' -Session $Session -Headers $Headers
        if($null -eq $Setting)
        {
            $jsonStringData = '{}'
        }
        else
        {
            if($Setting.GetType().ToString() -eq 'System.Collections.Hashtable')
            {
                $jsonStringData = $Setting | ConvertTo-Json -Depth 10
            }
            else
            {
                $jsonStringData = $Setting
            }
        }
        
        $uri = Get-HPRESTUriFromHref -href $hr -Session $Session
        $method = "PUT"
        $payload = $jsonStringData
        $cmdletName = "Edit-HPRESTData"

        if($Session.DisableCertificateAuthentication.IsPresent -eq $false)
        {
            $webResponse = Invoke-HttpWebRequest -Uri $uri -Method $method -Payload $payload -CmdletName $cmdletName -Session $Session -Headers $Headers
        }
        else
        {
            $webResponse = Invoke-HttpWebRequest -Uri $uri -Method $method -Payload $payload -CmdletName $cmdletName -Session $Session -Headers $Headers -DisableCertificateAuthentication
        }

        try
        {
            $webStream = $webResponse.GetResponseStream()
            $respReader = New-Object System.IO.StreamReader($webStream)
            $resp = $respReader.ReadToEnd()
        
            $webResponse.Close()
            $webStream.Close()
            $respReader.Close()
    
            return $resp|ConvertFrom-Json
        }
        finally
        {
			if ($null -ne $respReader -and $respReader -is [System.IDisposable]){$respReader.Dispose()}
            if ($null -ne $webStream -and $webStream -is [System.IDisposable]){$webStream.Dispose()}
			if ($null -ne $webResponse -and $webResponse -is [System.IDisposable]){$webResponse.Dispose()}
        }
    }
    finally
    {
    }
}

function Find-HPREST 
{
<#
.SYNOPSIS
Find list of HPE REST sources in a specified subnet.

.DESCRIPTION
Lists HPE REST sources in the subnet provided. You must provide the subnet in which the REST sources have to be searched.

.PARAMETER Range
Specifies the lower parts of the IP addresses which is the subnet in which the REST sources are being searched. For IP address format 'a.b.c.d', where a, b, c, d represent an integer from 0 to 255, the Range parameter can have values such as: 
a - eg: 10 - for all IP addresses in 10.0.0.0 to 10.255.255.255
a.b - eg: 10.44 - for all IP addresses in 10.44.0.0 to 10.44.255.255
a.b.c - eg: 10.44.111 - for all IP addresses in 10.44.111.0 to 10.44.111.255
a.b.c.d - eg: 10.44.111.222 - for IP address 10.44.111.222
Each division of the IP address, can specify a range using a hyphen. eg: 
"10.44.111.10-12" returns IP addresses 10.44.111.10, 10.44.111.11, 10.44.111.12
Each division of the IP address, can specify a set using a comma. eg: 
"10.44.111.10,12" returns IP addresses 10.44.111.10, 10.44.111.12

.PARAMETER Timeout
Timeout period for Http request to find whether the target is HPE REST source or not. The default value is 25 seconds. The value should be range from 25 to 600. If the default timeout is not long enough, no REST sources will be found and no errors will be displayed.

.INPUTS
String or a list of String specifying the lower parts of the IP addresses which is the subnet in which the REST sources are being searched. For IP address format 'a.b.c.d', where a, b, c, d represent an integer from 0 to 255, the Range parameter can have values such as: 
    a - eg: 10 - for all IP addresses in 10.0.0.0 to 10.255.255.255
    a.b - eg: 10.44 - for all IP addresses in 10.44.0.0 to 10.44.255.255
    a.b.c - eg: 10.44.111 - for all IP addresses in 10.44.111.0 to 10.44.111.255
    a.b.c.d - eg: 10.44.111.222 - for IP address 10.44.111.222
Each division of the IP address, can specify a range using a hyphen. eg: "10.44.111.10-12" returns IP addresses 10.44.111.10, 10.44.111.11, 10.44.111.12.
Each division of the IP address, can specify a set using a comma. eg: "10.44.111.10,12" returns IP addresses 10.44.111.10, 10.44.111.12
Note: Both IPv4 and IPv6 ranges are supported.
Note: Port number is optional. With port number 8888 the input are 10:8888, 10.44:8888, 10.44.111:8888, 10.44.111.222:8888; Without port number, default port in iLO is used.

.OUTPUTS
 System.Management.Automation.PSObject[]
List of service Name, Oem details, Service Version, Links, IP, and hostname for valid REST sources in the subnet.
Use Get-Member to get details of fields in returned objects.

.NOTES
See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.EXAMPLE
PS C:\> Find-HPREST -Range 10.20.30.1-5
WARNING: It might take a while to search for all the HPE REST sources if the input is a very large range. Use Verbose for more information.


Name           : HP RESTful Root Service
Oem            : @{Hp=}
ServiceVersion : 0.9.5
Time           : 2015-05-28T03:48:12Z
Type           : ServiceRoot.0.10.1
UUID           : 174f7247-ccd3-5b3f-9c15-fe4ae0bcfe14
links          : @{AccountService=; Chassis=; EventService=; Managers=; 
                 Registries=; Schemas=; Sessions=; Systems=; self=}
IP             : 10.20.30.1
HOSTNAME       : abc1.domain.com

Name           : HP RESTful Root Service
Oem            : @{Hp=}
ServiceVersion : 0.9.5
Time           : 2015-05-28T15:50:41Z
Type           : ServiceRoot.0.10.1
UUID           : 8dea7372-23f9-565f-9396-2cd07febbe29
links          : @{AccountService=; Chassis=; EventService=; Managers=; 
                 Registries=; Schemas=; Sessions=; Systems=; self=}
IP             : 10.20.30.2
HOSTNAME       : abc2.domain.com

Name           : HP RESTful Root Service
Oem            : @{Hp=}
ServiceVersion : 0.9.5
Time           : 1970-01-02T11:44:18Z
Type           : ServiceRoot.0.10.0
links          : @{AccountService=; Chassis=; Managers=; Registries=; Schemas=; 
                 Sessions=; Systems=; self=}
IP             : 10.20.30.3
HOSTNAME       : abc3.domain.com

Name           : HP RESTful Root Service
Oem            : @{Hp=}
ServiceVersion : 0.9.5
Time           : 2015-05-27T09:40:19Z
Type           : ServiceRoot.0.10.0
links          : @{AccountService=; Chassis=; Managers=; Registries=; Schemas=; 
                 Sessions=; Systems=; self=}
IP             : 10.20.30.5
HOSTNAME       : abc5.domain.com

.LINK
http://www.hpe.com/servers/powershell

#>
    param (
        [System.String[]] 
        [alias('IP')]
        [parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)] 
        $Range,
        
        [Int32]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)] 
        [ValidateRange(25,600)]
        $Timeout = 25
    )
    Add-Type -AssemblyName System.Core

    $iptoping = New-Object System.Collections.Generic.HashSet[String]
    $validformat = $false

    #put all the input range in to array (one for IPv4, the other for IPv6)
    $InputIPv4Array = @()
    $InputIPv6Array = @()
    $InputHostnameArray = @() 

    # size of $IPv4Array will be the same as size of $InputIPv4Array, the same case to IPv6
    $IPv4Array = @()
    $IPv6Array = @()
	
    $ipv6_one_section='[0-9A-Fa-f]{1,4}'
    $ipv6_one_section_phen="$ipv6_one_section(-$ipv6_one_section)?"
	$ipv6_one_section_phen_comma="$ipv6_one_section_phen(,$ipv6_one_section_phen)*"

    $ipv4_one_section='(2[0-4]\d|25[0-5]|[01]?\d\d?)'
	$ipv4_one_section_phen="$ipv4_one_section(-$ipv4_one_section)?"
	$ipv4_one_section_phen_comma="$ipv4_one_section_phen(,$ipv4_one_section_phen)*"

    $ipv4_regex_inipv6="${ipv4_one_section_phen_comma}(\.${ipv4_one_section_phen_comma}){3}"  
    $ipv4_one_section_phen_comma_dot_findhpilo="(\.\.|\.|${ipv4_one_section_phen_comma}|\.${ipv4_one_section_phen_comma}|${ipv4_one_section_phen_comma}\.)"

    $port_regex = ':([1-9]|[1-9]\d|[1-9]\d{2}|[1-9]\d{3}|[1-5]\d{4}|6[0-4]\d{3}|65[0-4]\d{2}|655[0-2]\d|6553[0-5])'
	$ipv6_regex_findhpilo="^\s*(${ipv4_regex_inipv6}|${ipv6_one_section_phen_comma}|((${ipv6_one_section_phen_comma}:){1,7}(${ipv6_one_section_phen_comma}|:))|((${ipv6_one_section_phen_comma}:){1,6}(:${ipv6_one_section_phen_comma}|${ipv4_regex_inipv6}|:))|((${ipv6_one_section_phen_comma}:){1,5}(((:${ipv6_one_section_phen_comma}){1,2})|:${ipv4_regex_inipv6}|:))|((${ipv6_one_section_phen_comma}:){1,4}(((:${ipv6_one_section_phen_comma}){1,3})|((:${ipv6_one_section_phen_comma})?:${ipv4_regex_inipv6})|:))|((${ipv6_one_section_phen_comma}:){1,3}(((:${ipv6_one_section_phen_comma}){1,4})|((:${ipv6_one_section_phen_comma}){0,2}:${ipv4_regex_inipv6})|:))|((${ipv6_one_section_phen_comma}:){1,2}(((:${ipv6_one_section_phen_comma}){1,5})|((:${ipv6_one_section_phen_comma}){0,3}:${ipv4_regex_inipv6})|:))|((${ipv6_one_section_phen_comma}:){1}(((:${ipv6_one_section_phen_comma}){1,6})|((:${ipv6_one_section_phen_comma}){0,4}:${ipv4_regex_inipv6})|:))|(:(((:${ipv6_one_section_phen_comma}){1,7})|((:${ipv6_one_section_phen_comma}){0,5}:${ipv4_regex_inipv6})|:)))(%.+)?\s*$" 
	$ipv6_regex_findhpilo_with_bra ="^\s*\[(${ipv4_regex_inipv6}|${ipv6_one_section_phen_comma}|((${ipv6_one_section_phen_comma}:){1,7}(${ipv6_one_section_phen_comma}|:))|((${ipv6_one_section_phen_comma}:){1,6}(:${ipv6_one_section_phen_comma}|${ipv4_regex_inipv6}|:))|((${ipv6_one_section_phen_comma}:){1,5}(((:${ipv6_one_section_phen_comma}){1,2})|:${ipv4_regex_inipv6}|:))|((${ipv6_one_section_phen_comma}:){1,4}(((:${ipv6_one_section_phen_comma}){1,3})|((:${ipv6_one_section_phen_comma})?:${ipv4_regex_inipv6})|:))|((${ipv6_one_section_phen_comma}:){1,3}(((:${ipv6_one_section_phen_comma}){1,4})|((:${ipv6_one_section_phen_comma}){0,2}:${ipv4_regex_inipv6})|:))|((${ipv6_one_section_phen_comma}:){1,2}(((:${ipv6_one_section_phen_comma}){1,5})|((:${ipv6_one_section_phen_comma}){0,3}:${ipv4_regex_inipv6})|:))|((${ipv6_one_section_phen_comma}:){1}(((:${ipv6_one_section_phen_comma}){1,6})|((:${ipv6_one_section_phen_comma}){0,4}:${ipv4_regex_inipv6})|:))|(:(((:${ipv6_one_section_phen_comma}){1,7})|((:${ipv6_one_section_phen_comma}){0,5}:${ipv4_regex_inipv6})|:)))(%.+)?\]($port_regex)?\s*$" 	
    $ipv4_regex_findhpilo="^\s*${ipv4_one_section_phen_comma_dot_findhpilo}(\.${ipv4_one_section_phen_comma_dot_findhpilo}){0,3}($port_regex)?\s*$"

    $hostname_regex = "^(([a-zA-Z0-9_]|[a-zA-Z0-9_][a-zA-Z0-9\-_]*[a-zA-Z0-9_])\.)*([A-Za-z0-9_]|[A-Za-z0-9_][A-Za-z0-9\-_]*[A-Za-z0-9_])(" + $port_regex + ")?$";

    if ($Range.GetType().Name -eq 'String')
    {
        if(($range -match $ipv4_regex_findhpilo) -and (4 -ge (Get-IPv4-Dot-Num -strIP  $range)))
        {
            $InputIPv4Array += $Range            
            $validformat = $true
        }
        elseif($range -match $ipv6_regex_findhpilo -or $range -match $ipv6_regex_findhpilo_with_bra)
        {
            if($range.contains(']') -and $range.Split(']')[0].Replace('[','').Trim() -match $ipv4_regex_findhpilo)  #exclude [ipv4] and [ipv4]:port
            {
			   Write-Error $(Get-Message('MSG_INVALID_RANGE'))
               $validformat = $false
               return
            }
            else
            {
               $InputIPv6Array += $Range            
               $validformat = $true
            }
        }
        elseif($range -match $hostname_regex)
        {
            $InputHostnameArray += $Range
            $validformat = $true
        }
        else
        {
			Write-Error $(Get-Message('MSG_INVALID_RANGE'))
            $validformat = $false
            return
        }	
        
    }
	elseif($Range.GetType() -eq [String[]])
    {
        $hasvalidinput=$false
        foreach($r in $Range)
        {            
            if(($r -match $ipv4_regex_findhpilo)  -and (4 -ge (Get-IPv4-Dot-Num -strIP  $r)) )
            {
                $InputIPv4Array += $r                
                $hasvalidinput=$true
            }
            elseif($r -match $ipv6_regex_findhpilo -or $r -match $ipv6_regex_findhpilo_with_bra)
            {
                if($r.contains(']') -and $r.Split(']')[0].Replace('[','').Trim() -match $ipv4_regex_findhpilo) #exclude [ipv4] and [ipv4]:port
                {
                   Write-Warning $([string]::Format($(Get-Message('MSG_INVALID_PARAMETER')) ,$r))           
                }
                else
                {
                   $InputIPv6Array += $r
                   $hasvalidinput=$true
                }
            }
            elseif($range -match $hostname_regex)
            {
                $InputHostnameArray += $r
                $hasvalidinput=$true
            }
            else
            {
                Write-Warning $([string]::Format($(Get-Message('MSG_INVALID_PARAMETER')) ,$r))           
            }                    
        }
        $validformat = $hasvalidinput        
    }
    else
    {
        Write-Error $([string]::Format($(Get-Message('MSG_PARAMETER_INVALID_TYPE')), $Range.GetType().Name, 'Range'))
        $validformat = $false
        return
    }
    
    if($null -eq $Timeout){
        $validformat = $false		
        throw [System.ArgumentException] $(Get-Message("MSG_INVALID_TIMEOUT"))
    }
    else{
        if(($Timeout -match '^\s*[1-9][0-9]*\s*$') -ne $true){ 
            $validformat = $false		
            throw [System.ArgumentException] $(Get-Message('MSG_INVALID_TIMEOUT'))         
        }
    }
	
    if($InputIPv4Array.Length -gt 0)
    {
        #$IPv4Array = New-Object 'object[,]' $InputIPv4Array.Length,4
        $IPv4Array = New-Object System.Collections.ArrayList              
        foreach($inputIP in $InputIPv4Array)
        {
           if($inputIP.contains(':'))
           {
              $returnip = Complete-IPv4 -strIP $inputIP.Split(':')[0].Trim()
              $returnip = $returnip + ':' + $inputIP.Split(':')[1].Trim()      
           }
           else
           {
              $returnip = Complete-IPv4 -strIP $inputIP
           }
           $x = $IPv4Array.Add($returnip)
        }
    }

    if($InputIPv6Array.Length -gt 0)
    {
        #$IPv6Array = New-Object'object[,]' $InputIPv6Array.Length,11
        $IPv6Array = New-Object System.Collections.ArrayList        
        foreach($inputIP in $InputIPv6Array)
        { 
            if($inputIP.contains(']')) #[ipv6] and [ipv6]:port
            {
               $returnip = Complete-IPv6 -strIP $inputIP.Split(']')[0].Replace('[','').Trim()
               $returnip = '[' + $returnip + ']' + $inputIP.Split(']')[1].Trim()
            }
            else #ipv6 without [] nor port
            {
               $returnip = Complete-IPv6 -strIP $inputIP 
               $returnip = '[' + $returnip + ']'
            }
            $x = $IPv6Array.Add($returnip)
        }
    }   

	
	if($validformat)
	{	
		Write-Warning $(Get-Message('MSG_FIND_LONGTIME'))
        foreach($ipv4 in $IPv4Array)
        { 
            if($ipv4.contains(':')) #contains port
            {
               $retarray = Get-IPArrayFromString -stringIP $ipv4.Split(':')[0].Trim() -IPType 'IPv4'
               foreach($oneip in $retarray)
               {
                  $x = $ipToPing.Add($oneip + ':' + $ipv4.Split(':')[1].Trim())
               }                 
            }
            else
            {
               $retarray = Get-IPArrayFromString -stringIP $ipv4 -IPType 'IPv4'
               foreach($oneip in $retarray)
               {
                  $x = $ipToPing.Add($oneip)
               }  
            }                  
        }
				
        foreach($ipv6 in $IPv6Array) #all ipv6 has been changed to [ipv6] or [ipv6]:port
        { 
           $retarray = Get-IPv6FromString -stringIP $ipv6.Split(']')[0].Replace('[','').Trim() 
           foreach($oneip in $retarray)
           {
              $x = $ipToPing.Add('[' + $oneip + ']' + $ipv6.Split(']')[1].Trim())
           }                           
        }		
		
        foreach($hostname in $InputHostnameArray) 
        { 
            $x = $ipToPing.Add($hostname)
        }

        $rstList = @()
		$ThreadPipes = @()
		$poolsize = (@($ipToPing.Count, 256) | Measure-Object -Minimum).Minimum
		if($poolsize -eq 0)
		{
			$poolsize = 1
		}
		Write-Verbose -Message $([string]::Format($(Get-Message('MSG_USING_THREADS_FIND')) ,$poolsize))
		$thispool = Create-ThreadPool $poolsize
		$t = {
			    Param($aComp, $timeout,$RM)

                Function Get-Message
                {
                    Param
                    (
                        [Parameter(Mandatory=$true)][String]$MsgID
                    )
                     #only these strings are used in the two script blocks
                    $LocalizedStrings=@{
	                    'MSG_SENDING_TO'='Sending to {0}'
	                    'MSG_FAIL_HOSTNAME'='DNS name translation not available for {0} - Host name left blank.'
	                    'MSG_FAIL_IPADDRESS'='Invalid Hostname: IP Address translation not available for hostname {0}.'
	                    'MSG_FIND_NO_SOURCE'='No HPE Rest source at {0}'
	                    }
                    $Message = ''
                    try
                    {
                        $Message = $RM.GetString($MsgID)
                        if($null -eq $Message)
                        {
                            $Message = $LocalizedStrings[$MsgID]
                        }
                    }
                    catch
                    {
                        #throw $_
		                $Message = $LocalizedStrings[$MsgID]
                    }

                    if($null -eq $Message)
                    {
		                #or unknown
                        $Message = 'Fail to get the message'
                    }
                    return $Message
                }

                function Invoke-FindHpRestHttpWebRequest
                {
                    param
                    (
                        [System.String]
                        $Uri,

                        [System.String]
                        $Method,

                        [System.Object]
                        $Payload,

                        [System.String]
                        $CmdletName
                    )
                    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Ssl3
    
                    if($null -ne $wr)
                    {
                        $wr = $null
                    }
                    if($null -ne $httpWebRequest)
                    {
                        $httpWebRequest = $null
                    }
                    $wr = [System.Net.WebRequest]::Create($Uri)
                    $httpWebRequest = [System.Net.HttpWebRequest]$wr
                    $httpWebRequest.Method = $Method
                    $httpWebRequest.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip
					$httpWebRequest.KeepAlive = $false
					$httpWebRequest.CachePolicy = New-Object System.Net.Cache.RequestCachePolicy -ArgumentList ([System.Net.Cache.RequestCacheLevel]::NoCacheNoStore)
					$httpWebRequest.ServicePoint.Expect100Continue = $false
                    $httpWebRequest.Headers.Add('X-Auth-Token',$Session.'X-Auth-Token')
                    $httpWebRequest.ServerCertificateValidationCallback = {$true}
                    $httpWebRequest.Timeout = $timeout * 1000
                    try
                    {
                        [System.Net.WebResponse] $resp = $httpWebRequest.GetResponse()
                        #return $resp
                        $rs = $resp.GetResponseStream();
                        [System.IO.StreamReader] $sr = New-Object System.IO.StreamReader -argumentList $rs;
                        $results = ''
                        [string]$results = $sr.ReadToEnd();
						$sr.Close()
                        $rs.Close()
						$resp.Close()                        
                        $finalResult = ConvertFrom-Json $results
                        return $finalResult
                    }
                    catch
                    {
                        $webResponse = $_.Exception.InnerException.Response
                        if($null -ne $webResponse)
                        {
                            if($webResponse.StatusCode.ToString() -eq '308')
                            {
                                $uri = $webResponse.Headers['Location']
                                $wr = [System.Net.WebRequest]::Create($uri)
                                $httpWebRequest = [System.Net.HttpWebRequest]$wr
                                $httpWebRequest.Method = $Method
                                $httpWebRequest.ContentType = 'application/json'
                                $httpWebRequest.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip
								$httpWebRequest.KeepAlive = $false
								$httpWebRequest.CachePolicy = New-Object System.Net.Cache.RequestCachePolicy -ArgumentList ([System.Net.Cache.RequestCacheLevel]::NoCacheNoStore)
								$httpWebRequest.ServicePoint.Expect100Continue = $false
                                $httpWebRequest.Headers.Add('X-Auth-Token',$Session.'X-Auth-Token')
                                $httpWebRequest.ServerCertificateValidationCallback = {$true}
                                $httpWebRequest.Timeout = $timeout * 1000
                                Write-Verbose "Redirecting to $uri"
                                [System.Net.WebResponse] $resp = $httpWebRequest.GetResponse()
                                $Global:Error.RemoveAt(0)
                                $rs = $resp.GetResponseStream();
                                [System.IO.StreamReader] $sr = New-Object System.IO.StreamReader -argumentList $rs;
                                $results = ''
                                [string]$results = $sr.ReadToEnd();
						        $sr.Close()
                                $rs.Close()
						        $resp.Close()                        
                                $finalResult = ConvertFrom-Json $results
                                return $finalResult
                            }
                            else
                            {   
                                $webResponse = $_.Exception.InnerException.Response
                                if($null -ne $webResponse)
                                {
                                    $errorRecord = Get-ErrorRecord -WebResponse $webResponse -CmdletName $CmdletName
                                    $Global:Error.RemoveAt(0)
                                    throw $errorRecord
                                }
                                else
                                {
                                    throw $_
                                }
                            }
                        }
                        else
                        {
                            throw $_
                        }
                    }
                }


                $ipv6_one_section="[0-9A-Fa-f]{1,4}"
                $ipv6_one_section_phen="$ipv6_one_section(-$ipv6_one_section)?"
	            $ipv6_one_section_phen_comma="$ipv6_one_section_phen(,$ipv6_one_section_phen)*"

                $ipv4_one_section="(2[0-4]\d|25[0-5]|[01]?\d\d?)"
	            $ipv4_one_section_phen="$ipv4_one_section(-$ipv4_one_section)?"
	            $ipv4_one_section_phen_comma="$ipv4_one_section_phen(,$ipv4_one_section_phen)*"

                $ipv4_regex_inipv6="${ipv4_one_section_phen_comma}(\.${ipv4_one_section_phen_comma}){3}"  
                $ipv4_one_section_phen_comma_dot_findhpilo="(\.\.|\.|${ipv4_one_section_phen_comma}|\.${ipv4_one_section_phen_comma}|${ipv4_one_section_phen_comma}\.)"

                $port_regex = ":([1-9]|[1-9]\d|[1-9]\d{2}|[1-9]\d{3}|[1-5]\d{4}|6[0-4]\d{3}|65[0-4]\d{2}|655[0-2]\d|6553[0-5])"
	            $ipv6_regex_findhpilo="^\s*(${ipv4_regex_inipv6}|${ipv6_one_section_phen_comma}|((${ipv6_one_section_phen_comma}:){1,7}(${ipv6_one_section_phen_comma}|:))|((${ipv6_one_section_phen_comma}:){1,6}(:${ipv6_one_section_phen_comma}|${ipv4_regex_inipv6}|:))|((${ipv6_one_section_phen_comma}:){1,5}(((:${ipv6_one_section_phen_comma}){1,2})|:${ipv4_regex_inipv6}|:))|((${ipv6_one_section_phen_comma}:){1,4}(((:${ipv6_one_section_phen_comma}){1,3})|((:${ipv6_one_section_phen_comma})?:${ipv4_regex_inipv6})|:))|((${ipv6_one_section_phen_comma}:){1,3}(((:${ipv6_one_section_phen_comma}){1,4})|((:${ipv6_one_section_phen_comma}){0,2}:${ipv4_regex_inipv6})|:))|((${ipv6_one_section_phen_comma}:){1,2}(((:${ipv6_one_section_phen_comma}){1,5})|((:${ipv6_one_section_phen_comma}){0,3}:${ipv4_regex_inipv6})|:))|((${ipv6_one_section_phen_comma}:){1}(((:${ipv6_one_section_phen_comma}){1,6})|((:${ipv6_one_section_phen_comma}){0,4}:${ipv4_regex_inipv6})|:))|(:(((:${ipv6_one_section_phen_comma}){1,7})|((:${ipv6_one_section_phen_comma}){0,5}:${ipv4_regex_inipv6})|:)))(%.+)?\s*$" 
	            $ipv6_regex_findhpilo_with_bra ="^\s*\[(${ipv4_regex_inipv6}|${ipv6_one_section_phen_comma}|((${ipv6_one_section_phen_comma}:){1,7}(${ipv6_one_section_phen_comma}|:))|((${ipv6_one_section_phen_comma}:){1,6}(:${ipv6_one_section_phen_comma}|${ipv4_regex_inipv6}|:))|((${ipv6_one_section_phen_comma}:){1,5}(((:${ipv6_one_section_phen_comma}){1,2})|:${ipv4_regex_inipv6}|:))|((${ipv6_one_section_phen_comma}:){1,4}(((:${ipv6_one_section_phen_comma}){1,3})|((:${ipv6_one_section_phen_comma})?:${ipv4_regex_inipv6})|:))|((${ipv6_one_section_phen_comma}:){1,3}(((:${ipv6_one_section_phen_comma}){1,4})|((:${ipv6_one_section_phen_comma}){0,2}:${ipv4_regex_inipv6})|:))|((${ipv6_one_section_phen_comma}:){1,2}(((:${ipv6_one_section_phen_comma}){1,5})|((:${ipv6_one_section_phen_comma}){0,3}:${ipv4_regex_inipv6})|:))|((${ipv6_one_section_phen_comma}:){1}(((:${ipv6_one_section_phen_comma}){1,6})|((:${ipv6_one_section_phen_comma}){0,4}:${ipv4_regex_inipv6})|:))|(:(((:${ipv6_one_section_phen_comma}){1,7})|((:${ipv6_one_section_phen_comma}){0,5}:${ipv4_regex_inipv6})|:)))(%.+)?\]($port_regex)?\s*$" 	
                $ipv4_regex_findhpilo="^\s*${ipv4_one_section_phen_comma_dot_findhpilo}(\.${ipv4_one_section_phen_comma_dot_findhpilo}){0,3}($port_regex)?\s*$"

                $hostname_regex = "^(([a-zA-Z0-9_]|[a-zA-Z0-9_][a-zA-Z0-9\-_]*[a-zA-Z0-9_])\.)*([A-Za-z0-9_]|[A-Za-z0-9_][A-Za-z0-9\-_]*[A-Za-z0-9_])(" + $port_regex + ")?$";

                $targetWithoutPort = $aComp
			    $ipv4Addr = $null
			    $hostname = $null
			    $ipv6Addr = $null
                $HostnameLookUpFailure = $false
                $IPLookUpFailure = $false
            
			    if($aComp -match $ipv4_regex_findhpilo) #ipv4
	            {
	               $ipv4Addr = $aComp
			       if($aComp.contains(":")) #ipv4:port
			       { 
					    $targetWithoutPort = $aComp.Split(":")[0].Trim()
			       }
			       try
			       {
					    $dns = [System.Net.Dns]::GetHostEntry($targetWithoutPort)
			            $hostname = $dns.Hostname
			       }
			       catch
			       {
                        $HostnameLookUpFailure = $true
					    $global:error.RemoveAt($global:error.count-1)
			       }
	            }
	            elseif($aComp -match $ipv6_regex_findhpilo_with_bra) #all ipv6 have been added [] after completing address
	            {
				    $ipv6Addr = $aComp
				    if($aComp.contains("]:")) #[ipv6]:port
				    {
					    $targetWithoutPort = $aComp.Split("]")[0].Replace("[","").Trim()
				    }

				    try
				    {
					    $dns = [System.Net.Dns]::GetHostEntry($targetWithoutPort)
					    $hostname = $dns.Hostname
				    }
				    catch
				    {
                        $HostnameLookUpFailure = $true
					    $global:error.RemoveAt($global:error.count-1)
				    }
	            }
	            elseif($aComp -match $hostname_regex)
	            {
			       $hostname = $aComp
			       if($aComp.contains(":")) #hostname:port
			       { 
					    $targetWithoutPort = $aComp.Split(":")[0].Trim()
			       }
		   
				    try
				    {
					    $dns = [System.Net.Dns]::GetHostAddresses("$targetWithoutPort")
					    $ipv4Addr = [string]$dns.IPAddressToString
				    }
				    catch
				    {
                        $IPLookUpFailure = $true
					    $global:error.RemoveAt($global:error.count-1)
				    }
	            }

                $iLOAddr = @{$true=$ipv4Addr;$false=$ipv6Addr}[-Not [string]::IsNullorEmpty($ipv4Addr)]
			    
			    $retobj = New-Object -TypeName PSObject   
				$rstAddr = $aComp
				$inUri = "https://$aComp/rest/v1"
				$inMethod = "GET"
				$inCmdletName = "Find-HPEREST"

				try 
				{ 
        			$rstobj = Invoke-FindHpRestHttpWebRequest -Uri $inUri -Method $inMethod -CmdletName $inCmdletName
  
					$rstobj |   Add-Member NoteProperty IP  $iLOAddr 
					$rstobj |   Add-Member NoteProperty HOSTNAME $hostname
					
                    if($rstobj.PSObject.Members.Name.Contains('Type'))
                    { 
                        if(($rstobj.Type).indexOf('ServiceRoot.') -ne -1) 
					    {
						    $retobj | Add-Member NoteProperty data $rstobj
					    }
                    }
                    elseif($rstobj.PSObject.Members.Name.Contains('@odata.type')) 
                    {
                        if(($rstobj.'@odata.type').indexOf('ServiceRoot.') -ne -1) 
					    {
						    $retobj | Add-Member NoteProperty data $rstobj
					    }
                    }

                    if($HostnameLookUpFailure)
			        {
				        $retobj | Add-Member NoteProperty errormsg $([string]::Format($(Get-Message('MSG_FAIL_HOSTNAME')), $targetWithoutPort))                            
			        }
                    if($IPLookUpFailure)
			        {
				        $retobj | Add-Member NoteProperty errormsg $([string]::Format($(Get-Message('MSG_FAIL_IPADDRESS')), $hostname))                            
			        }
				}
				catch 
				{
                    if($null -eq $retobj.errormsg)
                    {
					    $retobj | Add-Member NoteProperty errormsg $([string]::Format($(Get-Message('MSG_FIND_NO_SOURCE')), $rstAddr))
                    }
                    else
                    {
                        $retobj.errormsg = $([string]::Format($(Get-Message('MSG_FIND_NO_SOURCE')), $rstAddr))
                    }
				}
			    return $retobj
        } 
		#end of $t scriptblock
            
        if($ipToPing.Count -eq 1)
		{
		    [string]$comp = $ipToPing[0]
		    $rstList += Invoke-Command -ScriptBlock $t -ArgumentList $comp, $Timeout, $RM
		}
		else
        {
		    foreach ($comp in $ipToPing)
            {
			    $ThreadPipes += Start-ThreadScriptBlock -ThreadPool $thispool -ScriptBlock $t -Parameters $comp, $Timeout, $RM
		    }
        

		    #this waits for and collects the output of all of the scriptblock pipelines - using showprogress for verbose
		    if ($VerbosePreference -eq 'Continue') {
			    $rstList = Get-ThreadPipelines -Pipelines $ThreadPipes -ShowProgress
		    }
		    else {
			    $rstList = Get-ThreadPipelines -Pipelines $ThreadPipes
		    }
		    $thispool.Close()
		    $thispool.Dispose()
        }

        foreach($ilo in $rstList)
        {
			if($null -ne $ilo.errormsg)
            {
                Write-Verbose $ilo.errormsg
            }
            
            if($null -ne $ilo.data)
            {
                $ilo.data
            }
        }  
        
    }    
    else{
        #Write-Error $(Get-Message('MSG_INVALID_USE'))
        throw $(Get-Message('MSG_INVALID_USE'))
    }
}
#end of Find-HPRest

function Format-HPRESTDir
{
<#
.SYNOPSIS
Displays HPE REST data in directory format.

.DESCRIPTION
Takes the node array returned by Get-HPRESTDir and displays each node as a directory.

.PARAMETER Session
Session PSObject returned by executing Connect-HPREST cmdlet. It must have RootURI and X-Auth-Token for executing this cmdlet.

.PARAMETER NodeArray
The array created by Get-HPRESTDir, containing a collection of REST API nodes in an array.

.PARAMETER AutoSize
Switch parameter that turns the autosize feature on when true.

.NOTES
See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.INPUTS
System.String
You can pipe the NodeArray obtained from Get-HPRESTDir to Format-HPRESTDir.

.OUTPUTS
System.Management.Automation.PSCustomObject or System.Object[]
Format-HPRESTDir returns a PSCustomObject or an array of PSCustomObject if Recurse parameter is set to true.

.EXAMPLE
PS C:\> $href = 'rest/v1/sessions'

PS C:\> $nodeArray = Get-HPRESTDir -Session $session -Href $href -Recurse

PS C:\> Format-HPRESTDir -NodeArray $NodeArray

Location: https://10.20.30.1/rest/v1
Link: /rest/v1/Sessions

Type           Name                Value                                                            
----           ----                -----                                                            
String         @odata.context      /redfish/v1/$metadata#Sessions                                   
String         @odata.id           /redfish/v1/Sessions/                                            
String         @odata.type         #SessionCollection.SessionCollection                             
String         Description         Manager User Sessions                                            
Object[]       Items               {@{@odata.context=/redfish/v1/$metadata#SessionService/Session...
               href                /rest/v1/SessionService/Sessions/admin55dd017b39999998           
PSCustomObject links               @{Member=System.Object[]; self=}                                 
               href                /rest/v1/SessionService/Sessions/admin55dd017b39999998           
               href                /rest/v1/Sessions                                                
Object[]       Members             {@{@odata.id=/redfish/v1/SessionService/Sessions/admin55dd017b...
Int32          Members@odata.count 1                                                                
String         MemberType          Session.1                                                        
String         Name                Sessions                                                         
PSCustomObject Oem                 @{Hp=}                                                           
               href                /rest/v1/SessionService/Sessions/admin55dd017b39999998           
Int32          Total               1                                                                
String         Type                Collection.1.0.0                                                 


Link: /rest/v1/SessionService/Sessions/admin55dd017b39999998

Type           Name           Value                                                        
----           ----           -----                                                        
String         @odata.context /redfish/v1/$metadata#SessionService/Sessions/Members/$entity
String         @odata.id      /redfish/v1/SessionService/Sessions/admin55dd017b39999998/   
String         @odata.type    #Session.1.0.0.Session                                       
String         Description    Manager User Session                                         
String         Id             admin55dd017b39999998                                        
PSCustomObject links          @{self=}                                                     
               href           /rest/v1/SessionService/Sessions/admin55dd017b39999998       
String         Name           User Session                                                 
PSCustomObject Oem            @{Hp=}                                                       
String         Type           Session.1.0.0                                                
String         UserName       admin                                                        


Link: /rest/v1/Sessions

Type           Name                Value                                                            
----           ----                -----                                                            
String         @odata.context      /redfish/v1/$metadata#Sessions                                   
String         @odata.id           /redfish/v1/Sessions/                                            
String         @odata.type         #SessionCollection.SessionCollection                             
String         Description         Manager User Sessions                                            
Object[]       Items               {@{@odata.context=/redfish/v1/$metadata#SessionService/Session...
               href                /rest/v1/SessionService/Sessions/admin55dd017b39999998           
PSCustomObject links               @{Member=System.Object[]; self=}                                 
               href                /rest/v1/SessionService/Sessions/admin55dd017b39999998           
               href                /rest/v1/Sessions                                                
Object[]       Members             {@{@odata.id=/redfish/v1/SessionService/Sessions/admin55dd017b...
Int32          Members@odata.count 1                                                                
String         MemberType          Session.1                                                        
String         Name                Sessions                                                         
PSCustomObject Oem                 @{Hp=}                                                           
               href                /rest/v1/SessionService/Sessions/admin55dd017b39999998           
Int32          Total               1                                                                
String         Type                Collection.1.0.0                                                 



This example shows the formatted node array obtained from href for sessions.The list of Href links in a property are listed below the property name and value

.LINK
http://www.hpe.com/servers/powershell

#>
    param
    (
        [PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session,
		
		#($NodeArray, $Session, $AutoSize)
        [System.Object[]]
        [parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        $NodeArray,

        [switch]
        [parameter(Mandatory=$false)]
        $AutoSize
    )
    BEGIN 
    {
        function Find-Hrefs($nodeForFindHrefs)
        {
            if($nodeForFindHrefs.GetType().ToString() -eq 'System.Object[]')
            {
                foreach($obj in $nodeForFindHrefs)
                {
                    $obj | Get-Member -type NoteProperty | ForEach-Object {
                        $name = $_.Name ;
                        $value = $obj."$($_.Name)"
                        if($name -eq "href")
                        {
                            foreach($v in $value)
                            { 
                                if($v -notin $Global:DirValues.Value)
                                {
                                    $NodeProperties = New-Object System.Object
                                    $NodeProperties | Add-Member -type NoteProperty -name Type -value $null
                                    $NodeProperties | Add-Member -type NoteProperty -name Name -value $name
                                    $NodeProperties | Add-Member -type NoteProperty -name Value -value $v
                                    $Global:DirValues += $NodeProperties
                                }
                            }
                        }
                        else
                        {
                            if($null -ne $value -and $value.GetType().ToString() -eq 'System.Object[]')
                            {
                                $arrHasNonNullElements = $false
                                foreach($i in $value)
                                {
                                    if($null -ne $i)
                                    {
                                        $arrHasNonNullElements = $true
                                        break
                                    }
                                }
                                if($arrHasNonNullElements -eq $false)
                                {
                                    continue
                                }
                            }
                     
                            if($null -ne $value -and ($value |Get-Member).MemberType -contains "NoteProperty")
                            {
                                Find-Hrefs -nodeForFindHrefs $value
                            }
                        }
                    }
                }
            }
            else
            {
                $nodeForFindHrefs | Get-Member -type NoteProperty | ForEach-Object {
                    $name = $_.Name ;
                    $value = $nodeForFindHrefs."$($_.Name)"
                    if($name -eq 'href')
                    {
                        
                        foreach($v in $value)
                        { 
                            if($v -notin $Global:DirValues.Value)
                            {
                                $NodeProperties = New-Object System.Object
                                $NodeProperties | Add-Member -type NoteProperty -name Type -value $null
                                $NodeProperties | Add-Member -type NoteProperty -name Name -value $name
                                $NodeProperties | Add-Member -type NoteProperty -name Value -value $v
                                $Global:DirValues += $NodeProperties
                            }
                        }
                    }

                    else
                    {
                        if($null -ne $value -and $value.GetType().ToString() -eq 'System.Object[]')
                        {
                            $arrHasNonNullElements = $false
                            foreach($i in $value)
                            {
                                if($null -ne $i)
                                {
                                    $arrHasNonNullElements = $true
                                    break
                                }
                            }
                            if($arrHasNonNullElements -eq $false)
                            {
                                continue
                            }
                        }
                    
                        if($null -ne $value -and ($value |Get-Member).MemberType -contains 'NoteProperty')
                        {
                            Find-Hrefs -nodeForFindHrefs $value
                        }
                    }
                }
            }
        }

        Function Format-Node($nodeForFormat, $href)
        {
            "Link: $href"
            $Global:DirValues = @()
            $nodeForFormat | get-member -type NoteProperty | foreach-object {
                $name = $_.Name ; 
                $value = $nodeForFormat."$($_.Name)"
                if($null -ne $value)
                {
                    $NodeProperties = New-Object System.Object
                    $NodeProperties | Add-Member -type NoteProperty -name Type -value $value.GetType().name
                    $NodeProperties | Add-Member -type NoteProperty -name Name -value $name
                    $NodeProperties | Add-Member -type NoteProperty -name Value -value $value
                    $Global:DirValues += $NodeProperties
                }
                else
                {
                    $NodeProperties = New-Object System.Object
                    $NodeProperties | Add-Member -type NoteProperty -name Type -value "Null"
                    $NodeProperties | Add-Member -type NoteProperty -name Name -value $name
                    $NodeProperties | Add-Member -type NoteProperty -name Value -value $value
                    $Global:DirValues += $NodeProperties
                }

                if($null -ne $value -and $value.GetType().ToString() -eq 'System.Object[]')
                {
                    $arrHasNonNullElements = $false
                    foreach($i in $value)
                    {
                        if($null -ne $i)
                        {
                            $arrHasNonNullElements = $true
                            break
                        }
                    }
                    if($arrHasNonNullElements -eq $false)
                    {
                        continue
                    }
                    foreach($v in $value)
                    {
                        Find-Hrefs -nodeForFindHrefs $v
                    }

                }
                if($null -ne $value -and ($value |Get-Member).MemberType -contains 'NoteProperty')
                {
                    Find-Hrefs -nodeForFindHrefs $value
                }
            }
            if($AutoSize -eq $true)
            {
                $Global:DirValues | Format-Table -AutoSize
            }
            else
            {
                $Global:DirValues | Format-Table
            }
        }
        if(!($null -eq $session.Location -or $session.Location -eq ""))
        {
            "$(Get-Message('MSG_FORMATDIR_LOCATION')): $($Session.RootUri)"
        }
    }
    PROCESS
    {
		if($session.IsConnected -eq $false)
		{
			throw $([string]::Format($(Get-Message('MSG_INVALID_SESSION_OBJECT'))))
		}
	
        if($NodeArray.GetType().ToString() -match 'PScustomobject')
        {
            $href1 = $NodeArray.links.self.href
            Format-Node -nodeForFormat $NodeArray -href $href1
        }
        elseif($NodeArray.GetType().ToString() -eq 'System.Object[]')
        {
            foreach($node1 in $NodeArray)
            {
                if($node1.GetType().ToString() -match 'PSCustomObject')
                {
                    $href1 = $node1.links.self.href
                    Format-Node -nodeForFormat $node1 -href $href1
                }
                else
                {
                    throw $([string]::Format($(Get-Message('MSG_PARAMETER_INVALID_TYPE')), $node1.GetType().Name, 'NodeArray'))
                }
            }
        }
    }
    END
    {

    }
}

function Get-HPRESTData
{
<#
.SYNOPSIS
Retrieves Data and Properties of data for provided Href.

.DESCRIPTION
Retrieves Data and Properties for data specified by given Href. This cmdlet returns two sets of values - Data and properties. The properties include if the data item is readonly, possible values in enum, enum values' descriptions and datatypes of allowed value.

.PARAMETER Session
Session PSObject returned by executing Connect-HPREST cmdlet. It must have RootURI and X-Auth-Token for executing this cmdlet.

.PARAMETER Href
Specifies the value of Href of REST source to be retrieved. Href is of the format 'rest/v1/xxxx' where xxxx is the path to the resource. An example value of the Href parameter is 'rest/v1/systems/1'. The URI to which the HTTP web request is sent is created using the protocol and host information from the session object and the value of this Href parameter.

.PARAMETER Headers
A list of Key-Value pairs in the form of a hashtable to be included in the HTTP web request.

.PARAMETER Language
The language code for the schema property information to be retrieved. The default value is 'en'. The allowed values depend on the languages available on the system.

.INPUTS
System.String
You can pipe the Href to Get-HPRESTData.

.OUTPUTS
Two objects of type System.Management.Automation.PSCustomObject or one object of System.Object[]
Get-HPRESTData returns two object of type PSObject - first has the retrieved data and the second has properties in the form of System.Collections.Hashtable. If you use one variable for returned object, then the variable will be an array with first term as the data PSObject and second element as the property list in System.Collections.Hashtable

.NOTES
See typical usage examples in the HPRESTExamples.ps1 file installed with this module.


.EXAMPLE
PS C:\> $data,$prop = Get-HPRESTData -Href rest/v1/systems/1 -Session $session

PS C:\> $data


AssetTag         : 
AvailableActions : {@{Action=Reset; Capabilities=System.Object[]}}
Bios             : @{Current=}
Boot             : @{BootSourceOverrideEnabled=Disabled; BootSourceOverrideSupported=System.Object[]; 
                   BootSourceOverrideTarget=None; UefiTargetBootSourceOverride=None; 
                   UefiTargetBootSourceOverrideSupported=System.Object[]}
Description      : Computer System View
HostCorrelation  : @{HostMACAddress=System.Object[]; HostName=; IPAddress=System.Object[]}
IndicatorLED     : Off
Manufacturer     : HP
Memory           : @{Status=; TotalSystemMemoryGB=8}
Model            : ProLiant DL380 Gen9
Name             : Computer System
Oem              : @{Hp=}
Power            : On
Processors       : @{Count=2; ProcessorFamily=Intel(R) Xeon(R) CPU E5-2683 v3 @ 2.00GHz; Status=}
SKU              : 501101-001
SerialNumber     : LCHAS01RJ5Y00Z
Status           : @{Health=Warning; State=Enabled}
SystemType       : Physical
Type             : ComputerSystem.0.9.7
UUID             : 31313035-3130-434C-4841-533031524A35
links            : @{Chassis=System.Object[]; Logs=; ManagedBy=System.Object[]; self=}




PS C:\> $prop

Name                           Value                                                                                    
----                           -----                                                                                    
BootSourceOverrideSupported    @{Schema_AllowedValue=System.Object[]; schema_enumDescriptions=; Schema_Type=System.Ob...
UUID                           @{Schema_Description=The universal unique identifier for this system.; Schema_Type=Sys...
Status                         @{Schema_Description=This property indicates the TPM or TM status.; Schema_AllowedValu...
Description                    @{Schema_Description=This object represents the Description property.; Schema_Type=str...
PowerOnDelay                   @{Schema_Description=The PowerAutoOn policy delay that can also be found in the HpBios...
BootSourceOverrideTarget       @{Schema_Description=The current boot source to be used at next boot instead of the no...
Model                          @{Schema_Description=The model information that the manufacturer uses to refer to this...
Name                           @{Schema_Description=The name of the resource or array element.; Schema_Type=string; S...
Date                           @{Schema_Description=The build date of the firmware.; Schema_Type=string; Schema_ReadO...
  .
  .
  .
IntelligentProvisioningVersion @{Schema_Description= Intelligent Provisioning Version.; Schema_Type=string; Schema_Re...
IntelligentProvisioningIndex   @{Schema_Description= Index in the Firmware Version Table for Intelligent Provisioning...
AssetTag                       @{Schema_Description=A user-definable tag that is used to track this system for invent...
AllowableValues                @{Schema_Description=The supported values for this property on this resource.; Schema_...
BootSourceOverrideEnabled      @{Schema_Description=BootSourceOverrideTarget must be specified before BootSourceOverr...
IndicatorLED                   @{Schema_Description=The state of the indicator LED.; Schema_AllowedValue=System.Objec...
href                           @{Schema_Description=The URI of an internal resource; Schema_Type=string; Schema_ReadO...
VersionString                  @{Schema_Description=This string represents the version of the firmware image.; Schema...



PS C:\> $prop.IndicatorLED


Schema_Description      : The state of the indicator LED.
Schema_AllowedValue     : {Unknown, Lit, Blinking, Off}
schema_enumDescriptions : @{Unknown=The state of the Indicator LED cannot be determined.; Lit=The Indicator LED is 
                          lit.; Blinking=The Indicator LED is blinking.; Off=The Indicator LED is off.}
Schema_Type             : {string, null}
Schema_ReadOnly         : False

.LINK
http://www.hpe.com/servers/powershell

#>
    param
    (
	    [PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session,

        [System.String]
        [parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        $Href,

        [Hashtable]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Headers,
	
        [String]
        $Language = 'en'
    )
    if($null -eq $session -or $session -eq '')
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,'Session'))
    }
    if($session.IsConnected -eq $false)
    {
        throw $([string]::Format($(Get-Message('MSG_INVALID_SESSION_OBJECT'))))
    }
    
    try
    {
        $nodeData = Get-HPRESTDataRaw -Href $Href -Headers $Headers -Session $Session
        $schema = Get-HPRESTSchema -Type $nodeData.Type -Session $Session -Headers $Headers -Language $Language
        $DictionaryOfSchemas = [System.Collections.Hashtable]@{}

        $props = Get-HPRESTDataPropRecurse -Data $nodeData -Schema $schema -Session $Session -DictionaryOfSchemas $DictionaryOfSchemas -Headers $Headers -Language $Language
        return $nodeData, $props
    }
    finally
    {
    }
}

function Get-HPRESTDataRaw
{
<#
.SYNOPSIS
Retrieves data for provided Href.

.DESCRIPTION
Retrieves the HPE REST data returned from the source pointed to by the Href in PSObject format.
This cmdlet uses the session information to connect to the REST data source and retrieves the data to the user in PSObject format. Session object with ‘RootUri’, ‘X-Auth-Token’ and ‘Location’ information of the session must be provided for using sessions to retrieve data.

.PARAMETER Href
Specifies the value of Href of REST source to be retrieved. Href is of the format 'rest/v1/xxxx' where xxxx is the path to the resource. An example value of the Href parameter is 'rest/v1/systems/1'. The URI to which the HTTP web request is sent is created using the protocol and host information from the session object and the value of this Href parameter.

.PARAMETER Session
Session PSObject returned by executing Connect-HPREST cmdlet. It must have RootURI and X-Auth-Token for executing this cmdlet.

.PARAMETER OutputType
Specifies the format of required output. Possible values are PSObject, String and ByteArray. Default value is PSObject. If you need to download a binary file from the interface, then use 'ByteArray' as OutputType. The returned value can be stored into a file using 'WriteAllBytes()' method in 'System.IO.File' class.

.PARAMETER Headers
A list of Key-Value pairs in the form of a hashtable to be included in the HTTP web request.

.NOTES
Paging in the REST data is automatically handled by this cmdlet. You will not be able to retrieve individual pages when using this cmdlet.

.INPUTS
System.String
You can pipe the Href parameter to Get-HPRESTDataRaw.

.OUTPUTS
System.Management.Automation.PSCustomObject
Get-HPRESTDataRaw returns a PSCustomObject that has the retrieved data.

.NOTES
See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.EXAMPLE
PS C:\> $sys = Get-HPRESTDataRaw -Href rest/v1/systems/1 -Session $session

PS C:\> $sys


AssetTag         : 
AvailableActions : {@{Action=Reset; Capabilities=System.Object[]}}
Bios             : @{Current=}
Boot             : @{BootSourceOverrideEnabled=Disabled; BootSourceOverrideSupported=System.Object[]; BootSourceOverrideTarget=None; UefiTargetBootSourceOverride=None; UefiTargetBootSourceOverrideSupported=System.Object[]}
Description      : Computer System View
HostCorrelation  : @{HostMACAddress=System.Object[]; HostName=; IPAddress=System.Object[]}
IndicatorLED     : Off
Manufacturer     : HP
Memory           : @{Status=; TotalSystemMemoryGB=8}
Model            : ProLiant DL380 Gen9
Name             : Computer System
Oem              : @{Hp=}
Power            : On
Processors       : @{Count=2; ProcessorFamily=Intel(R) Xeon(R) CPU E5-2683 v3 @ 2.00GHz; Status=}
SKU              : 501101-001
SerialNumber     : LCHAS01RJ5Y00Z
Status           : @{Health=Warning; State=Enabled}
SystemType       : Physical
Type             : ComputerSystem.0.9.7
UUID             : 31313035-3130-434C-4841-533031524A35
links            : @{Chassis=System.Object[]; Logs=; ManagedBy=System.Object[]; self=}

This example retrieves system data.

.EXAMPLE

PS C:\> $sessions = Get-HPRESTDataRaw -Href 'rest/v1/Sessions' -Session $session
        foreach($ses in $sessions.Items)
        {
            if($ses.Oem.Hp.MySession -eq $true)
            {
                $ses
                $ses.oem.hp
            }
        }



Description : Manager User Session
Name        : User Session
Oem         : @{Hp=}
Type        : Session.0.9.5
UserName    : admin
links       : @{self=}

AccessTime            : 2014-10-30T18:56:31Z
LoginTime             : 2014-10-30T18:56:30Z
MySession             : True
Privileges            : @{LoginPriv=True; RemoteConsolePriv=True; 
                        UserConfigPriv=True; VirtualMediaPriv=True; 
                        VirtualPowerAndResetPriv=True; iLOConfigPriv=True}
Type                  : HpiLOSession.0.9.5
UserAccount           : admin
UserDistinguishedName : 
UserExpires           : 2014-10-30T19:01:31Z
UserIP                : 
UserTag               : Web UI
UserType              : Local

This example shows the process to retrieve current user session.


.EXAMPLE
PS C:\> $registries = Get-HPRESTDataRaw -Href 'rest/v1/registries' -Session $session
        foreach($reg in $registries.items)
        {
            if($reg.Schema -eq $biosAttReg)
            {
                $attRegLoc = $reg.Location|Where-Object{$_.Language -eq 'en'}|%{$_.uri.extref}
                break
            }
        }
        $attReg = Get-HPRESTDataRaw -Href $attRegLoc -Session $session
        $attReg.RegistryEntries.Dependencies


The example shows retrieval of Dependencies of BIOS settings. The BIOS attribute registry value is present in $biosAttReg. The English version of the registry is retrieved.

.LINK
http://www.hpe.com/servers/powershell

#>
    param
    (
		[PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session,

        [System.String]
        [parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        $Href,

        [System.String]
        [parameter(Mandatory=$false)][ValidateSet("PSObject","String","ByteArray")]
        $OutputType = "PSObject",

        [Hashtable]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Headers
    )
     
    if($null -eq $session -or $session -eq '')
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,'Session'))
    }
    if($session.IsConnected -eq $false)
    {
        throw $([string]::Format($(Get-Message('MSG_INVALID_SESSION_OBJECT'))))
    }
    
    try
    {
		try
        {
            $uri = Get-HPRESTUriFromHref -Session $Session -Href $Href
            $Method = 'GET'
            $cmdletName = 'Get-HPRESTDataRaw'

			if($Session.DisableCertificateAuthentication.IsPresent -eq $false)
			{
				$resp = Invoke-HttpWebRequest -Uri $uri -Method $Method -CmdletName $cmdletName -Session $Session -Headers $Headers
			}
			else
			{
				$resp = Invoke-HttpWebRequest -Uri $uri -Method $Method -CmdletName $cmdletName -Session $Session -Headers $Headers -DisableCertificateAuthentication
			}

            $rs = $resp.GetResponseStream();
            if($OutputType -eq "PSObject")
            {
                [System.IO.StreamReader] $sr = New-Object System.IO.StreamReader -argumentList $rs;
                $results = ''
                [string]$results = $sr.ReadToEnd();
				$sr.Close()
                $rs.Close()
				$resp.Close()        

                $finalResult = Convert-JsonToPSObject $results
                Merge-HPRESTPage -FinalObj $finalResult -ThisPage $finalResult -Session $Session -Headers $Headers
            }
            elseif($OutputType -eq "String")
            {
                [System.IO.StreamReader] $sr = New-Object System.IO.StreamReader -argumentList $rs;
                $results = ''
                [string]$results = $sr.ReadToEnd();
				$sr.Close()
                $rs.Close()
				$resp.Close()

                $finalResult = $results
            }
            elseif($OutputType -eq "ByteArray")
            {
                [System.IO.BinaryReader] $br = New-Object System.IO.BinaryReader -argumentList $rs #@($rs, [System.Text.Encoding]::UTF8)

                $memStream = New-Object System.IO.MemoryStream
                $Buffer = New-Object Byte[] 10240

                Do {
                    $BytesRead = $br.Read($Buffer, 0, $Buffer.Length)
                    $memStream.Write($Buffer,0,$BytesRead)    
                } While ($BytesRead -gt 0)
                
				$br.Close()
                $rs.Close()
				$resp.Close()
                
                $finalResult = $memStream.ToArray()
				$memStream.Close()
            }
        }
        finally
        {
			if ($null -ne $sr -and $sr -is [System.IDisposable]){$sr.Dispose()}
            if ($null -ne $rs -and $rs -is [System.IDisposable]){$rs.Dispose()}
			if ($null -ne $resp -and $resp -is [System.IDisposable]){$resp.Dispose()}            
        }

        return $finalResult
    }
    finally
    {
    }
}

function Get-HPRESTDir
{
<#
.SYNOPSIS
Gets HPE REST data and stores into a node array.

.DESCRIPTION
Get-HPRESTDir cmdlet gets the data at location specified by the href parameter and stores it in a node array. If Recurse parameter is set, the cmdlet will iterate to every href stored within the first node and every node there after storing each node into a node array.

.PARAMETER Session
Session PSObject returned by executing Connect-HPREST cmdlet. It must have RootURI and X-Auth-Token for executing this cmdlet.

.PARAMETER Href
Specifies the value of Href of REST source from which the data nodes are retrieved. Href is of the format 'rest/v1/xxxx' where xxxx is the path to the resource. An example value of the Href parameter is 'rest/v1/systems/1'. The URI to which the HTTP web request is sent is created using the protocol and host information from the session object and the value of this Href parameter.

.PARAMETER Recurse
Switch parameter that turns recursion on if true.

.PARAMETER Headers
A list of Key-Value pairs in the form of a hashtable to be included in the HTTP web request.

.INPUTS
System.String
You can pipe the Href to Get-HPRESTDir.

.OUTPUTS
System.Object[]
Get-HPRESTDir returns an array of PSObject objects that contains the data at the location specified by the Href parameter and by hrefs in that data if Recurse parameter is set to true.

.NOTES
See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.Example
PS C:\windows\system32> $NodeArray = Get-HPRESTDir -Session $session -Href $href 

PS C:\windows\system32> $NodeArray 


Description : Manager User Sessions
Items       : {@{Description=Manager User Session; Name=User Session; Oem=; Type=Session.0.9.5; UserName=admin; links=}, @{Description=Manager User Session; Name=User Session; Oem=; 
              Type=Session.0.9.5; UserName=admin; links=}}
MemberType  : Session.0
Name        : Sessions
Oem         : @{Hp=}
Total       : 2
Type        : Collection.0.9.5
links       : @{Member=System.Object[]; self=}

This example shows the basic execution where there is no recursion. Only the data at the specified Href is returned.

.Example
PS C:\windows\system32> $NodeArray = Get-HPRESTDir -Session $session -Href $href -Recurse

PS C:\windows\system32> $NodeArray


Description : Manager User Sessions
Items       : {@{Description=Manager User Session; Name=User Session; Oem=; Type=Session.0.9.5; UserName=admin; links=}, @{Description=Manager User Session; Name=User Session; Oem=; 
              Type=Session.0.9.5; UserName=admin; links=}}
MemberType  : Session.0
Name        : Sessions
Oem         : @{Hp=}
Total       : 2
Type        : Collection.0.9.5
links       : @{Member=System.Object[]; self=}

Description : Manager User Session
Name        : User Session
Oem         : @{Hp=}
Type        : Session.0.9.5
UserName    : admin
links       : @{self=}

Description : Manager User Session
Name        : User Session
Oem         : @{Hp=}
Type        : Session.0.9.5
UserName    : admin
links       : @{self=}


This example shows a recursive execution of the cmdlet with the specified Recurse parameter. The second and the third PSObjects shown above are retrieved recursively using the Href from the 'links' property in each object under the 'Items' property in the first object.


.LINK
http://www.hpe.com/servers/powershell

#>
    param
    (
	    [PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session,
		
        [System.String]
        [parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        $Href,

        [Switch]
        [parameter(Mandatory=$false)]
        $Recurse,

        [Hashtable]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Headers
    )
    if($null -eq $session -or $session -eq "")
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,"Session"))
    }
    if($session.IsConnected -eq $false)
    {
        throw $([string]::Format($(Get-Message('MSG_INVALID_SESSION_OBJECT'))))
    }
    
    try{
		$global:SeenHrefs = [System.Collections.ArrayList]@() #The hrefs of the already visited nodes.
        $global:NodeArr = @() #The Array of nodes to be returned.

        $fromInnerObject = 0
        $currHref = $Href
        function Find-Hrefs($node, $currHref) #This function finds all the OdataIds in a node recursively and adds them to the $SeenHrefs list, 
        {                          #adds the new node to the node array, and uses the new node to call the function again.
            if($null -eq $node -or ((($node | Get-Member).MemberType -contains 'NoteProperty') -eq $false))
            {
                return
            }
            #$node | Get-Member -type NoteProperty | foreach {
            $props = $node | Get-Member -MemberType NoteProperty
            if($fromInnerObject -eq 0)
            {
                $currHref = $node.'links'.'self'.'href'
            }
            foreach($prop in $props)
            {
                $name = $prop.Name
                $value = $node."$($prop.Name)"
                if($null -eq $value)
                {
                    continue
                }

                if($value.GetType().ToString() -eq 'System.Object[]')
                {
                    $arrHasNonNullElements = $false
                    foreach($i in $value)
                    {
                        if($null -ne $i)
                        {
                            $arrHasNonNullElements = $true
                            break
                        }
                    }
                    if($arrHasNonNullElements -eq $false)
                    {
                        continue
                    }
                }

                if($name -eq 'href')
                {
                    foreach($v in $value)
                    {
                        if($Global:SeenHrefs -notcontains $v.ToLower() -and $null -ne $v)# -and $sub -eq $parentHref)
                        {
                            $currHrefSplit = $currHref -split '/'
                            $vSplit = $v -split '/'
                            $diffTreeFlag = $false
                            for($i=$currHrefSplit.length-1; $i-ge0; $i--)
                            {
                                if($vSplit[$i] -ne $currHrefSplit[$i])
                                {
                                    $diffTreeFlag = $true
                                    break
                                }
                            }

                            if($diffTreeFlag -eq $false)
                            {
                                try
                                {   
                                    Write-Verbose $v
                                    $newnode = Get-HPRESTDataRaw -Href $v -Session $Session -Headers $Headers
                                    $Global:SeenHrefs += $v.ToLower() 
                                    $global:NodeArr += $newnode
                                    if($recurse -eq $true)
                                    {
                                        Find-Hrefs -node $newnode -href $v
                                    }
                                }
                                catch
                                {
                                    Write-Error "$v`n$_"
                                }
                                
                            }
                        }
                    }
                }
                elseif($null -ne $value -and $value.GetType().ToString() -eq 'System.Object[]')
                {
                    foreach($v in $value)
                    {
                        Find-Hrefs -node $v $currHref
                    }
                }
                elseif($null -ne $value -and $value.GetType().ToString() -match 'PSCustomObject')
                {
                    $fromInnerObject = $fromInnerObject +1
                    Find-Hrefs -node $value $currHref
                    $fromInnerObject = $fromInnerObject -1
                }
            }
        }


        if($recurse -ne $true)
        {
            try
            {
                $newnode = Get-HPRESTDataRaw -Href $href -Session $Session -Headers $Headers
            }
            catch
            {
                Write-Error "$href`n$_"
            }
            $global:NodeArr+=$newnode
        }
        else
        {

            try
            {
                Write-Verbose $Href
                $newnode = Get-HPRESTDataRaw -Href $href -Session $Session -Headers $Headers
            }
            catch
            {
                Write-Error "$href`n$_"
            }
            if($Href.StartsWith('/') -eq $false)
            {
                $Href = '/'+$Href
            }
            $global:SeenHrefs += $href.ToLower()
            $global:NodeArr += $newnode
            Find-Hrefs $newnode $Href
        }
        $ret = $global:NodeArr
        return $ret
    }
    finally
    {
    }
}

function Get-HPRESTMessage
{
<#
.SYNOPSIS
Retrieves message details from the MessageId returned from the API.

.DESCRIPTION
This cmdlet retrieves details of the API response messages specified by the MessageID parameter. These messages may be informational, warning or an error message. The possible messages are specified in the Data Model Reference document. These messages are obtained as returned objects by executing cmdlets like Set-HPRESTData, Edit-HPRESTData etc.

.PARAMETER Session
Session PSObject returned by executing Connect-HPREST cmdlet. It must have RootURI and X-Auth-Token for executing this cmdlet.

.PARAMETER MessageID
API response message object returned by executing cmdlets like Set-HPRESTData and Edit-HPRESTData.

.PARAMETER MessageArg
API response message arguments returned in the message from cmdlets like Set-HPRESTData, Edit-HPRESTData, etc. The MessageArg parameter has an array of arguments that provides parameter names and/or values relevant to the error/messages returned from cmdlet execution.

.PARAMETER Headers
A list of Key-Value pairs in the form of a hashtable to be included in the HTTP web request.

.INPUTS
System.String
You can pipe the MessageID parameter to Get-HPRESTMessage.

.OUTPUTS
System.Management.Automation.PSCustomObject
Get-HPRESTMessage returns a PSCustomObject that has the error details with Description, Mesage, Severity, Number of arguments to the message, parameter types and the resolution.

.NOTES
See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.EXAMPLE
PS C:\> $setting = @{'AdminName' = 'TestAdmin'}
PS C:\> $ret = Set-HPRESTData -Href rest/v1/systems/1/bios/settings -Setting $setting -Session $session
PS C:\> $ret

Messages                    Name                        Type                       
--------                    ----                        ----                       
{@{MessageID=iLO.0.10.Sy... Extended Error Information  ExtendedError.0.9.6        



PS C:\> $ret.Messages

MessageID                                                                          
---------                                                                          
iLO.0.10.SystemResetRequired                                                       



PS C:\> $status = Get-HPRESTMessage -MessageID $ret.Messages[0].MessageID -Session $session
PS C:\> $status


Description  : The system properties were correctly changed, but will not take effect until the system is reset.
Message      : One or more properties were changed and will not take effect until system is reset.
Severity     : Warning
NumberOfArgs : 0
ParamTypes   : {}
Resolution   : Reset system for the settings to take effect.


In this example, when a BIOS setting(AdminName) is updated, an object is returned with messageID  iLO.0.10.SystemResetRequired. When this message ID is passed to Get-HPRESTMessage, details of this message/error are returned.


.EXAMPLE
PS C:\> $tempBoot = @{'BootSourceOverrideTarget'='test'}
    $OneTimeBoot = @{'Boot'=$tempBoot}
PS C:\> $ret = Set-HPRESTData -Href rest/v1/systems/1 -Setting $OneTimeBoot -Session $session
PS C:\> $ret|fl


Messages : {@{MessageArgs=System.Object[]; MessageID=Base.0.0.PropertyValueNotInList}}
Name     : Extended Error Information
Type     : ExtendedError.0.9.5


PS C:\> $ret.Messages

MessageArgs                                     MessageID                                     
-----------                                     ---------                                     
{test, BootSourceOverrideTarget}                Base.0.0.PropertyValueNotInList  


PS C:\> $status = Get-HPRESTMessage -MessageArgs $ret.Messages[0].MessageArgs -MessageID $ret.Messages[0].MessageID -Session $session
PS C:\> $status


Description  : The value type is correct, but the value is not supported.
Message      : The value test for the property BootSourceOverrideTarget is not valid.
Severity     : Warning
NumberOfArgs : 2
ParamTypes   : {String, String}
Resolution   : If the operation did not complete, choose a value from the enumeration list and 
               resubmit your request.


In this example, when an invalid value is set as temporary boot device, an object is returned with messageID  Base.0.0.PropertyValueNotInList. When this message ID is passed to Get-HPRESTMessage along with the message arguments, details of this message/error are returned.

.LINK
http://www.hpe.com/servers/powershell

#>
    param
    (
		[PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session,

        [System.String]
        [parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        $MessageID,

        [System.Object]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $MessageArg,

        [Hashtable]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Headers
    )

    if($null -eq $session -or $session -eq "")
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,"Session"))
    }
    if($session.IsConnected -eq $false)
    {
        throw $([string]::Format($(Get-Message('MSG_INVALID_SESSION_OBJECT'))))
    }
    
    try
    {
	    $regs = Get-HPRESTDataRaw -Href 'rest/v1/registries' -Session $session -Headers $Headers
	    $location = ''
	    $errorname = ''
	    foreach($item in $regs.links.member.href)
	    {
            $hrefSplit = $item.split('/')
	        if(($MessageID.Split('.'))[0] -eq $hrefSplit[$hrefsplit.Length-1])
	        {
                $regItem = Get-HPRESTDataRaw -Href $item -Session $Session
	            $location = ($regItem.Location | Where-Object{$_.Language -eq 'en'}).uri.extref
	            $split = $MessageID.Split('.')
	            $errorname = $split[$split.Length-1]
	            break
	        }
	    }
        if($location -eq '')
        {
            throw $([string]::Format($(Get-Message('MSG_MESSAGEID_NOTFOUND')), $MessageID))
        }
	    $registry = Get-HPRESTDataRaw -Href $location -Session $session -Headers $Headers
	    if(-not($registry.Messages.$errorname -eq '' -or $null -eq $registry.Messages.$errorname ))
	    {
	        $errDetail = $registry.Messages.$errorname
	        $msg = $errDetail.Message
	        $newMsg = Set-Message -Message $msg -MessageArg $MessageArg
	        $errDetail.Message = $newMsg
	        return $errDetail
	    }
	    else
        {
            throw $([string]::Format($(Get-Message('MSG_MESSAGEID_NOTFOUND')), $MessageID))
        }
	}
    finally
    {
    }
}; Set-Alias Get-HPRESTError Get-HPRESTMessage -Scope Global

function Get-HPRESTHttpData
{
<#
.SYNOPSIS
Retrieves HTTP data for provided Href.

.DESCRIPTION
Retrieves the HTTP web response with the REST data returned from the source pointed to by the Href in PSObject format.
This cmdlet uses the session information to connect to the REST data source and retrieves the webresponse which has the headers from which 'Allow' methods can be found. These can be GET, POST, PATCH, PUT, DELETE. Session object with ‘RootUri’, ‘X-Auth-Token’ and ‘Location’ information of the session must be provided for using sessions to retrieve data.

.PARAMETER Session
Session PSObject returned by executing Connect-HPREST cmdlet. It must have RootURI and X-Auth-Token for executing this cmdlet.

.PARAMETER Href
Specifies the value of Href of REST source to be retrieved. Href is of the format 'rest/v1/xxxx' where xxxx is the path to the resource. An example value of the Href parameter is 'rest/v1/systems/1'. The URI to which the HTTP web request is sent is created using the protocol and host information from the session object and the value of this Href parameter.

.PARAMETER Headers
A list of Key-Value pairs in the form of a hashtable to be included in the HTTP web request.

.INPUTS
System.String
You can pipe the Href parameter to Get-HPRESTHttpData.

.OUTPUTS
System.Management.Automation.PSCustomObject
Get-HPRESTHttpData returns a PSCustomObject that has the retrieved HTTP data.

.NOTES
See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.EXAMPLE
PS C:\> $httpSys = Get-HPRESTHttpData -Href rest/v1/systems/1 -Session $session

PS C:\> $httpSys


IsMutuallyAuthenticated : False
Cookies                 : {}
Headers                 : {Allow, Connection, X_HP-CHRP-Service-Version, Content-Length...}
SupportsHeaders         : True
ContentLength           : 2920
ContentEncoding         : 
ContentType             : application/json
CharacterSet            : 
Server                  : HP-iLO-Server/1.30
LastModified            : 5/27/2015 11:04:47 AM
StatusCode              : OK
StatusDescription       : OK
ProtocolVersion         : 1.1
ResponseUri             : https://10.20.30.1/rest/v1/systems/1
Method                  : GET
IsFromCache             : False



PS C:\> $httpSys.Headers['Allow']
GET, HEAD, POST, PATCH

PS C:\> $httpSys.Headers['Connection']
keep-alive

The example shows HTTP details returned and the 'Allow' and 'Connection' header values

.LINK
http://www.hpe.com/servers/powershell

#>
    param
    (
        [PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session,
		
        [System.String]
        [parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        $Href,

        [Hashtable]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Headers
    )

    try
    {
        if($null -eq $session -or $session -eq '')
        {
            throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,'Session'))
        }
        if($session.IsConnected -eq $false)
        {
            throw $([string]::Format($(Get-Message('MSG_INVALID_SESSION_OBJECT'))))
        }

        $uri = Get-HPRESTUriFromHref -Session $Session -Href $Href
        $Method = 'GET'
        $cmdletName = 'Get-HPRESTHttpData'

        if($DisableCertificateAuthentication.IsPresent -eq $false)
        {
            $webResponse = Invoke-HttpWebRequest -Uri $uri -Method $Method -CmdletName $cmdletName -Session $Session -Headers $Headers
        }
        else
        {
            $webResponse = Invoke-HttpWebRequest -Uri $uri -Method $Method -CmdletName $cmdletName -Session $Session -Headers $Headers -DisableCertificateAuthentication
        }

        $props = $webResponse.PSObject.Properties.Name
        $retHttpData = New-Object PSObject
        foreach($prop in $props)
        {
            Add-Member -InputObject $retHttpData -MemberType NoteProperty $prop $webResponse.$prop
        }
        $webResponse.Close()
        return $retHttpData
    }
    finally
    {
    }
}

function Get-HPRESTIndex
{ 
<#
.SYNOPSIS
Gets an index of HPE REST API data.

.DESCRIPTION
Using a passed in REST API session, the cmdlet recursively traverses the REST API tree and indexes everything that is found. Using the switch parameters, the user can customize what gets indexed. The returned index is a set of key-value pairs where the keys are the terms in the HPE REST data source and the values are list of occurances of the term and details of the term like Property name or value where the term is found, the hrefs to access the data item and its schema, etc.

.PARAMETER Session
Session PSObject returned by executing Connect-HPREST cmdlet. It must have RootURI and X-Auth-Token for executing this cmdlet.

.PARAMETER DateAndTime
Switch value that causes the iLO Date and Time node to be indexed when true.

.PARAMETER ExtRef
Switch value that causes external refrences to be indexed when true.

.PARAMETER Schema
Switch value that causes Schemas to be in indexed when  true.

.PARAMETER Log
Switch value that causes IML and IEL logs to be indexed when true.

.PARAMETER Headers
A list of Key-Value pairs in the form of a hashtable to be included in the HTTP web request(s) to retrieve data.

.INPUTS
System.Management.Automation.PSCustomObject
You can pipe Session object obtained by executing Connect-HPREST cmdlet to Get-HPRESTIndex

.OUTPUTS
System.Collections.SortedList
Get-HPRESTIndex returns a sorted list of key-value pairs which is the index. The keys are terms in the HPE REST source and values are details of keys like Porperty name and value where the key is found, href to access the key and the schema href for the property.

.NOTES
See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.EXAMPLE
PS C:\> $index = Get-HPRESTIndex -Session $session

PS C:\> $index.Keys -match "power"
AllocatedPowerWatts
AutoPowerOn
AveragePowerOutputWatts
BalancedPowerPerf
CollabPowerControl
DynamicPowerResponse
DynamicPowerSavings
FastPowerMeter
HpPowerMeter
HpPowerMetricsExt
HpServerPowerSupply
LastPowerOutputWatts
MaxPowerOutputWatts
MinProcIdlePower
MixedPowerSupplyReporting
OldPowerOnPassword
Power
PowerAllocationLimit
PowerandResetPriv
PowerAutoOn
PowerButton
PowerCapacityWatts
PowerConsumedWatts
PowerMeter
PowerMetrics
PowerOnDelay
PowerOnLogo
PowerOnPassword
PowerProfile
PowerRegulator
PowerRegulatorMode
PowerRegulatorModesSupported
PowerSupplies
PowerSupplyStatus
PowerSupplyType
PushPowerButton
VirtualPowerAndResetPriv

PS C:\> $index.PowerMeter


PropertyName : PowerMeter
Value        : @{href=/rest/v1/Chassis/1/PowerMetrics/PowerMeter}
DataHref     : /rest/v1/Chassis/1/PowerMetrics
SchemaHref   : /rest/v1/SchemaStore/en/HpPowerMetricsExt.json
Tag          : PropertyName

PropertyName : href
Value        : /rest/v1/Chassis/1/PowerMetrics/PowerMeter
DataHref     : /rest/v1/Chassis/1/PowerMetrics
SchemaHref   : /rest/v1/SchemaStore/en/HpPowerMetricsExt.json
Tag          : Value

PropertyName : href
Value        : /rest/v1/Chassis/1/PowerMetrics/PowerMeter
DataHref     : /rest/v1/ResourceDirectory
SchemaHref   : /rest/v1/SchemaStore/en/HpiLODateTime.json
Tag          : Value

This example shows how to create and use the index on an HPE REST data source. First, the index is created using Get-HPRESTIndex cmdlets and store the created index. The index stores key-value pairs for the entire data source. The term "power" is searched in the keys of the index and it returns all the keys which has "power" as substring. When a specific key "PowerMeter" is seleted, the list of values is displayed where PowerMeter was encountered in the HPE REST data.

.LINK
http://www.hpe.com/servers/powershell

#>
    param
    (
        [PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session,

        [Switch]
        [parameter(Mandatory=$false)]
        $DateAndTime,

        [Switch]
        [parameter(Mandatory=$false)]
        $ExtRef,

        [Switch]
        [parameter(Mandatory=$false)]
        $Schema,

        [Switch]
        [parameter(Mandatory=$false)]
        $Log,

        [Hashtable]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Headers
    )
    if($null -eq $session -or $session -eq "")
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,"Session"))
    }
    if($session.IsConnected -eq $false)
    {
        throw $([string]::Format($(Get-Message('MSG_INVALID_SESSION_OBJECT'))))
    }

    try
    {
		$Global:SeenHrefs = [System.Collections.ArrayList]@() #The hrefs of the already visited nodes.

        $Global:SeenSchemaTypes = [System.Collections.ArrayList]@() #The hrefs of the already visited nodes.

        $KeyValueIndex= New-Object System.Collections.SortedList
    
        $SchemaIgnoreList = @("object", "string", "BaseNetworkAdapter.0.9.5", "Type.json#", "array", "integer", "null", "number", "boolean", "map","Enumeration","Password")

        #$Seperator = @(" ", "!", "`"", "#", "$", "%", "&", "``", "(", ")", "*", "'","+", "-", ".", "/", ":", ";", "<", "=", ">", "?", "@", "[", "\", "]", "^", "_", "~", "{", "|", "}")

        $IgnoreList = @("a", "A", "and", "any", "are", "as", "at", "be", "been", "for", "from", "has", "have", "if", "in", "is", "or", "the", "The", "this", "This", "to", "was", "when", "which", "will")

        $PropertyNameIgnoreList = @("Created", "Type", "action", "UUID", "Updated", "updated")

        $hrefIgnoreList = @()

        $TraverseRefs = @("href")

        if($DateAndTime -ne $true)
        {
            $hrefIgnoreList += "/rest/v1/Managers/1/DateTime"
        }

        if($ExtRef -eq $true)
        {
            $TraverseRefs += "extref"
        }

        if($Log -ne $true)
        {
            $hrefIgnoreList += "/rest/v1/Managers/1/Logs/IEL/Entries"
            $hrefIgnoreList += "/rest/v1/Systems/1/Logs/IML/Entries"
        }
        $rootDisableCertError = $false
        function Step-ThroughNoteProperties($node, $Dhref, $SchemaHref, $s, $SchemaNode)
        {
            if($null -ne $node.Type)
            {
                $NodeType = $node.type
                foreach($SchemaType in $NodeType)
                {
                    if($null -ne $SchemaType.'$ref')
                    {
                        $SchemaType = $SchemaType.'$ref'
                    } 
                    if($null -ne $SchemaType -and $SchemaIgnoreList -notcontains $SchemaType -and $Global:SeenSchemaTypes -notcontains $SchemaType)
                    {
                        $Global:SeenSchemaTypes += $SchemaType
                        if($rootDisableCertError -eq $true)
                        {
                            continue
                        }
                        $schemaHref = ""
                        $path = ""
                        $type = $schemaType
                        try
                        {
                            ## Type is a PSObject in schema when it is a property name in the data object
                            if($type.GetType().ToString() -notmatch 'PSCustomObject') 
                            {
                                if($schemaType -match '.json#')
                                {
                                    $type = $schemaType.Substring(0,$SchemaType.IndexOf('.json#'))
                                    $path = $schemaType.Substring($SchemaType.IndexOf('.json#')+6)
                                }
                                $schHref = Get-HPRESTSchemaExtref -Type $type -Session $session -Headers $Headers
                                if($schHref -ne "")
                                {
                                    $schemaref = $schref
                                }
                            }
                            else
                            {
                                Step-ThroughNoteProperties -node $type -Dhref $SchemaHref -s $s
                                continue
                            }
                            if("" -ne $schemaHref -and $Schema -and $Global:SeenHrefs -notcontains $SchemaHref)
                            {
                                if($rootDisableCertError -eq $true)
                                {
                                    continue
                                }
                                $Global:SeenHrefs+= $SchemaHref
                                $SchemaNode = $null
                                try
                                {
                                    $schemaNode = Get-HPRESTDataRaw -Href $SchemaHref -Session $session -Headers $Headers
                                    if($path -ne "") 
                                    {
                                        $propPath = $path -split '/'
    
                                        for($i=1;$i-lt$propPath.length;$i++)
                                        {
                                            $schemaNode = $schemaNode.($propPath[$i])
                                        }
                                    }
                                }
                                catch
                                {
                                    Write-Error $_
                                }
                                Step-ThroughNoteProperties -node $SchemaNode -Dhref $SchemaHref -s $s
                            }
                        }
                        catch
                        {
                            Write-Error $_
                            if($node.links.self.href -eq '/rest/v1')
                            {
                                $rootDisableCertError = $true
                                break
                            }
                        }
                    }
                }
            }
            #$node | get-member -type NoteProperty | foreach-object { #Displays all the note properties within the node.
             $props = $node | get-member -type NoteProperty 
             foreach($prop in $props) {
                if($PropertyNameIgnoreList -notcontains $prop.Name)
                {
                    $name=$prop.Name ;
                    $temp = $node.$name
                    $Information = New-Object PSObject
                        $Information | Add-Member -type NoteProperty -Name PropertyName -Value $name
                        $Information | Add-Member -type NoteProperty -Name Value -Value $temp
                        $Information | Add-Member -type NoteProperty -Name DataHref -Value $DHref
                        $Information | Add-Member -type NoteProperty -Name SchemaHref -Value $SchemaHref
                        $Information | Add-Member -type NoteProperty -Name Tag -Value "PropertyName"
                        Limit-Entries -Name $name -Information $information

                    if($null -ne $temp -and $temp -ne "" -and $PropertyNameIgnoreList -notcontains $name)
                    {
                        $parsedProp = $false
                        $arrHasNonNullElements = $false
                        if($temp.GetType().ToString() -eq 'System.Object[]')
                        {
                            foreach($i in $temp)
                            {
                                if($null -ne $i)
                                {
                                    $arrHasNonNullElements = $true
                                    break
                                }
                            }
                            if($arrHasNonNullElements -eq $false)
                            {
                                Split-Value -DOdataId $DOdataId -SchemaOdataId $SchemaOdataId -node $node -Value $temp -name $name
                                $parsedProp = $true
                            }
                        }
                        
                        if($parsedProp -eq $false)
                        {
                            if(($temp | Get-Member).MemberType -contains "NoteProperty") 
                            {
                                Step-ThroughNoteProperties -node $temp -Dhref $Dhref -SchemaHref $SchemaHref -s $s -SchemaNode $SchemaNode
                
                            }
                            elseif(($temp.Count) -gt 1)
                            {
                                foreach($t in $temp)
                                {
                                    if($null -ne $t -and ($t | Get-Member).MemberType -contains "NoteProperty") 
                                    {
                                        Step-ThroughNoteProperties -node $t -Dhref $Dhref -SchemaHref $SchemaHref -s $s -SchemaNode $SchemaNode
            
                                    }
                                    else
                                    {
                                        Split-Value -DHref $Dhref -SchemaHref $SchemaHref -node $node -Value $t -name $name
                                    }
                                }
                            }
                            else
                            {
                                Split-Value -DHref $Dhref -SchemaHref $SchemaHref -node $node -Value $temp -name $name
                            }
                        }
                        if($TraverseRefs -contains $name)
                        {
                        
                
                            foreach($t in $temp)
                            {
                                if($Global:SeenHrefs -notcontains $t -and $hrefIgnoreList -notcontains $t -and (Confirm-Href $t))
                                {
                                    try
                                    {
                                        if($rootDisableCertError -eq $true)
                                        {
                                            continue
                                        }
            
                                        $Global:SeenHrefs += $t
                                        $NewNode = Get-HPRESTDataRaw -Href $t -Session $session -Headers $Headers
                                        if($null -ne $NewNode)
                                        {
                                            Step-ThroughNoteProperties -node $NewNode -Dhref $t -SchemaHref $SchemaHref -s $s -SchemaNode $SchemaNode
                                        }
                                    }
                                    Catch
                                    {
                                        Write-Error $_
                                    }
                                }        
                            }
                        }
                    }
                }
            }
        }

        function Confirm-Href($value)
        {
            if($value -match "/rest/v1")
            {
                return $true
            }
            else
            {
                return $false
            }
        }

        function Confirm-isNumeric ($value) 
        {
            $x = 0
            $isNum = [System.Int32]::TryParse($value, [ref]$x)
            return $isNum
        }

        function Limit-Entries($Name, $Information)
        {
            $PassedRules = $true

            if(Confirm-isNumeric $name)
            {
                $PassedRules = $false
            }
            elseif($name -eq "" -or $null -eq $Information)
            {
                $PassedRules = $false
            }
            elseif($IgnoreList -ccontains $name)
            {
                $PassedRules = $false
            }
            if($PassedRules)
            {
                Add-KeyValueIndex $Name $Information
            }
        }

        function Add-KeyValueIndex($Name, $Information)
        {
            if($KeyValueIndex.Contains($Name))
            {
                $KeyValueIndex.$Name += $Information
            }
            else
            {
                $ray = @()
                $KeyValueIndex.Add($Name, $ray)
                $KeyValueIndex.$Name += $Information
            }
        }

        function Split-Value($DHref, $SchemaHref, $node, $Value, $name)
        {
            $Information = New-Object PSObject
            $Information | Add-Member -type NoteProperty -Name PropertyName -Value $name
            $Information | Add-Member -type NoteProperty -Name Value -Value $value
            $Information | Add-Member -type NoteProperty -Name DataHref -Value $DHref
            $Information | Add-Member -type NoteProperty -Name SchemaHref -Value $SchemaHref
            $Information | Add-Member -type NoteProperty -Name Tag -Value "Value"

            $value = $value -replace '[ -/]+', " "
            $value = $value -replace '[:-@]+', " "
            $value = $value -replace '[[-``]+', " "
            $value = $value -replace '[{-~]+', " "

            if($null -ne $value -and $value -ne "")
            {
                $SplitValue = $Value.Split(" ")
                foreach($word in $SplitValue)
                {
                    if($IgnoreList -notcontains $word)
                    {
                    
                        Limit-Entries -Name $word -Information $information
                    }
                }
            }
        }

        Step-ThroughNoteProperties -node $session.RootData -Dhref $href -s $Session

        return $KeyValueIndex
    }
    finally
    {
    }
}

function Get-HPRESTModuleVersion
{
<#
.SYNOPSIS
Gets the module details for the HPRESTCmdlets module.

.DESCRIPTION
The Get-HPRESTModuleVersion cmdlet gets the module details for the HPRESTCmdlets module. The details include name of file, path, description, GUID, product version, .Net version, Environment details and supported UICultures with respective version.
    
.INPUTS

.OUTPUTS
System.Management.Automation.PSCustomObject
    
    Get-HPRESTmoduleVersion retuns a System.Management.Automation.PSCustomObject object.

.EXAMPLE
Get-HPRESTModuleVersion 

Name                    : HPRESTCmdlets
Path                    : C:\Program Files\WindowsPowerShell\Modules\HPRESTCmdlets\1.2.0.0\HPRESTCmdlets.psm1
Description             : HPE REST PowerShell cmdlets create an interface to HPE REST devices such as iLO and Moonshot iLO CM. 
                          These cmdlets can be used to get and set HPE REST data and to invoke actions on these devices and the systems they manage.
                          There are also advanced functions that can create an index or directory of HPE REST data sources. A file with examples called HPRESTExamples.ps1 is included in this release.
GUID                    : 2f9b1ca0-2031-45c0-9d82-a432014abfdf
Version                 : 1.2.0.0
DotNetVersion           : 4.6.1
PSVersion               : @{PSVersion=5.0.10586.117; PSCompatibleVersions=System.Version[]; BuildVersion=10.0.10586.117; CLRVersion=4.0.30319.42000; WSManStackVersion=3.0; PSRemotingProtocolVersion=2.3; SerializationVersion=1.1.0.1}
OSVersion               : @{Caption=Microsoft Windows 8.1 Enterprise; CSDVersion=; Version=6.3.9600; BuildNumber=9600}
CurrentUICultureName    : en-US
CurrentUICultureVersion : 1.2.0.0
AvailableUICulture      : @{UICultureName=en-US; UICultureVersion=1.2.0.0}


This example shows the cmdlets module details.

.LINK
http://www.hpe.com/servers/powershell

#>
    [CmdletBinding(PositionalBinding=$false)]
    param() # no parameters

        function Get-OSVersion
    {
        $wmiSearcher = [wmisearcher]"SELECT * FROM Win32_OperatingSystem"
        $osSearcher = $wmiSearcher.Get()
        $dotNetVersion = New-Object PSObject
        $dotNetVersion | Add-Member 'Caption' $osSearcher.Caption
        $dotNetVersion | Add-Member 'CSDVersion' $osSearcher.CSDVersion
        $dotNetVersion | Add-Member 'Version' $osSearcher.Version
        $dotNetVersion | Add-Member 'BuildNumber' $osSearcher.BuildNumber
        
        return $dotNetVersion
    }

    function Get-DotNetVersion
    {
        $dotNetVersion = $null
        $regKey = $null

        $dotNetFramework1to3RegistryPath = "SOFTWARE\\Microsoft\\NET Framework Setup\\NDP"
        $dotNetFramework4RegistryPath = 'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\'
        
        [Microsoft.Win32.RegistryKey]$regKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry32)
        $reg = $regkey.OpenSubKey($dotNetFramework4RegistryPath).GetValue("Release")
        switch ($reg)
	    {
		    460798 { [Version]::TryParse('4.7', [ref]$dotNetVersion) | Out-Null }
            394802 { [Version]::TryParse('4.6.2', [ref]$dotNetVersion) | Out-Null }
		    394806 { [Version]::TryParse('4.6.2', [ref]$dotNetVersion) | Out-Null }
		    394254 { [Version]::TryParse('4.6.1', [ref]$dotNetVersion) | Out-Null }
            394271 { [Version]::TryParse('4.6.1', [ref]$dotNetVersion) | Out-Null }
		    393295 { [Version]::TryParse('4.6.1', [ref]$dotNetVersion) | Out-Null }
		    393297 { [Version]::TryParse('4.6.1', [ref]$dotNetVersion) | Out-Null }
		    379893 { [Version]::TryParse('4.5.2', [ref]$dotNetVersion) | Out-Null }
		    378675 { [Version]::TryParse('4.5.1', [ref]$dotNetVersion) | Out-Null }
		    378758 { [Version]::TryParse('4.5.1', [ref]$dotNetVersion) | Out-Null }
		    378389 { [Version]::TryParse('4.5', [ref]$dotNetVersion) | Out-Null }
	    }

        if($null -eq $dotNetVersion)
        {
            [Microsoft.Win32.RegistryKey]$installedVersions = ([Microsoft.Win32.Registry]::LocalMachine).OpenSubKey($dotNetFramework1to3RegistryPath);
		    $versionNames = $installedVersions.GetSubKeyNames();
		    # version names start with 'v', eg, 'v3.5' which needs to be trimmed off before conversion
		    $Framework = $versionNames[$versionNames.Length - 1].Remove(0, 1), [cultureinfo]::InvariantCulture
		    $SP = $installedVersions.OpenSubKey($versionNames[$versionNames.Length - 1]).GetValue("SP", 0)
		    [Version]::TryParse($sp.ToString(),[ref]$dotNetVersion) | Out-Null
        }

        return $dotNetVersion
    }

    $mod = Get-Module | Where-Object {$_.Name -eq "HPRESTCmdlets"}
    $cul = Get-UICulture
    $versionObject = New-Object PSObject
    $versionObject | Add-member "Name" $mod.Name
    $versionObject | Add-member "Path" $mod.Path
    $versionObject | Add-member "Description" $mod.Description
    $versionObject | Add-member "GUID" $mod.GUID
    $versionObject | Add-member "Version" $mod.Version
    $versionObject | Add-member 'DotNetVersion' (Get-DotNetVersion)
    $versionObject | Add-member 'PSVersion' (New-Object PSObject -Property ($PSVersionTable))
    $versionObject | Add-member 'OSVersion' (Get-OSVersion)
    $versionObject | Add-member "CurrentUICultureName" $cul.Name
    $versionObject | Add-member "CurrentUICultureVersion" $mod.Version
    
    $UICulture = New-Object PSObject
    $UICulture | Add-Member 'UICultureName' 'en-US'
    $UICulture | Add-Member 'UICultureVersion' $mod.Version
    $AvailableUICulture += $UICulture
          
    $versionObject | Add-Member "AvailableUICulture" $AvailableUICulture

    return $versionObject
}

function Get-HPRESTSchema
{
<#
.SYNOPSIS
Retrieve schema for the specified Type.

.DESCRIPTION
Retrieves the schema for the specified Type of REST data. The cmdlet first gets the JSON link of the schema and then gets the data from the schema store that has the schema.

.PARAMETER Session
Session PSObject returned by executing Connect-HPREST cmdlet. It must have RootURI and X-Auth-Token for executing this cmdlet.

.PARAMETER Type
Value of the Type field obtained from the data for which schema is to be found.

.PARAMETER Language
The language code of the schema to be retrieved. The default value is 'en'. The allowed values depend on the languages available on the system.

.PARAMETER Headers
A list of Key-Value pairs in the form of a hashtable to be included in the HTTP web request.

.INPUTS
System.String
You can pipe the Type parameter to Get-HPRESTSchema.

.OUTPUTS
System.Management.Automation.PSCustomObject
Get-HPRESTSchema returns a PSCustomObject that has the retrieved schema of the specified type.

.NOTES
See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.EXAMPLE
PS C:\> $sch = Get-HPRESTSchema -Type ComputerSystem.0.9.7 -Session $session

PS C:\> $sch


$schema              : http://json-schema.org/draft-04/schema#
title                : ComputerSystem.0.9.7
type                 : object
readonly             : False
additionalProperties : False
description          : The schema definition of a computer system and its properties. A computer system represents a physical or virtual machine and the local resources, such as memory, CPU, and other devices that can be accessed from that machine.
properties           : @{Oem=; Name=; Modified=; Type=; SystemType=; links=; AssetTag=; Manufacturer=; Model=; SKU=; SerialNumber=; Version=; PartNumber=; Description=; VirtualSerialNumber=; UUID=; HostCorrelation=; Status=; BIOSPOSTCode=; IndicatorLED=; Power=; Boot=; Bios=; Processors=; Memory=; AvailableActions=}
required             : {Name, Type}
actions              : @{description=The POST custom actions defined for this type (the implemented actions might be a subset of these).; actions=}


PS C:\> $sch.properties


Oem                 : @{type=object; readonly=False; additionalProperties=True; properties=}
Name                : @{$ref=Name.json#}
Modified            : @{$ref=Modified.json#}
Type                : @{$ref=Type.json#}
SystemType          : @{type=string; description=The type of computer system that this resource represents.; enum=System.Object[]; enumDescriptions=; readonly=True; etag=True}
links               : @{type=object; additionalProperties=True; properties=; readonly=True; description=The links array contains the related resource URIs.}
    .
    .
    .
AssetTag            : @{type=System.Object[]; description=A user-definable tag that is used to track this system for inventory or other client purposes.; readonly=False; etag=True}
IndicatorLED        : @{type=System.Object[]; description=The state of the indicator LED.; enum=System.Object[]; enumDescriptions=; readonly=False; etag=True}
AvailableActions    : @{type=array; readonly=True; additionalItems=False; uniqueItems=True; items=}


PS C:\> $sch.properties.IndicatorLED


type             : {string, null}
description      : The state of the indicator LED.
enum             : {Unknown, Lit, Blinking, Off}
enumDescriptions : @{Unknown=The state of the Indicator LED cannot be determined.; Lit=The Indicator LED is lit.; Blinking=The Indicator LED is blinking.; Off=The Indicator LED is off.}
readonly         : False
etag             : True

This example shows schema of type ComputerSystem.0.9.7

.LINK
http://www.hpe.com/servers/powershell

#>
    param
    (
        [PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session,
		
        [System.String]
        [parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        $Type,

        [System.String]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Language = 'en',

        [Hashtable]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Headers
    )
    if($null -eq $session -or $session -eq '')
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,'Session'))
    }
    if($session.IsConnected -eq $false)
    {
        throw $([string]::Format($(Get-Message('MSG_INVALID_SESSION_OBJECT'))))
    }

    try
    {
        $schemaJSONHref = Get-HPRESTSchemaExtref -Type $Type -Session $Session -Language $Language -Headers $Headers
        if($null -ne $schemaJSONHref)
        {
            $schema = Get-HPRESTDataRaw -Href $schemaJSONHref -Session $Session -Headers $Headers
        }
    
        return $schema
    }
    finally
    {
    }
}

function Get-HPRESTSchemaExtref
{
<#
.SYNOPSIS
Retrieves the uri of the JSON file that contains the schema for the specified type.

.DESCRIPTION
Schema JSON file is pointed to by a uri. This link is retrieved from the external reference (extref) in Location field of the Type in rest/v1/schemas. This is uri of the JSON file that contains the schema for the specified type. This cmdlet retrieves this URI that points to the JSON schema file.

.PARAMETER Session
Session PSObject returned by executing Connect-HPREST cmdlet. It must have RootURI and X-Auth-Token for executing this cmdlet.

.PARAMETER Type
Type value of the data for which schema JSON file link has to be retrieved. The Type value is present in the REST data.

.PARAMETER Language
The language code of the schema for which the JSON URI is to be retrieved. The default value is 'en'. The allowed values depend on the languages available on the system.

.PARAMETER Headers
A list of Key-Value pairs in the form of a hashtable to be included in the HTTP web request.

.INPUTS
System.String
You can pipe the Type parameter to Get-HPRESTSchemaExtref.

.OUTPUTS
System.String
Get-HPRESTSchemaExtref returns a String that has the Extref of the schema specified by the Type parameter.

.NOTES
See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.EXAMPLE
PS C:\> $schemaJSONhref = Get-HPRESTSchemaExtref -type ComputerSystem.0.9.7 -Session $session
    

PS C:\> $schemaJSONhref
/rest/v1/SchemaStore/en/ComputerSystem.json


This example shows that the schema for ComputerSystem.0.9.7 is stored at the external reference /rest/v1/SchemaStore/en/ComputerSystem.json. The schema is retrieved using this as value of 'Href' parameter for Get-HPRESTData or Get-HPRESTDataRaw and navigate to the 'Properties' field.

.LINK
http://www.hpe.com/servers/powershell

#>
    param
    (
        [PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session,
		
        [System.String]
        [parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        $Type,

        [System.String]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Language = 'en',

        [Hashtable]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Headers
    )

    if($null -eq $session -or $session -eq '')
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,'Session'))
    }
    if($session.IsConnected -eq $false)
    {
        throw $([string]::Format($(Get-Message('MSG_INVALID_SESSION_OBJECT'))))
    }

    try
    {
		if(-not($null -eq $Type -or $Type -eq ''))
        {
            $first=".+"
            $versionPart="(\d)+"
            $typePattern="$first(\.$versionPart){3}$"
            if($type -notmatch $typePattern -and $type.Split('.').Count -ne 1)
            {
                throw $([string]::Format($(Get-Message('MSG_INVALID_TYPE')), $type))
            }
            
            $rootURI = $Session.RootUri
            $schemaURIList = 'rest/v1/schemas'
            $data = $null
            $data = Get-HPRESTDataRaw -Session $Session -Href $schemaURIList -Headers $Headers
            $hreflist = $data.links.member.href

            $foundFlag = $false
            $schemaHref = ''
            $prefix = $Type
            $schemaJSONLink = ''

        <#
        ##code in this comment block is rendered unnecessary due to page handling functionality added in Get-HPRESTDataRaw

        #$return = $false
        if($data.links.PSObject.Properties.Name.Contains('NextPage'))
        {
            if($data.links.NextPage.PSObject.Properties.Name.Contains('page'))
            {
                while($true)
                {
                    if($data.links.PSObject.Properties.Name.Contains('NextPage'))
                    {
                        if($data.links.NextPage.PSObject.Properties.Name.Contains('page'))
                        {
                                $newPage = $data.links.NextPage.page
                                $link = $data.links.self.href -replace 'page=(\d)*',"page=$newPage"
                                $data = Get-HPRESTDataRaw -Href $link -Session $Session
                                foreach($sch in $data.links.member.href)
                                {
                                    $hreflist += $sch
                                }
                        }
                        else
                        {
                            break
                        }
                    }
                    else
                    {
                        break
                    }
                }#end while
            }
        }
        #>
            foreach($href in $hreflist)
            {
                $typeFromHref = $href.SubString($href.LastIndexOf('/')+1)
                if($typeFromHref -eq $Type)
                {
                    $schemaHref = $href
                    $foundFlag = $true
                    break
                }
            }

            if($foundFlag -eq $false)
            {
                $prefix = Get-HPRESTTypePrefix -type $Type
                Write-Verbose "Using prefix - $prefix"
                foreach($href in $hreflist)
                {
                    $x = $href.Split('/')
                    if($x[$x.length-1] -eq $prefix)
                    {
                        $schemaHref = $href
                        $foundFlag = $true
                        break
                    }
                }
            }
            if($foundFlag -eq $true)
            {
                $schemaLinkObj = $null
                $schemaLinkObj = Get-HPRESTDataRaw -Href $schemaHref -Session $session -Headers $Headers
                $x = Compare-HPRESTSchemaVersion -DataType $Type -SchemaType $schemaLinkObj.schema
                if($x -eq $true)
                {
                    $schemaJSONHref = ($schemaLinkObj.Location|Where-Object {$_.language -eq $Language} | ForEach-Object {$_.Uri}).extref
                }
                return $schemaJSONHref
            }
            else
            {
                #Write-Error "Schema not found for $type"
                throw $([string]::Format($(Get-Message('MSG_SCHEMA_NOT_FOUND')), $type))
            }
        }
    }
    finally
    {
    }
}

function Get-HPRESTUriFromHref
{
<#
.SYNOPSIS
Gets entire URI path from provided Href and root URI in Session variable.

.DESCRIPTION
Gets entire URI from provided Href and root URI in Session variable. The URI is created using the protocol and host information from the session object and the value of Href parameter of the cmdlet.

.PARAMETER Session
Session PSObject returned by executing Connect-HPREST cmdlet. It must have RootURI to create the complete URI along with the Href parameter.

.PARAMETER Href
Specifies the value of Href of REST source for which the URI is being created. Href is of the format 'rest/v1/xxxx' where xxxx is the path to the resource. An example value of the Href parameter is 'rest/v1/systems/1'. The URI to which the HTTP web request is sent is created using the protocol and host information from the session object and the value of this Href parameter.

.INPUTS
System.String
You can pipe the Href parameter to Get-HPRESTUriFromHref.

.OUTPUTS
System.String
Get-HPRESTUriFromHref returns a string that has the complete URI derived from the Href and the RootUri from the session object.

.NOTES
See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.EXAMPLE
PS C:\> Get-HPRESTUriFromHref -Href rest/v1/systems/1 -Session $session
https://10.20.30.1/rest/v1/systems/1

This example shows the resultant REST URI obtained from the Href provided and the RootURI from the session object.

.LINK
http://www.hpe.com/servers/powershell

#>
    param
    (
	    [PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session,
		
        [System.String]
        [parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        $Href
    )

    if($null -eq $session -or $session -eq "")
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,"Session"))
    }
    if($session.IsConnected -eq $false)
    {
        throw $([string]::Format($(Get-Message('MSG_INVALID_SESSION_OBJECT'))))
    }
    
    $rootURI = $Session.RootUri
    if($null -eq $rootURI)
    {
         throw $([string]::Format($(Get-Message('MSG_PARAMETER_INVALID_TYPE')), $Session.GetType().Name, 'Session'))
    }

    $initUri = New-Object System.Uri -ArgumentList @([URI]$Session.RootUri)
    $baseUri = $initUri.Scheme + '://' + $initUri.Authority  # 'Authority' has the port number if provided by the user (along with the IP or hostname)
    return  (New-Object System.Uri -ArgumentList @([URI]$baseUri, $Href)).ToString()
}

function Invoke-HPRESTAction
{
<#
.SYNOPSIS
Executes HTTP POST method on the destination server.

.DESCRIPTION
Executes HTTP POST method on the desitination server with the data from Data parameter. Used for invoking an action like resetting the server.

.Parameter Session
Session PSObject returned by executing Connect-HPREST cmdlet. It must have RootURI to create the complete URI along with the Href parameter.

.PARAMETER Href
Specifies the value of Href of REST source where the HTTP POST request is sent. Href is of the format 'rest/v1/xxxx' where xxxx is the path to the resource. An example value of the Href parameter is 'rest/v1/systems/1'. The URI to which the HTTP web request is sent is created using the protocol and host information from the session object and the value of this Href parameter.

.PARAMETER Data
Data passed in name-value hashtable format that you have to POST.

.PARAMETER Headers
A list of Key-Value pairs in the form of a hashtable to be included in the HTTP web request.

.NOTES
- Edit-HPRESTData is for HTTP PUT method
- Invoke-HPRESTAction is for HTTP POST method
- Remove-HPRESTData is for HTTP DELETE method
- Set-HPRESTData is for HTTP PATCH method

See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.INPUTS
System.String
You can pipe the Href to Invoke-HPRESTAction. Href points to the location where the POST method is to be executed.

.OUTPUTS
System.Management.Automation.PSCustomObject
Invoke-HPRESTAction returns a PSObject that has message from the HTTP response. The response may be informational or may have a message requiring an action like server reset.

.EXAMPLE
PS C:\> $dataToPost = @{'Action'='Reset';'ResetType'='ForceRestart'}
PS C:\> Invoke-HPRESTAction -Href $sys -Data $dataToPost -Session $session

Messages                        Name                        Type                       
--------                        ----                        ----                       
{@{MessageID=Base.0.10.Success  Extended Error Information  ExtendedError.0.9.6        

This example shows Invoke-HPRESTData used to invoke a rest on the server. The 'ResetType' property is set to 'ForcedReset' and the output shows that reset was invoked successfully. The details of actions that can be performed at a particular Href are mentioned in the value for 'AvailableActions' field.

.EXAMPLE
$PS C:\> $accData = Get-HPRESTDataRaw -Href 'rest/v1/AccountService' -Session $session
    $accountHref = $accData.links.Accounts.href
    
$PS C:\> $priv = @{}
    $priv.Add('RemoteConsolePriv',$true)
    $priv.Add('iLOConfigPriv',$true)
    $priv.Add('VirtualMediaPriv',$false)
    $priv.Add('UserConfigPriv',$false)
    $priv.Add('VirtualPowerAndResetPriv',$true)

$PS C:\> $hp = @{}
    $hp.Add('LoginName',$newiLOLoginName)
    $hp.Add('Privileges',$priv)
    
$PS C:\> $oem = @{}
    $oem.Add('Hp',$hp)

$PS C:\> $user = @{}
    $user.Add('UserName',$newiLOUserName)
    $user.Add('Password',$newiLOPassword)
    $user.Add('Oem',$oem)

$PS C:\> $ret = Invoke-HPRESTAction -Href $accountHref -Data $user -Session $session

This example creates a user object and adds it to the Account href in AccountService.

.EXAMPLE
PS C:\> $settingToPost = @{}
PS C:\> $settingToPost.Add('Action','Reset')
PS C:\> Invoke-HPRESTAction -Href 'rest/v1/managers/1' -Data $settingToPost -Session $session

Messages                                Name                          Type
--------                                ----                          ----
{@{MessageID=iLO.0.10.ResetInProgress   Extended Error Information    ExtendedError.0.9.6

This example invokes a reset on the iLO for the server.

.EXAMPLE
PS C:\> $action = @{'Action'='ClearLog'}
PS C:\> Invoke-HPRESTAction -Href '/rest/v1/Systems/1/Logs/IML' -Data $action -Session $session

{"Messages":[{"MessageID":"iLO.0.10.EventLogCleared"}],"Name":"Extended Error Information","Type":"ExtendedError.0.9.6"}


This example clears the IML logs by creating a JSON object with action to clear the Integraged Management Logs.

.EXAMPLE
PS C:\> $action = @{'Action'='ClearLog'}
PS C:\> Invoke-HPRESTAction -Href '/rest/v1/Managers/1/Logs/IEL' -Data $action -Session $session

{"Messages":[{"MessageID":"iLO.0.10.EventLogCleared"}],"Name":"Extended Error Information","Type":"ExtendedError.0.9.6"}


This example clears the IEL logs by creating a JSON object with action to clear the iLO Event Logs.

.LINK
http://www.hpe.com/servers/powershell

#>
    param
    (
		[PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session,

        [System.String]
        [parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        $Href,

        [System.Object]
        [parameter(Mandatory=$false)]
        $Data, #one of the AllowedValue in capabilities

        [Hashtable]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Headers
    )
<#
    Edit-HPRESTData is for HTTP PUT method
    Invoke-HPRESTAction is for HTTP POST method
    Remove-HPRESTData is for HTTP DELETE method
    Set-HPRESTData is for HTTP PATCH method
#>
  
    if($null -eq $session -or $session -eq '')
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,'Session'))
    }
    if(($null -ne $Data) -and $Data.GetType().ToString() -notin @('System.Collections.Hashtable', 'System.String'))
    {
      
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_INVALID_TYPE')), $Data.GetType().ToString() ,'Data'))
    }
    if($session.IsConnected -eq $false)
    {
        throw $([string]::Format($(Get-Message('MSG_INVALID_SESSION_OBJECT'))))
    }

    try
    {
        $jsonStringData = ''
        if($null -eq $Data)
        {
            $jsonStringData = '{}'
        }
        else
        {
            if($Data.GetType().ToString() -eq 'System.Collections.Hashtable')
            {
                $jsonStringData = $Data | ConvertTo-Json -Depth 10
            }
            else
            {
                $jsonStringData = $Data
            }
        }
        
        $uri = Get-HPRESTUriFromHref -href $href -Session $Session
        $method = "POST"
        $payload = $jsonStringData
        $cmdletName = "Invoke-HPRESTAction"

        if($Session.DisableCertificateAuthentication.IsPresent -eq $false)
        {
            $webResponse = Invoke-HttpWebRequest -Uri $uri -Method $method -Payload $payload -CmdletName $cmdletName -Session $Session -Headers $Headers
        }
        else
        {
            $webResponse = Invoke-HttpWebRequest -Uri $uri -Method $method -Payload $payload -CmdletName $cmdletName -Session $Session -Headers $Headers -DisableCertificateAuthentication
        }

        try
        {
            $webStream = $webResponse.GetResponseStream()
            $respReader = New-Object System.IO.StreamReader($webStream)
            $resp = $respReader.ReadToEnd()
        
            $respReader.Close()
			$webStream.Close()    
			$webResponse.Close()

            return $resp|ConvertFrom-Json
        }
        finally
        {
			if ($null -ne $respReader -and $respReader -is [System.IDisposable]){$respReader.Dispose()}
            if ($null -ne $webStream -and $webStream -is [System.IDisposable]){$webStream.Dispose()}
			if ($null -ne $webResponse -and $webResponse -is [System.IDisposable]){$webResponse.Dispose()}
        }
    }
    finally
    {
    }
}

function Remove-HPRESTData
{
<#
.SYNOPSIS
Executes HTTP DELETE method on destination server.

.DESCRIPTION
Executes HTTP DELETE method on the desitination server at the location pointed to by Href parameter. Example of usage of this cmdlet is removing an iLO user account.

.PARAMETER Session
Session PSObject returned by executing Connect-HPREST cmdlet. It must have RootURI to create the complete URI along with the Href parameter. The root URI of the REST source and the X-Auth-Token session identifier required for executing this cmdlet is obtained from Session parameter.

.PARAMETER Href
Specifies the value of Href of REST source to be deleted. Href is of the format 'rest/v1/xxxx' where xxxx is the path to the resource. An example value of the Href parameter is 'rest/v1/systems/1'. The URI to which the HTTP web request is sent is created using the protocol and host information from the session object and the value of this Href parameter.

.PARAMETER Headers
A list of Key-Value pairs in the form of a hashtable to be included in the HTTP web request.

.NOTES
- Edit-HPRESTData is for HTTP PUT method
- Invoke-HPRESTAction is for HTTP POST method
- Remove-HPRESTData is for HTTP DELETE method
- Set-HPRESTData is for HTTP PATCH method

See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.INPUTS
System.String
You can pipe the Href to Remove-HPRESTData. Href points to the location where the DELETE method is to be executed.

.OUTPUTS
System.Management.Automation.PSCustomObject
Remove-HPRESTData returns a PSObject that has message from the HTTP response. The response may be informational or may have a message requiring an action like server reset.

.EXAMPLE
$users = Get-HPRESTDataRaw -Href rest/v1/accountService/accounts -Session $session
foreach($u in $users.Items)
{
    if($u.Username -eq 'user1')
    {
        Remove-HPRESTData -Href $u.links.self.href -Session $session
        break
    }
}


In this example, first, all accounts are retrieved in $users variable. This list is parsed one by one and when the 'user1' username is found, it is removed from the list of users.

.LINK
http://www.hpe.com/servers/powershell

#>
    param
    (
        [PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session,
		
        [System.String]
        [parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        $Href,

        [Hashtable]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Headers
    )
<#
    Edit-HPRESTData is for HTTP PUT method
    Invoke-HPRESTAction is for HTTP POST method
    Remove-HPRESTData is for HTTP DELETE method
    Set-HPRESTData is for HTTP PATCH method
#>
    if($null -eq $session -or $session -eq '')
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,'Session'))
    }
    if($session.IsConnected -eq $false)
    {
        throw $([string]::Format($(Get-Message('MSG_INVALID_SESSION_OBJECT'))))
    }
    
    try
    {
		$uri = Get-HPRESTUriFromHref -href $Href -Session $Session
        $method = "DELETE"
        $cmdletName = "Remove-HPRESTData"
		
		if($Session.DisableCertificateAuthentication.IsPresent -eq $false)
        {
			$webResponse = Invoke-HttpWebRequest -Uri $uri -Method $method -CmdletName $cmdletName -Session $Session -Headers $Headers
		}
		else
		{
			$webResponse = Invoke-HttpWebRequest -Uri $uri -Method $method -CmdletName $cmdletName -Session $Session -Headers $Headers -DisableCertificateAuthentication
		}

        try
        {
            $webStream = $webResponse.GetResponseStream()
            $respReader = New-Object System.IO.StreamReader($webStream)
            $resp = $respReader.ReadToEnd()

			$respReader.Close()
            $webStream.Close()
            $webResponse.Close()

            return $resp|ConvertFrom-Json
        }
        finally
        {
			if ($null -ne $respReader -and $respReader -is [System.IDisposable]){$respReader.Dispose()}
            if ($null -ne $webStream -and $webStream -is [System.IDisposable]){$webStream.Dispose()}
			if ($null -ne $webResponse -and $webResponse -is [System.IDisposable]){$webResponse.Dispose()}
        }
    }
    finally
    {
    }
}

function Set-HPRESTData
{
<#
.SYNOPSIS
Executes HTTP PATCH method on destination server.

.DESCRIPTION
Executes HTTP PATCH method at the specified Href. This cmdlet is used to update the value of an editable property in the REST source. A property name and the new value must be provided to modify a value. If the Property name is left blank or not specified, then the PATCH is done using the Value parameter on the Href. 

.PARAMETER Session
Session PSObject returned by executing Connect-HPREST cmdlet. It must have RootURI to create the complete URI along with the Href parameter. The root URI of the REST source and the X-Auth-Token session identifier required for executing this cmdlet is obtained from Session parameter.

.PARAMETER Href
Specifies the value of Href of REST source to be modified. Href is of the format 'rest/v1/xxxx' where xxxx is the path to the resource. An example value of the Href parameter is 'rest/v1/systems/1'. The URI to which the HTTP web request is sent is created using the protocol and host information from the session object and the value of this Href parameter.

.PARAMETER Setting
Specifies a hashtable using @{} which has the name of the setting to be modified and the corresponding value. Multiple properties can be modified using the same request by stating multiple name-value pairs in the same hashtable structure.
Example 1: $setting = @{'property1'= 'value1'}
Example 2: $setting = @{'property1'= 'value1'; 'property2'='value2'}
This can also be a complex(nested) hashtable. 
Example: $priv = @{}
          $priv.Add('RemoteConsolePriv',$true)
          $priv.Add('iLOConfigPriv',$true)
          $priv.Add('VirtualMediaPriv',$true)
          $priv.Add('UserConfigPriv',$true)
          $priv.Add('VirtualPowerAndResetPriv',$true)

          $hp = @{}
          $hp.Add('LoginName','user1')
          $hp.Add('Privileges',$priv)
    
          $oem = @{}
          $oem.Add('Hp',$hp)

          $user = @{}
          $user.Add('UserName','adminUser')
          $user.Add('Password','password123')
          $user.Add('Oem',$oem)

This example shows a complex $user object that is used as 'Setting' parameter value to update properties/privileges of a user. This is passed to the Href of the user whose details are to be updated.

.PARAMETER Headers
A list of Key-Value pairs in the form of a hashtable to be included in the HTTP web request.

.NOTES
- Edit-HPRESTData is for HTTP PUT method
- Invoke-HPRESTAction is for HTTP POST method
- Remove-HPRESTData is for HTTP DELETE method
- Set-HPRESTData is for HTTP PATCH method

If user tries to PATCH data to an Href that does not allow PATCH operation, then the code automatically searches for 'Settings' href in the 'links' field and performs a PATCH operation on the 'Settings' href. If 'Settings' href is not found in 'links' field of the data and PATCH is not allowed on the provided href, it results in an error.

See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.INPUTS
System.String
You can pipe the Href to Set-HPRESTData. Href points to the location where the PATCH method is to be executed.

.OUTPUTS
System.Management.Automation.PSCustomObject
Set-HPRESTData returns a PSObject that has message from the HTTP response. The response may be informational or may have a message requiring an action like server reset.

.EXAMPLE
PS C:\> $setting = @{'AdminName' = 'TestAdmin'}
PS C:\> $ret = Set-HPRESTData -Href rest/v1/systems/1/bios/settings -Setting $setting -Session $session
PS C:\> $ret

Messages                                   Name                        Type                       
--------                                   ----                        ----                       
{@{MessageID=iLO.0.10.SystemResetRequired  Extended Error Information  ExtendedError.0.9.6        

This example shows updating the 'AdminName' field in bios setting to set the value to 'TestAdmin'


.EXAMPLE
PS C:\> $LoginNameToModify = 'TimHorton'
PS C:\> $accounts = Get-HPRESTDataRaw -href 'rest/v1/AccountService/Accounts' -Session $session
PS C:\> $reqAccount = $accounts.Items | ?{$_.Username -eq $LoginNameToModify}
PS C:\> $priv = @{}
    $priv.Add('VirtualMediaPriv',$false)
    $priv.Add('UserConfigPriv',$false)
            
    $hp = @{}
    $hp.Add('Privileges',$priv)
    
    $oem = @{}
    $oem.Add('Hp',$hp)

    $user = @{}
    $user.Add('Oem',$oem)

PS C:\> $ret = Set-HPRESTData -Href $reqAccount.links.self.href -Settnig $user -Session $session
PS C:\> $ret

Messages                                  Name                        Type                       
--------                                  ----                        ----                       
{@{MessageID=Base.0.10.AccountModified}}  Extended Error Information  ExtendedError.0.9.6

This example shows modification of user privilege for a user. First the href of the user 'TimHorton' is seacrched from Accounts href. Then user object is created with the required privilege change. This object is then used as the setting parameter value for Set-HPRESTData cmdlet.

.LINK
http://www.hpe.com/servers/powershell

#>
    param
    (
	    [PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session,

        [System.String]
        [parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        $Href,

        [System.Object]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Setting,

        [Hashtable]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Headers
    )
<#
    Edit-HPRESTData is for HTTP PUT method
    Invoke-HPRESTAction is for HTTP POST method
    Remove-HPRESTData is for HTTP DELETE method
    Set-HPRESTData is for HTTP PATCH method
#>
  
   if($null -eq $session -or $session -eq '')
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,'Session'))
    }
    if(($null -ne $Setting) -and $Setting.GetType().ToString() -notin @('System.Collections.Hashtable', 'System.String'))
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_INVALID_TYPE')), $Setting.GetType().ToString() ,'Setting'))
    }
    if($session.IsConnected -eq $false)
    {
        throw $([string]::Format($(Get-Message('MSG_INVALID_SESSION_OBJECT'))))
    }
    
    try
    {
		$Href = Get-FinalHrefForPutPatch -Href $Href -CmdletName 'Set-HPRESTData' -MethodToExecute 'PATCH' -Session $Session -Headers $Headers

        $jsonStringData = ''
        if($null -eq $Setting )
        {
            $jsonStringData = '{}'
        }
        else
        {
            if($Setting.GetType().ToString() -eq 'System.Collections.Hashtable')
            {
                $jsonStringData = $Setting | ConvertTo-Json -Depth 10
            }
            else
            {
                $jsonStringData = $Setting
            }
        }
    
        $uri = Get-HPRESTUriFromHref -Href $Href -Session $Session
        $method = "PATCH"
        $payload = $jsonStringData
        $cmdletName = "Set-HPRESTData"
		
		if($Session.DisableCertificateAuthentication.IsPresent -eq $false)
        {
			$webResponse = Invoke-HttpWebRequest -Uri $uri -Method $method -Payload $payload -CmdletName $cmdletName -Headers $Headers -Session $Session
		}
		else
		{
			$webResponse = Invoke-HttpWebRequest -Uri $uri -Method $method -Payload $payload -CmdletName $cmdletName -Headers $Headers -Session $Session -DisableCertificateAuthentication
		}

        try
        {
            $webStream = $webResponse.GetResponseStream()
            $respReader = New-Object System.IO.StreamReader($webStream)
            $resp = $respReader.ReadToEnd()
        
			$respReader.Close() 
            $webStream.Close()
			$webResponse.Close()

            return $resp|ConvertFrom-Json
        } 
        finally
        {
		    if (($null -ne $respReader) -and ($respReader -is [System.IDisposable])){$respReader.Dispose()}
            if (($null -ne $webStream) -and ($webStream -is [System.IDisposable])){$webStream.Dispose()}
			if (($null -ne $webResponse) -and ($webResponse -is [System.IDisposable])){$webResponse.Dispose()}
        }
    }
    finally
    {
    }
}

Export-ModuleMember -Function Connect-HPREST, Disconnect-HPREST, Edit-HPRESTData, Find-HPREST, Get-HPRESTData, Get-HPRESTDataRaw, Get-HPRESTDir, Format-HPRESTDir, Get-HPRESTIndex, Get-HPRESTModuleVersion, Get-HPRESTMessage, Get-HPRESTHttpData, Get-HPRESTSchema, Get-HPRESTSchemaExtref, Get-HPRESTUriFromHref, Invoke-HPRESTAction, Remove-HPRESTData, Set-HPRESTData

# SIG # Begin signature block
# MIIkYQYJKoZIhvcNAQcCoIIkUjCCJE4CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCn1oh0CfiNCxOd
# yrguv+hewgqQpFUV7yhAkEDpb3d256CCHtUwggQUMIIC/KADAgECAgsEAAAAAAEv
# TuFS1zANBgkqhkiG9w0BAQUFADBXMQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xv
# YmFsU2lnbiBudi1zYTEQMA4GA1UECxMHUm9vdCBDQTEbMBkGA1UEAxMSR2xvYmFs
# U2lnbiBSb290IENBMB4XDTExMDQxMzEwMDAwMFoXDTI4MDEyODEyMDAwMFowUjEL
# MAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExKDAmBgNVBAMT
# H0dsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBIC0gRzIwggEiMA0GCSqGSIb3DQEB
# AQUAA4IBDwAwggEKAoIBAQCU72X4tVefoFMNNAbrCR+3Rxhqy/Bb5P8npTTR94ka
# v56xzRJBbmbUgaCFi2RaRi+ZoI13seK8XN0i12pn0LvoynTei08NsFLlkFvrRw7x
# 55+cC5BlPheWMEVybTmhFzbKuaCMG08IGfaBMa1hFqRi5rRAnsP8+5X2+7UulYGY
# 4O/F69gCWXh396rjUmtQkSnF/PfNk2XSYGEi8gb7Mt0WUfoO/Yow8BcJp7vzBK6r
# kOds33qp9O/EYidfb5ltOHSqEYva38cUTOmFsuzCfUomj+dWuqbgz5JTgHT0A+xo
# smC8hCAAgxuh7rR0BcEpjmLQR7H68FPMGPkuO/lwfrQlAgMBAAGjgeUwgeIwDgYD
# VR0PAQH/BAQDAgEGMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYEFEbYPv/c
# 477/g+b0hZuw3WrWFKnBMEcGA1UdIARAMD4wPAYEVR0gADA0MDIGCCsGAQUFBwIB
# FiZodHRwczovL3d3dy5nbG9iYWxzaWduLmNvbS9yZXBvc2l0b3J5LzAzBgNVHR8E
# LDAqMCigJqAkhiJodHRwOi8vY3JsLmdsb2JhbHNpZ24ubmV0L3Jvb3QuY3JsMB8G
# A1UdIwQYMBaAFGB7ZhpFDZfKiVAvfQTNNKj//P1LMA0GCSqGSIb3DQEBBQUAA4IB
# AQBOXlaQHka02Ukx87sXOSgbwhbd/UHcCQUEm2+yoprWmS5AmQBVteo/pSB204Y0
# 1BfMVTrHgu7vqLq82AafFVDfzRZ7UjoC1xka/a/weFzgS8UY3zokHtqsuKlYBAIH
# MNuwEl7+Mb7wBEj08HD4Ol5Wg889+w289MXtl5251NulJ4TjOJuLpzWGRCCkO22k
# aguhg/0o69rvKPbMiF37CjsAq+Ah6+IvNWwPjjRFl+ui95kzNX7Lmoq7RU3nP5/C
# 2Yr6ZbJux35l/+iS4SwxovewJzZIjyZvO+5Ndh95w+V/ljW8LQ7MAbCOf/9RgICn
# ktSzREZkjIdPFmMHMUtjsN/zMIIEnzCCA4egAwIBAgISESHWmadklz7x+EJ+6RnM
# U0EUMA0GCSqGSIb3DQEBBQUAMFIxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9i
# YWxTaWduIG52LXNhMSgwJgYDVQQDEx9HbG9iYWxTaWduIFRpbWVzdGFtcGluZyBD
# QSAtIEcyMB4XDTE2MDUyNDAwMDAwMFoXDTI3MDYyNDAwMDAwMFowYDELMAkGA1UE
# BhMCU0cxHzAdBgNVBAoTFkdNTyBHbG9iYWxTaWduIFB0ZSBMdGQxMDAuBgNVBAMT
# J0dsb2JhbFNpZ24gVFNBIGZvciBNUyBBdXRoZW50aWNvZGUgLSBHMjCCASIwDQYJ
# KoZIhvcNAQEBBQADggEPADCCAQoCggEBALAXrqLTtgQwVh5YD7HtVaTWVMvY9nM6
# 7F1eqyX9NqX6hMNhQMVGtVlSO0KiLl8TYhCpW+Zz1pIlsX0j4wazhzoOQ/DXAIlT
# ohExUihuXUByPPIJd6dJkpfUbJCgdqf9uNyznfIHYCxPWJgAa9MVVOD63f+ALF8Y
# ppj/1KvsoUVZsi5vYl3g2Rmsi1ecqCYr2RelENJHCBpwLDOLf2iAKrWhXWvdjQIC
# KQOqfDe7uylOPVOTs6b6j9JYkxVMuS2rgKOjJfuv9whksHpED1wQ119hN6pOa9PS
# UyWdgnP6LPlysKkZOSpQ+qnQPDrK6Fvv9V9R9PkK2Zc13mqF5iMEQq8CAwEAAaOC
# AV8wggFbMA4GA1UdDwEB/wQEAwIHgDBMBgNVHSAERTBDMEEGCSsGAQQBoDIBHjA0
# MDIGCCsGAQUFBwIBFiZodHRwczovL3d3dy5nbG9iYWxzaWduLmNvbS9yZXBvc2l0
# b3J5LzAJBgNVHRMEAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMEIGA1UdHwQ7
# MDkwN6A1oDOGMWh0dHA6Ly9jcmwuZ2xvYmFsc2lnbi5jb20vZ3MvZ3N0aW1lc3Rh
# bXBpbmdnMi5jcmwwVAYIKwYBBQUHAQEESDBGMEQGCCsGAQUFBzAChjhodHRwOi8v
# c2VjdXJlLmdsb2JhbHNpZ24uY29tL2NhY2VydC9nc3RpbWVzdGFtcGluZ2cyLmNy
# dDAdBgNVHQ4EFgQU1KKESjhaGH+6TzBQvZ3VeofWCfcwHwYDVR0jBBgwFoAURtg+
# /9zjvv+D5vSFm7DdatYUqcEwDQYJKoZIhvcNAQEFBQADggEBAI+pGpFtBKY3IA6D
# lt4j02tuH27dZD1oISK1+Ec2aY7hpUXHJKIitykJzFRarsa8zWOOsz1QSOW0zK7N
# ko2eKIsTShGqvaPv07I2/LShcr9tl2N5jES8cC9+87zdglOrGvbr+hyXvLY3nKQc
# MLyrvC1HNt+SIAPoccZY9nUFmjTwC1lagkQ0qoDkL4T2R12WybbKyp23prrkUNPU
# N7i6IA7Q05IqW8RZu6Ft2zzORJ3BOCqt4429zQl3GhC+ZwoCNmSIubMbJu7nnmDE
# Rqi8YTNsz065nLlq8J83/rU9T5rTTf/eII5Ol6b9nwm8TcoYdsmwTYVQ8oDSHQb1
# WAQHsRgwggVMMIIDNKADAgECAhMzAAAANdjVWVsGcUErAAAAAAA1MA0GCSqGSIb3
# DQEBBQUAMH8xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAn
# BgNVBAMTIE1pY3Jvc29mdCBDb2RlIFZlcmlmaWNhdGlvbiBSb290MB4XDTEzMDgx
# NTIwMjYzMFoXDTIzMDgxNTIwMzYzMFowbzELMAkGA1UEBhMCU0UxFDASBgNVBAoT
# C0FkZFRydXN0IEFCMSYwJAYDVQQLEx1BZGRUcnVzdCBFeHRlcm5hbCBUVFAgTmV0
# d29yazEiMCAGA1UEAxMZQWRkVHJ1c3QgRXh0ZXJuYWwgQ0EgUm9vdDCCASIwDQYJ
# KoZIhvcNAQEBBQADggEPADCCAQoCggEBALf3GjPm8gAELTngTlvtH7xsD821+iO2
# zt6bETOXpClMfZOfvUq8k+0DGuOPz+VtUFrWlymUWoCwSXrbLpX9uMq/NzgtHj6R
# Qa1wVsfwTz/oMp50ysiQVOnGXw94nZpAPA6sYapeFI+eh6FqUNzXmk6vBbOmcZSc
# cbNQYArHE504B4YCqOmoaSYYkKtMsE8jqzpPhNjfzp/haW+710LXa0Tkx63ubUFf
# clpxCDezeWWkWaCUN/cALw3CknLa0Dhy2xSoRcRdKn23tNbE7qzNE0S3ySvdQwAl
# +mG5aWpYIxG3pzOPVnVZ9c0p10a3CitlttNCbxWyuHv77+ldU9U0WicCAwEAAaOB
# 0DCBzTATBgNVHSUEDDAKBggrBgEFBQcDAzASBgNVHRMBAf8ECDAGAQH/AgECMB0G
# A1UdDgQWBBStvZh6NLQm9/rEJlTvA73gJMtUGjALBgNVHQ8EBAMCAYYwHwYDVR0j
# BBgwFoAUYvsKIVt/Q24R2glUUGv10pZx8Z4wVQYDVR0fBE4wTDBKoEigRoZEaHR0
# cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljcm9zb2Z0
# Q29kZVZlcmlmUm9vdC5jcmwwDQYJKoZIhvcNAQEFBQADggIBADYrovLhMx/kk/fy
# aYXGZA7Jm2Mv5HA3mP2U7HvP+KFCRvntak6NNGk2BVV6HrutjJlClgbpJagmhL7B
# vxapfKpbBLf90cD0Ar4o7fV3x5v+OvbowXvTgqv6FE7PK8/l1bVIQLGjj4OLrSsl
# U6umNM7yQ/dPLOndHk5atrroOxCZJAC8UP149uUjqImUk/e3QTA3Sle35kTZyd+Z
# BapE/HSvgmTMB8sBtgnDLuPoMqe0n0F4x6GENlRi8uwVCsjq0IT48eBr9FYSX5Xg
# /N23dpP+KUol6QQA8bQRDsmEntsXffUepY42KRk6bWxGS9ercCQojQWj2dUk8vig
# 0TyCOdSogg5pOoEJ/Abwx1kzhDaTBkGRIywipacBK1C0KK7bRrBZG4azm4foSU45
# C20U30wDMB4fX3Su9VtZA1PsmBbg0GI1dRtIuH0T5XpIuHdSpAeYJTsGm3pOam9E
# hk8UTyd5Jz1Qc0FMnEE+3SkMc7HH+x92DBdlBOvSUBCSQUns5AZ9NhVEb4m/aX35
# TUDBOpi2oH4x0rWuyvtT1T9Qhs1ekzttXXyaPz/3qSVYhN0RSQCix8ieN913jm1x
# i+BbgTRdVLrM9ZNHiG3n71viKOSAG0DkDyrRfyMVZVqsmZRDP0ZVJtbE+oiV4pGa
# oy0Lhd6sjOD5Z3CfcXkCMfdhoinEMIIFajCCBFKgAwIBAgIRANxk5SdQPTPwcDM3
# MrzN2JAwDQYJKoZIhvcNAQELBQAwfTELMAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdy
# ZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEaMBgGA1UEChMRQ09N
# T0RPIENBIExpbWl0ZWQxIzAhBgNVBAMTGkNPTU9ETyBSU0EgQ29kZSBTaWduaW5n
# IENBMB4XDTE3MDgxNDAwMDAwMFoXDTE4MDgxNDIzNTk1OVowgdIxCzAJBgNVBAYT
# AlVTMQ4wDAYDVQQRDAU5NDMwNDELMAkGA1UECAwCQ0ExEjAQBgNVBAcMCVBhbG8g
# QWx0bzEcMBoGA1UECQwTMzAwMCBIYW5vdmVyIFN0cmVldDErMCkGA1UECgwiSGV3
# bGV0dCBQYWNrYXJkIEVudGVycHJpc2UgQ29tcGFueTEaMBgGA1UECwwRSFAgQ3li
# ZXIgU2VjdXJpdHkxKzApBgNVBAMMIkhld2xldHQgUGFja2FyZCBFbnRlcnByaXNl
# IENvbXBhbnkwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDFeprDB20N
# R6CpKiAGpGZdM05iXBGHcljM+7xBih7bacPYQ5nowqVHmFv/QWlLtpiNclv1wtxd
# hnjG9CJlKNWHo2/ObT2z1U3PI/J0xq5S0PpBxo3sIYdeDkrQQ1xZ6A9HTvVUmCNJ
# dMzUScQc+1wcL1YSKgsMLih5exqlPN93xiyrQjv6Zjneg6aogaEnoauw6XLdYO9M
# Ei5IzZs0CaWhQRnQfIKaPBD6i6pyfixr8DNMfNzuKOtH/rokYD5//04AuAUNS6i1
# nMscJcz0jcfpjp9k5wyF6yFHS51UhRaN29oFoN+11k9rvlGgCCHgtbzRoqOhpYID
# gGbaQdRcNYsVAgMBAAGjggGNMIIBiTAfBgNVHSMEGDAWgBQpkWD/ik366/mmarjP
# +eZLvUnOEjAdBgNVHQ4EFgQUWPfI3+QB9fYXhr/dYp0OEJBnrV4wDgYDVR0PAQH/
# BAQDAgeAMAwGA1UdEwEB/wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUHAwMwEQYJYIZI
# AYb4QgEBBAQDAgQQMEYGA1UdIAQ/MD0wOwYMKwYBBAGyMQECAQMCMCswKQYIKwYB
# BQUHAgEWHWh0dHBzOi8vc2VjdXJlLmNvbW9kby5uZXQvQ1BTMEMGA1UdHwQ8MDow
# OKA2oDSGMmh0dHA6Ly9jcmwuY29tb2RvY2EuY29tL0NPTU9ET1JTQUNvZGVTaWdu
# aW5nQ0EuY3JsMHQGCCsGAQUFBwEBBGgwZjA+BggrBgEFBQcwAoYyaHR0cDovL2Ny
# dC5jb21vZG9jYS5jb20vQ09NT0RPUlNBQ29kZVNpZ25pbmdDQS5jcnQwJAYIKwYB
# BQUHMAGGGGh0dHA6Ly9vY3NwLmNvbW9kb2NhLmNvbTANBgkqhkiG9w0BAQsFAAOC
# AQEAEiVTOJ5DIimmshtdmYtH7D4556e4JgTBUC9aJJ20uk3Bh/YMB1iUHGJsAx4V
# JtJVNuVbbOtj7UpGsJ0rC0tS3Nq78QbL+L7qmQO/tjSlKBGOAHOCs2fYUBBH7UTp
# i6SYEMLec+AjLA6nel/H8BosdtJbDl41YLi2Qlz/CKChDoPwZ0n5cScLFKpTAljx
# uYfbjyufLEfIFn38FjeM6/W2/wJGkUvLuC9V7M/bxoV6pkAJgQnoUkKTlucSQK50
# VFNCoMmdJE/EQC8YHDrP0XosMT51cQy7xEcpvYcugZq7rjprHzB4QK2+iA+F30c6
# PKq6c4ZQ5r3MiMAiFUbjx90U3zCCBXQwggRcoAMCAQICECdm7lbrSfOOq9dwovyE
# 3iIwDQYJKoZIhvcNAQEMBQAwbzELMAkGA1UEBhMCU0UxFDASBgNVBAoTC0FkZFRy
# dXN0IEFCMSYwJAYDVQQLEx1BZGRUcnVzdCBFeHRlcm5hbCBUVFAgTmV0d29yazEi
# MCAGA1UEAxMZQWRkVHJ1c3QgRXh0ZXJuYWwgQ0EgUm9vdDAeFw0wMDA1MzAxMDQ4
# MzhaFw0yMDA1MzAxMDQ4MzhaMIGFMQswCQYDVQQGEwJHQjEbMBkGA1UECBMSR3Jl
# YXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxmb3JkMRowGAYDVQQKExFDT01P
# RE8gQ0EgTGltaXRlZDErMCkGA1UEAxMiQ09NT0RPIFJTQSBDZXJ0aWZpY2F0aW9u
# IEF1dGhvcml0eTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAJHoVJLS
# ClaxrA0k3cXPRGd0mSs3o30jcABxvFPfxPoqEo9LfxBWvZ9wcrdhf8lLDxenPeOw
# BGHu/xGXx/SGPgr6Plz5k+Y0etkUa+ecs4Wggnp2r3GQ1+z9DfqcbPrfsIL0FH75
# vsSmL09/mX+1/GdDcr0MANaJ62ss0+2PmBwUq37l42782KjkkiTaQ2tiuFX96sG8
# bLaL8w6NmuSbbGmZ+HhIMEXVreENPEVg/DKWUSe8Z8PKLrZr6kbHxyCgsR9l3kgI
# uqROqfKDRjeE6+jMgUhDZ05yKptcvUwbKIpcInu0q5jZ7uBRg8MJRk5tPpn6lRfa
# fDNXQTyNUe0LtlyvLGMa31fIP7zpXcSbr0WZ4qNaJLS6qVY9z2+q/0lYvvCo//S4
# rek3+7q49As6+ehDQh6J2ITLE/HZu+GJYLiMKFasFB2cCudx688O3T2plqFIvTz3
# r7UNIkzAEYHsVjv206LiW7eyBCJSlYCTaeiOTGXxkQMtcHQC6otnFSlpUgK7199Q
# alVGv6CjKGF/cNDDoqosIapHziicBkV2v4IYJ7TVrrTLUOZr9EyGcTDppt8WhuDY
# /0Dd+9BCiH+jMzouXB5BEYFjzhhxayvspoq3MVw6akfgw3lZ1iAar/JqmKpyvFdK
# 0kuduxD8sExB5e0dPV4onZzMv7NR2qdH5YRTAgMBAAGjgfQwgfEwHwYDVR0jBBgw
# FoAUrb2YejS0Jvf6xCZU7wO94CTLVBowHQYDVR0OBBYEFLuvfgI9+qbxPISOre44
# mOzZMjLUMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MBEGA1UdIAQK
# MAgwBgYEVR0gADBEBgNVHR8EPTA7MDmgN6A1hjNodHRwOi8vY3JsLnVzZXJ0cnVz
# dC5jb20vQWRkVHJ1c3RFeHRlcm5hbENBUm9vdC5jcmwwNQYIKwYBBQUHAQEEKTAn
# MCUGCCsGAQUFBzABhhlodHRwOi8vb2NzcC51c2VydHJ1c3QuY29tMA0GCSqGSIb3
# DQEBDAUAA4IBAQBkv4PxX5qF0M24oSlXDeha99HpPvJ2BG7xUnC7Hjz/TQ10asyB
# giXTw6AqXUz1uouhbcRUCXXH4ycOXYR5N0ATd/W0rBzQO6sXEtbvNBh+K+l506tX
# RQyvKPrQ2+VQlYi734VXaX2S2FLKc4G/HPPmuG5mEQWzHpQtf5GVklnxTM6jkXFM
# fEcMOwsZ9qGxbIY+XKrELoLL+QeWukhNkPKUyKlzousGeyOd3qLzTVWfemFFmBho
# x15AayP1eXrvjLVri7dvRvR78T1LBNiTgFla4EEkHbKPFWBYR9vvbkb9FfXZX5qz
# 29i45ECzzZc5roW7HY683Ieb0abv8TtvEDhvMIIF4DCCA8igAwIBAgIQLnyHzA6T
# SlL+lP0ct800rzANBgkqhkiG9w0BAQwFADCBhTELMAkGA1UEBhMCR0IxGzAZBgNV
# BAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEaMBgGA1UE
# ChMRQ09NT0RPIENBIExpbWl0ZWQxKzApBgNVBAMTIkNPTU9ETyBSU0EgQ2VydGlm
# aWNhdGlvbiBBdXRob3JpdHkwHhcNMTMwNTA5MDAwMDAwWhcNMjgwNTA4MjM1OTU5
# WjB9MQswCQYDVQQGEwJHQjEbMBkGA1UECBMSR3JlYXRlciBNYW5jaGVzdGVyMRAw
# DgYDVQQHEwdTYWxmb3JkMRowGAYDVQQKExFDT01PRE8gQ0EgTGltaXRlZDEjMCEG
# A1UEAxMaQ09NT0RPIFJTQSBDb2RlIFNpZ25pbmcgQ0EwggEiMA0GCSqGSIb3DQEB
# AQUAA4IBDwAwggEKAoIBAQCmmJBjd5E0f4rR3elnMRHrzB79MR2zuWJXP5O8W+Of
# HiQyESdrvFGRp8+eniWzX4GoGA8dHiAwDvthe4YJs+P9omidHCydv3Lj5HWg5TUj
# jsmK7hoMZMfYQqF7tVIDSzqwjiNLS2PgIpQ3e9V5kAoUGFEs5v7BEvAcP2FhCoyi
# 3PbDMKrNKBh1SMF5WgjNu4xVjPfUdpA6M0ZQc5hc9IVKaw+A3V7Wvf2pL8Al9fl4
# 141fEMJEVTyQPDFGy3CuB6kK46/BAW+QGiPiXzjbxghdR7ODQfAuADcUuRKqeZJS
# zYcPe9hiKaR+ML0btYxytEjy4+gh+V5MYnmLAgaff9ULAgMBAAGjggFRMIIBTTAf
# BgNVHSMEGDAWgBS7r34CPfqm8TyEjq3uOJjs2TIy1DAdBgNVHQ4EFgQUKZFg/4pN
# +uv5pmq4z/nmS71JzhIwDgYDVR0PAQH/BAQDAgGGMBIGA1UdEwEB/wQIMAYBAf8C
# AQAwEwYDVR0lBAwwCgYIKwYBBQUHAwMwEQYDVR0gBAowCDAGBgRVHSAAMEwGA1Ud
# HwRFMEMwQaA/oD2GO2h0dHA6Ly9jcmwuY29tb2RvY2EuY29tL0NPTU9ET1JTQUNl
# cnRpZmljYXRpb25BdXRob3JpdHkuY3JsMHEGCCsGAQUFBwEBBGUwYzA7BggrBgEF
# BQcwAoYvaHR0cDovL2NydC5jb21vZG9jYS5jb20vQ09NT0RPUlNBQWRkVHJ1c3RD
# QS5jcnQwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmNvbW9kb2NhLmNvbTANBgkq
# hkiG9w0BAQwFAAOCAgEAAj8COcPu+Mo7id4MbU2x8U6ST6/COCwEzMVjEasJY6+r
# otcCP8xvGcM91hoIlP8l2KmIpysQGuCbsQciGlEcOtTh6Qm/5iR0rx57FjFuI+9U
# US1SAuJ1CAVM8bdR4VEAxof2bO4QRHZXavHfWGshqknUfDdOvf+2dVRAGDZXZxHN
# TwLk/vPa/HUX2+y392UJI0kfQ1eD6n4gd2HITfK7ZU2o94VFB696aSdlkClAi997
# OlE5jKgfcHmtbUIgos8MbAOMTM1zB5TnWo46BLqioXwfy2M6FafUFRunUkcyqfS/
# ZEfRqh9TTjIwc8Jvt3iCnVz/RrtrIh2IC/gbqjSm/Iz13X9ljIwxVzHQNuxHoc/L
# i6jvHBhYxQZ3ykubUa9MCEp6j+KjUuKOjswm5LLY5TjCqO3GgZw1a6lYYUoKl7RL
# QrZVnb6Z53BtWfhtKgx/GWBfDJqIbDCsUgmQFhv/K53b0CDKieoofjKOGd97SDMe
# 12X4rsn4gxSTdn1k0I7OvjV9/3IxTZ+evR5sL6iPDAZQ+4wns3bJ9ObXwzTijIch
# hmH+v1V04SF3AwpobLvkyanmz1kl63zsRQ55ZmjoIs2475iFTZYRPAmK0H+8KCgT
# +2rKVI2SXM3CZZgGns5IW9S1N5NGQXwH3c/6Q++6Z2H/fUnguzB9XIDj5hY5S6cx
# ggTiMIIE3gIBATCBkjB9MQswCQYDVQQGEwJHQjEbMBkGA1UECBMSR3JlYXRlciBN
# YW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxmb3JkMRowGAYDVQQKExFDT01PRE8gQ0Eg
# TGltaXRlZDEjMCEGA1UEAxMaQ09NT0RPIFJTQSBDb2RlIFNpZ25pbmcgQ0ECEQDc
# ZOUnUD0z8HAzNzK8zdiQMA0GCWCGSAFlAwQCAQUAoHwwEAYKKwYBBAGCNwIBDDEC
# MAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwG
# CisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEICLk22kWIwzu62liJnFAlEDGYHI5
# PLUvTJcvB+v7beMVMA0GCSqGSIb3DQEBAQUABIIBAIoWmHz/UNd30i+nSj0dygYJ
# vPWqEkERgU/yl4o1rVt5A0W+h/5UGJyoDCN3WZCjlmvEnbMbSDOaTP9XsaeH2fVI
# fPe+cOFVFzuhFalyfrgU2gMn+AfS8379uwMEfOEqT5Cf8WZGlnuNUGI2BgHjekKa
# Mkew+MK41IuSv//qJqGuOoC5DPAaT04ISaEVMJ47Z9FCrYWx5FWBc5+Sfu/zwcxZ
# D/s/mMx2gi5w7wMltWk9VtzhaJ0AQdHr/KgS9mAMb6nP9/aH5a5f0dvX1P6PnooX
# oDLb6dRXkCz0l0dW2N7lJ/39awuo8jDga4aabJGcHq9c7qSDHW7hKA554VndjSeh
# ggKiMIICngYJKoZIhvcNAQkGMYICjzCCAosCAQEwaDBSMQswCQYDVQQGEwJCRTEZ
# MBcGA1UEChMQR2xvYmFsU2lnbiBudi1zYTEoMCYGA1UEAxMfR2xvYmFsU2lnbiBU
# aW1lc3RhbXBpbmcgQ0EgLSBHMgISESHWmadklz7x+EJ+6RnMU0EUMAkGBSsOAwIa
# BQCggf0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcN
# MTcxMDI2MDQzNzI3WjAjBgkqhkiG9w0BCQQxFgQUFVL1kJp0PoifxhVzkJ+LXHqz
# bVswgZ0GCyqGSIb3DQEJEAIMMYGNMIGKMIGHMIGEBBRjuC+rYfWDkJaVBQsAJJxQ
# KTPseTBsMFakVDBSMQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xvYmFsU2lnbiBu
# di1zYTEoMCYGA1UEAxMfR2xvYmFsU2lnbiBUaW1lc3RhbXBpbmcgQ0EgLSBHMgIS
# ESHWmadklz7x+EJ+6RnMU0EUMA0GCSqGSIb3DQEBAQUABIIBAI8atU5HZ4iCFoN5
# VfaXf5xmJTxhXRdw4WdDI5Yrn+lNiqQoo6URq4G/nc2zirTg9OelbbohNnHz6WES
# BhTK4ONJQRXNZkZhdIleOPBh67ImvKABl0FS7+yjRnEYrHUAERFfqLLL/J3NlsqU
# ECu0fxQm9wNucX5OHOUhJEJDrqWGvjC6ZpZff96yHAJf0e6ruPviPZT34Ul5gfJ3
# g1J68CTeNWE/mN0fDoVUJ48+8bYfZ4hO8Fcx24H1ueBoorVz0RgD3/BGLpljVsAt
# 7fYgZ4pzFCNw5eoSao8ZNPwEJclkcWUXJR4Rwa5OdjKyUBZ43zUlmaRcRua5I6uE
# jUZN5Ro=
# SIG # End signature block
