#Region './Private/Get-RedfishCollectionMember.ps1' -1

function Get-RedfishCollectionMember {
    <#
.SYNOPSIS
    Gets all members from a Redfish collection efficiently.

.DESCRIPTION
    Fetches all members from a Redfish collection (e.g., Systems, Chassis) using
    parallel batch requests for optimal performance.

.PARAMETER Session
    The Redfish session object.

.PARAMETER CollectionUri
    The URI of the collection to fetch (e.g., '/redfish/v1/Systems').

.PARAMETER MaxConcurrency
    Maximum number of concurrent requests when fetching members. Default is 10.

.EXAMPLE
    $systems = Get-RedfishCollectionMember -Session $session -CollectionUri '/redfish/v1/Systems'

.EXAMPLE
    $chassis = Get-RedfishCollectionMember -Session $session -CollectionUri '/redfish/v1/Chassis' -MaxConcurrency 20
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]
        $Session,

        [Parameter(Mandatory)]
        [string]
        $CollectionUri,

        [Parameter()]
        [ValidateRange(1, 50)]
        [int]
        $MaxConcurrency = 10
    )

    process {
        Write-Verbose "Fetching collection: $CollectionUri"

        # Get the collection
        $collection = Invoke-RedfishRequest -Session $Session -Uri $CollectionUri

        if (-not $collection.Members) {
            Write-Verbose 'Collection has no members'
            return [PSCustomObject[]]@()
        }

        Write-Verbose "Collection has $($collection.'Members@odata.count') members"

        # Create batch requests for all members
        $requests = $collection.Members | ForEach-Object {
            @{
                Uri    = $_.'@odata.id'
                Method = 'GET'
            }
        }

        # Fetch all members in parallel
        $members = Invoke-RedfishBatchRequest -Session $Session -Requests $requests -MaxConcurrency $MaxConcurrency

        Write-Verbose "Retrieved $($members.Count) members"

        return $members
    }
}
#EndRegion './Private/Get-RedfishCollectionMember.ps1' 71
#Region './Private/Get-RedfishErrorDetail.ps1' -1

function Get-RedfishErrorDetail {
    <#
.SYNOPSIS
    Extracts structured error details from a Redfish error.

.DESCRIPTION
    Retrieves the structured error object from a caught Redfish exception.

.PARAMETER ErrorRecord
    The error record containing the Redfish error.

.EXAMPLE
    try {
        Invoke-RedfishRequest -Session $session -Uri '/invalid'
    } catch {
        $details = Get-RedfishErrorDetail $_
        if ($details.StatusCode -eq 404) {
            Write-Host "Resource not found"
        }
    }
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    process {
        if (Test-RedfishError $ErrorRecord) {
            return $ErrorRecord.TargetObject
        }
        return $null
    }
}
#EndRegion './Private/Get-RedfishErrorDetail.ps1' 37
#Region './Private/Invoke-RedfishBatchRequest.ps1' -1

function Invoke-RedfishBatchRequest {
    <#
.SYNOPSIS
    Invokes multiple Redfish requests in parallel for high performance.

.DESCRIPTION
    Executes multiple HTTP requests concurrently against a Redfish endpoint.
    Useful for fetching multiple resources simultaneously (e.g., all systems, all chassis).
    Automatically handles errors and returns results in the same order as input.

.PARAMETER Session
    The Redfish session object.

.PARAMETER Requests
    Array of hashtables containing Uri, Method, and optionally Body.
    Example: @{Uri='/redfish/v1/Systems/1'; Method='GET'}

.PARAMETER MaxConcurrency
    Maximum number of concurrent requests. Default is 10.

.PARAMETER ContinueOnError
    If specified, continues processing remaining requests even if some fail.
    Failed requests will return error objects instead of throwing.

.EXAMPLE
    $requests = @(
        @{Uri='/redfish/v1/Systems/1'; Method='GET'}
        @{Uri='/redfish/v1/Systems/2'; Method='GET'}
        @{Uri='/redfish/v1/Chassis/1'; Method='GET'}
    )
    $results = Invoke-RedfishBatchRequest -Session $session -Requests $requests

.EXAMPLE
    # Fetch all members from a collection
    $systems = Invoke-RedfishRequest -Session $session -Uri '/redfish/v1/Systems'
    $requests = $systems.Members | ForEach-Object {
        @{Uri = $_.'@odata.id'; Method = 'GET'}
    }
    $allSystems = Invoke-RedfishBatchRequest -Session $session -Requests $requests

.OUTPUTS
    Array of response objects or error objects (if ContinueOnError is specified)
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [ValidateScript({
                if ($_.PSTypeNames -contains 'PSRedfish.Session') {
                    $true
                } else {
                    throw 'Session parameter must be a valid Redfish session object'
                }
            })]
        [PSCustomObject]
        $Session,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Requests,

        [Parameter()]
        [ValidateRange(1, 50)]
        [int]
        $MaxConcurrency = 10,

        [Parameter()]
        [switch]
        $ContinueOnError
    )

    begin {
        Write-Verbose "Starting batch request with $($Requests.Count) requests (max concurrency: $MaxConcurrency)"
    }

    process {
        try {
            $results = [System.Collections.ArrayList]::new()
            $tasks = [System.Collections.ArrayList]::new()
            $semaphore = [System.Threading.SemaphoreSlim]::new($MaxConcurrency, $MaxConcurrency)

            foreach ($req in $Requests) {
                # Validate request structure
                if (-not $req.ContainsKey('Uri')) {
                    throw 'Each request must contain a Uri key'
                }

                $uri = $req.Uri
                $method = if ($req.ContainsKey('Method')) { $req.Method } else { 'GET' }
                $body = if ($req.ContainsKey('Body')) { $req.Body } else { $null }

                # Construct full URI
                $fullUri = if ($uri -match '^https?://') {
                    $uri
                } else {
                    $cleanUri = $uri.TrimStart('/')
                    "$($Session.BaseUri)/$cleanUri"
                }

                Write-Verbose "Queuing request: $method $fullUri"

                # Wait for semaphore slot
                $null = $semaphore.Wait()

                # Create request
                $httpMethod = [System.Net.Http.HttpMethod]::new($method)
                $request = [System.Net.Http.HttpRequestMessage]::new($httpMethod, $fullUri)

                if ($null -ne $body) {
                    $jsonBody = if ($body -is [string]) {
                        $body
                    } else {
                        $body | ConvertTo-Json -Depth 10 -Compress
                    }

                    $request.Content = [System.Net.Http.StringContent]::new(
                        $jsonBody,
                        [System.Text.Encoding]::UTF8,
                        'application/json'
                    )
                }

                # Send async request
                $task = $Session.HttpClient.SendAsync($request)

                # Add continuation to release semaphore
                $null = $task.ContinueWith([Action[System.Threading.Tasks.Task[System.Net.Http.HttpResponseMessage]]] {
                        $semaphore.Release() | Out-Null
                    })

                $null = $tasks.Add(@{
                        Task        = $task
                        Request     = $req
                        HttpRequest = $request
                    })
            }

            Write-Verbose 'All requests queued. Waiting for completion...'

            # Wait for all tasks
            $allTasks = $tasks | ForEach-Object { $_.Task }
            [System.Threading.Tasks.Task]::WaitAll($allTasks)

            Write-Verbose 'All requests completed. Processing results...'

            # Process results in order
            foreach ($taskInfo in $tasks) {
                try {
                    $response = $taskInfo.Task.Result

                    if ($response.IsSuccessStatusCode) {
                        $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()

                        if ([string]::IsNullOrWhiteSpace($content)) {
                            $null = $results.Add($null)
                        } else {
                            $result = $content | ConvertFrom-Json
                            $null = $results.Add($result)
                        }
                    } else {
                        # Handle error response
                        $errorContent = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                        $statusCode = [int]$response.StatusCode

                        $errorObject = [PSCustomObject]@{
                            PSTypeName   = 'PSRedfish.BatchError'
                            StatusCode   = $statusCode
                            ReasonPhrase = $response.ReasonPhrase
                            Message      = $errorContent
                            RequestUri   = $taskInfo.Request.Uri
                            Method       = if ($taskInfo.Request.ContainsKey('Method')) { $taskInfo.Request.Method } else { 'GET' }
                        }

                        if ($ContinueOnError) {
                            Write-Warning "Request failed: $($taskInfo.Request.Method) $($taskInfo.Request.Uri) - HTTP $statusCode"
                            $null = $results.Add($errorObject)
                        } else {
                            throw "Batch request failed at $($taskInfo.Request.Uri): HTTP $statusCode - $($response.ReasonPhrase)"
                        }
                    }

                    $response.Dispose()
                } catch {
                    if ($ContinueOnError) {
                        $errorObject = [PSCustomObject]@{
                            PSTypeName = 'PSRedfish.BatchError'
                            Message    = $_.Exception.Message
                            RequestUri = $taskInfo.Request.Uri
                            Method     = if ($taskInfo.Request.ContainsKey('Method')) { $taskInfo.Request.Method } else { 'GET' }
                        }
                        Write-Warning "Request failed: $($taskInfo.Request.Method) $($taskInfo.Request.Uri) - $($_.Exception.Message)"
                        $null = $results.Add($errorObject)
                    } else {
                        throw
                    }
                } finally {
                    $taskInfo.HttpRequest.Dispose()
                }
            }

            $semaphore.Dispose()

            Write-Verbose "Batch request completed successfully. Processed $($results.Count) results."

            return $results.ToArray()
        } catch {
            Write-Error "Batch request failed: $_"
            throw
        }
    }
}

#EndRegion './Private/Invoke-RedfishBatchRequest.ps1' 215
#Region './Private/Show-RedfishMetric.ps1' -1

function Show-RedfishMetric {
    <#
.SYNOPSIS
    Displays session performance metrics in a formatted table.

.DESCRIPTION
    Shows detailed performance statistics for a Redfish session with metrics enabled.

.PARAMETER Session
    The Redfish session object with metrics enabled.

.EXAMPLE
    Show-RedfishMetric -Session $session

.EXAMPLE
    $session.Metrics.GetStatistics() | Format-Table
#>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Write-Host is appropriate for this display function')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]
        $Session
    )

    process {
        if (-not $Session.Metrics) {
            Write-Warning 'Metrics are not enabled for this session. Create session with -EnableMetrics to collect metrics.'
            return
        }

        $stats = $Session.Metrics.GetStatistics()

        Write-Host -Object "`nRedfish Session Metrics - $($Session.BaseUri)" -ForegroundColor Cyan
        Write-Host -Object ('=' * 60) -ForegroundColor Cyan
        Write-Host -Object ''

        Write-Host -Object 'Session Info:' -ForegroundColor Yellow
        Write-Host -Object "  Uptime:              $($stats.SessionUptime)"
        Write-Host -Object "  Requests/Second:     $($stats.RequestsPerSecond)"
        Write-Host -Object ''

        Write-Host -Object 'Request Statistics:' -ForegroundColor Yellow
        Write-Host -Object "  Total Requests:      $($stats.TotalRequests)"
        Write-Host -Object "  Successful:          $($stats.SuccessfulRequests)"
        Write-Host -Object "  Failed:              $($stats.FailedRequests)"
        Write-Host -Object "  Success Rate:        $($stats.SuccessRate)%"
        Write-Host -Object ''

        Write-Host -Object 'Latency (ms):' -ForegroundColor Yellow
        Write-Host -Object "  Average:             $($stats.AverageLatencyMs)"
        Write-Host -Object "  Minimum:             $($stats.MinLatencyMs)"
        Write-Host -Object "  Maximum:             $($stats.MaxLatencyMs)"
        Write-Host -Object "  95th Percentile:     $($stats.P95LatencyMs)"
        Write-Host -Object "  99th Percentile:     $($stats.P99LatencyMs)"
        Write-Host -Object ''
    }
}
#EndRegion './Private/Show-RedfishMetric.ps1' 59
#Region './Private/Test-RedfishError.ps1' -1

function Test-RedfishError {
    <#
.SYNOPSIS
    Tests if an exception is a Redfish structured error.

.DESCRIPTION
    Helper function to identify and extract information from structured Redfish errors.

.PARAMETER ErrorRecord
    The error record to test.

.EXAMPLE
    try {
        Invoke-RedfishRequest -Session $session -Uri '/invalid'
    } catch {
        if (Test-RedfishError $_) {
            $redfishError = Get-RedfishErrorDetail $_
            Write-Host "HTTP $($redfishError.StatusCode): $($redfishError.Message)"
        }
    }
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    process {
        return $null -ne $ErrorRecord.TargetObject -and
        $ErrorRecord.TargetObject.PSObject.TypeNames -contains 'PSRedfish.Exception'
    }
}
#EndRegion './Private/Test-RedfishError.ps1' 35
#Region './Public/Get-RedfishSession.ps1' -1

function Get-RedfishSession {
    <#
    .SYNOPSIS
        Retrieves active Redfish sessions from the session cache.

    .DESCRIPTION
        Returns all active Redfish sessions that have been created in the current PowerShell session.
        Sessions are cached when created by New-RedfishSession and can be retrieved for inspection
        or to pass to other Redfish cmdlets.

    .PARAMETER BaseUri
        Optional filter to return only sessions matching a specific BaseUri.

    .EXAMPLE
        Get-RedfishSession
        Returns all active Redfish sessions.

    .EXAMPLE
        Get-RedfishSession -BaseUri 'https://redfish.example.com'
        Returns only sessions connected to the specified endpoint.

    .EXAMPLE
        $sessions = Get-RedfishSession
        $sessions | Remove-RedfishSession
        Gets all sessions and removes them via the pipeline.

    .OUTPUTS
        PSCustomObject or array containing Redfish session objects.

    .NOTES
        Sessions remain in cache until explicitly removed with Remove-RedfishSession.
        Each session contains an HttpClient that should be disposed when no longer needed.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject], [object[]])]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $BaseUri
    )

    begin {
        Write-Verbose "Starting $($MyInvocation.MyCommand)"
    }

    process {
        try {
            # Return empty array if no sessions exist
            if ($null -eq $script:RedfishSessions -or $script:RedfishSessions.Count -eq 0) {
                Write-Verbose 'No active Redfish sessions found'
                return @()
            }

            # Filter by BaseUri if specified
            if ($PSBoundParameters.ContainsKey('BaseUri')) {
                $normalizedUri = $BaseUri.TrimEnd('/')
                $filtered = $script:RedfishSessions | Where-Object { $_.BaseUri -eq $normalizedUri }

                if ($filtered) {
                    Write-Verbose "Found $(@($filtered).Count) session(s) matching BaseUri: $normalizedUri"
                    return @($filtered)
                } else {
                    Write-Verbose "No sessions found matching BaseUri: $normalizedUri"
                    return @()
                }
            }

            # Return all sessions
            Write-Verbose "Found $($script:RedfishSessions.Count) active Redfish session(s)"
            return $script:RedfishSessions.ToArray()
        } catch {
            Write-Verbose "$($MyInvocation.MyCommand) failed: $_"
            Write-Verbose "StackTrace: $($_.ScriptStackTrace)"
            throw $_
        }
    }

    end {
        Write-Verbose "Completed $($MyInvocation.MyCommand)"
    }
}
#EndRegion './Public/Get-RedfishSession.ps1' 83
#Region './Public/Invoke-RedfishRequest.ps1' -1

function Invoke-RedfishRequest {
    <#
    .SYNOPSIS
        Invokes a request against a Redfish API endpoint with retry logic and enhanced error handling.

    .DESCRIPTION
        Executes an HTTP request (GET, POST, PATCH, PUT, DELETE) against a Redfish API endpoint
        using an established session. Supports both relative and absolute URIs.
        Includes automatic retry logic for transient failures and structured error objects.
        Uses .NET HttpClient for optimal performance.

    .PARAMETER Session
        The Redfish session object created by New-RedfishSession.

    .PARAMETER Uri
        The URI to request. Can be relative (e.g., '/redfish/v1/Systems') or absolute.
        If relative, it will be appended to the session's BaseUri.

    .PARAMETER Method
        The HTTP method to use. Default is GET.

    .PARAMETER Body
        The request body as a hashtable or PSCustomObject. Will be converted to JSON.

    .PARAMETER ContentType
        The Content-Type header for the request. Default is 'application/json'.

    .PARAMETER TimeoutSeconds
        Override the session's default timeout for this specific request.

    .PARAMETER MaxRetries
        Maximum number of retry attempts for transient failures. Default is 3.
        Set to 0 to disable retries.

    .PARAMETER RetryDelayMilliseconds
        Initial delay between retries in milliseconds. Default is 1000 (1 second).
        Delay increases exponentially with each retry.

    .PARAMETER NoRetry
        Disable retry logic for this request. Useful for operations that should fail fast.

    .EXAMPLE
        $systems = Invoke-RedfishRequest -Session $session -Uri '/redfish/v1/Systems'
        Gets the list of computer systems.

    .EXAMPLE
        $body = @{ AssetTag = 'SERVER-001' }
        Invoke-RedfishRequest -Session $session -Uri '/redfish/v1/Systems/1' -Method PATCH -Body $body
        Updates the AssetTag property of a system with automatic retry on transient failures.

    .EXAMPLE
        $result = Invoke-RedfishRequest -Session $session -Uri '/redfish/v1/Systems/1' -NoRetry
        Gets system information without retry logic.

    .OUTPUTS
        PSCustomObject containing the response data from the Redfish API.

    .NOTES
        For DELETE operations that return no content, returns $null.
        Automatically retries on HTTP 408, 429, 503, 504 status codes.
        Throws structured RedfishException objects for easier error handling.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNull()]
        [ValidateScript({
                if ($_.PSTypeNames -contains 'PSRedfish.Session') {
                    $true
                } else {
                    throw 'Session parameter must be a valid Redfish session object created by New-RedfishSession'
                }
            })]
        [PSCustomObject]
        $Session,

        [Parameter(Mandatory, Position = 1, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('@odata.id', 'Path')]
        [string]
        $Uri,

        [Parameter()]
        [ValidateSet('GET', 'POST', 'PATCH', 'PUT', 'DELETE')]
        [string]
        $Method = 'GET',

        [Parameter()]
        [ValidateNotNull()]
        [object]
        $Body,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ContentType = 'application/json',

        [Parameter()]
        [ValidateRange(1, 300)]
        [int]
        $TimeoutSeconds,

        [Parameter()]
        [ValidateRange(0, 10)]
        [int]
        $MaxRetries = 3,

        [Parameter()]
        [ValidateRange(100, 60000)]
        [int]
        $RetryDelayMilliseconds = 1000,

        [Parameter()]
        [switch]
        $NoRetry
    )

    begin {
        Write-Verbose "Starting $($MyInvocation.MyCommand)"
    }

    process {
        $attempt = 0
        $delay = $RetryDelayMilliseconds
        $maxAttempts = if ($NoRetry) { 1 } else { $MaxRetries + 1 }

        while ($attempt -lt $maxAttempts) {
            $attempt++
            $request = $null
            $response = $null
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            try {
                # Construct full URI
                $fullUri = if ($Uri -match '^https?://') {
                    $Uri
                } else {
                    $cleanUri = $Uri.TrimStart('/')
                    "$($Session.BaseUri)/$cleanUri"
                }

                Write-Verbose "$Method request to: $fullUri (Attempt $attempt/$maxAttempts)"

                # Create HTTP request message
                $httpMethod = [System.Net.Http.HttpMethod]::new($Method)
                $request = [System.Net.Http.HttpRequestMessage]::new($httpMethod, $fullUri)

                # Add body if provided
                if ($PSBoundParameters.ContainsKey('Body')) {
                    $jsonBody = if ($Body -is [string]) {
                        $Body
                    } else {
                        $Body | ConvertTo-Json -Depth 10 -Compress
                    }

                    Write-Verbose "Request body: $jsonBody"
                    $request.Content = [System.Net.Http.StringContent]::new(
                        $jsonBody,
                        [System.Text.Encoding]::UTF8,
                        $ContentType
                    )
                }

                if ($PSCmdlet.ShouldProcess($fullUri, "$Method request")) {
                    # Handle per-request timeout
                    if ($PSBoundParameters.ContainsKey('TimeoutSeconds')) {
                        $cts = [System.Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds($TimeoutSeconds))
                        try {
                            $response = $Session.HttpClient.SendAsync($request, $cts.Token).GetAwaiter().GetResult()
                        } finally {
                            $cts.Dispose()
                        }
                    } else {
                        $response = $Session.HttpClient.SendAsync($request).GetAwaiter().GetResult()
                    }

                    $stopwatch.Stop()

                    # Update metrics if available
                    if ($Session.PSObject.Properties['Metrics']) {
                        $Session.Metrics.TotalRequests++
                        $Session.Metrics.RequestDurations.Add($stopwatch.Elapsed.TotalMilliseconds)
                    }

                    # Check for successful status code
                    if (-not $response.IsSuccessStatusCode) {
                        $errorContent = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                        $statusCode = [int]$response.StatusCode

                        # Parse Redfish error format
                        $errorObject = $null
                        $errorMessage = $errorContent
                        $extendedInfo = $null

                        try {
                            $errorObject = $errorContent | ConvertFrom-Json
                            if ($errorObject.error) {
                                if ($errorObject.error.'@Message.ExtendedInfo') {
                                    $messages = $errorObject.error.'@Message.ExtendedInfo' | ForEach-Object {
                                        if ($_.Message) { $_.Message }
                                    }
                                    $errorMessage = $messages -join '; '
                                    $extendedInfo = $errorObject.error.'@Message.ExtendedInfo'
                                } elseif ($errorObject.error.message) {
                                    $errorMessage = $errorObject.error.message
                                }
                            }
                        } catch {
                            Write-Verbose "Could not parse error response as JSON: $_"
                        }

                        # Determine if error is retryable
                        $retryableCodes = @(408, 429, 503, 504)  # Request Timeout, Too Many Requests, Service Unavailable, Gateway Timeout
                        $isRetryable = $statusCode -in $retryableCodes

                        # Check for Retry-After header (for 429 and 503)
                        $retryAfter = $null
                        if ($response.Headers.Contains('Retry-After')) {
                            $retryAfterValue = $response.Headers.GetValues('Retry-After')[0]
                            if ($retryAfterValue -match '^\d+$') {
                                $retryAfter = [int]$retryAfterValue
                            }
                        }

                        # Create structured error object
                        $redfishException = [PSCustomObject]@{
                            PSTypeName   = 'PSRedfish.Exception'
                            StatusCode   = $statusCode
                            ReasonPhrase = $response.ReasonPhrase
                            Message      = $errorMessage
                            ExtendedInfo = $extendedInfo
                            RequestUri   = $fullUri
                            Method       = $Method
                            Timestamp    = [DateTime]::UtcNow
                            IsRetryable  = $isRetryable
                            RetryAfter   = $retryAfter
                            Attempt      = $attempt
                            DurationMs   = $stopwatch.Elapsed.TotalMilliseconds
                        }

                        # Update failure metrics
                        if ($Session.PSObject.Properties['Metrics']) {
                            $Session.Metrics.FailedRequests++
                        }

                        # Decide whether to retry
                        if ($isRetryable -and $attempt -lt $maxAttempts -and -not $NoRetry) {
                            $actualDelay = if ($retryAfter) {
                                [Math]::Min($retryAfter * 1000, 60000)  # Max 60 seconds
                            } else {
                                [Math]::Min($delay, 30000)  # Max 30 seconds
                            }

                            Write-Warning "Request failed with HTTP $statusCode. Retrying in ${actualDelay}ms... (Attempt $attempt/$maxAttempts)"
                            Start-Sleep -Milliseconds $actualDelay
                            $delay = $delay * 2  # Exponential backoff
                            continue  # Retry
                        }

                        # Not retryable or max retries reached - throw error
                        $errorRecordMessage = "HTTP $statusCode - $($response.ReasonPhrase): $errorMessage"

                        $exception = [System.Net.Http.HttpRequestException]::new(
                            $errorRecordMessage,
                            $null,
                            $statusCode
                        )

                        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                            $exception,
                            "RedfishHttpError_$statusCode",
                            [System.Management.Automation.ErrorCategory]::InvalidOperation,
                            $redfishException
                        )

                        throw $errorRecord
                    }

                    # Success - update metrics
                    if ($Session.PSObject.Properties['Metrics']) {
                        $Session.Metrics.SuccessfulRequests++
                    }

                    # Read response content
                    $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()

                    # Return null for empty responses (common with DELETE)
                    if ([string]::IsNullOrWhiteSpace($content)) {
                        Write-Verbose "Request completed successfully in $($stopwatch.Elapsed.TotalMilliseconds)ms (no content returned)"
                        return $null
                    }

                    # Parse JSON response
                    $result = $content | ConvertFrom-Json
                    Write-Verbose "Request completed successfully in $($stopwatch.Elapsed.TotalMilliseconds)ms"

                    return $result
                }
            } catch [System.Threading.Tasks.TaskCanceledException] {
                # Timeout exception
                $stopwatch.Stop()

                Write-Verbose "Request timed out after $($stopwatch.Elapsed.TotalSeconds)s"

                # Update metrics
                if ($Session.PSObject.Properties['Metrics']) {
                    $Session.Metrics.TotalRequests++
                    $Session.Metrics.FailedRequests++
                }

                # Create timeout error
                $timeoutException = [PSCustomObject]@{
                    PSTypeName   = 'PSRedfish.Exception'
                    StatusCode   = 408
                    ReasonPhrase = 'Request Timeout'
                    Message      = 'The request timed out'
                    RequestUri   = $fullUri
                    Method       = $Method
                    Timestamp    = [DateTime]::UtcNow
                    IsRetryable  = $true
                    Attempt      = $attempt
                    DurationMs   = $stopwatch.Elapsed.TotalMilliseconds
                }

                # Retry on timeout if not at max attempts
                if ($attempt -lt $maxAttempts -and -not $NoRetry) {
                    Write-Warning "Request timed out. Retrying in ${delay}ms... (Attempt $attempt/$maxAttempts)"
                    Start-Sleep -Milliseconds $delay
                    $delay = $delay * 2
                    continue
                }

                # Max retries reached
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    $_,
                    'RedfishRequestTimeout',
                    [System.Management.Automation.ErrorCategory]::OperationTimeout,
                    $timeoutException
                )
                throw $errorRecord
            } catch {
                Write-Verbose "$($MyInvocation.MyCommand) failed: $_"
                Write-Verbose "StackTrace: $($_.ScriptStackTrace)"

                # If this is already a structured error, just re-throw it
                if ($_.TargetObject.PSTypeName -eq 'PSRedfish.Exception') {
                    throw
                }

                # For other exceptions, wrap them
                throw $_
            } finally {
                if ($null -ne $request) {
                    $request.Dispose()
                }
                if ($null -ne $response) {
                    $response.Dispose()
                }
            }
        }
    }

    end {
        Write-Verbose "Completed $($MyInvocation.MyCommand)"
    }
}
#EndRegion './Public/Invoke-RedfishRequest.ps1' 368
#Region './Public/New-RedfishSession.ps1' -1

function New-RedfishSession {
    <#
    .SYNOPSIS
        Creates a new Redfish session to a DMTF Redfish® API endpoint with enhanced performance.

    .DESCRIPTION
        Establishes an authenticated session to a Redfish API endpoint using either Basic authentication
        or Redfish session-based authentication. Session-based authentication is more secure and recommended.
        Returns a session object that can be used with other Redfish cmdlets.
        Uses optimized .NET HttpClient with connection pooling for high performance.

    .PARAMETER BaseUri
        The base URI of the Redfish API endpoint (e.g., https://redfish.example.com).

    .PARAMETER Credential
        PSCredential object containing the username and password for authentication.

    .PARAMETER AuthMethod
        Authentication method to use. Valid values are 'Session' (default) and 'Basic'.
        Session authentication creates a Redfish session and uses X-Auth-Token.
        Basic authentication uses HTTP Basic Auth for each request.

    .PARAMETER SkipCertificateCheck
        If specified, skips SSL certificate validation. Use with caution in production environments.

    .PARAMETER TimeoutSeconds
        The timeout in seconds for HTTP requests. Default is 30 seconds.

    .PARAMETER MaxConnectionsPerServer
        Maximum number of concurrent connections to the server. Default is 10.
        Increase for high-throughput scenarios.

    .PARAMETER ConnectionLifetimeMinutes
        How long to keep connections alive in the pool. Default is 5 minutes.
        Helps with load balancer scenarios.

    .PARAMETER EnableMetrics
        Enable collection of performance metrics for this session.
        Access metrics via $session.Metrics.GetStatistics()

    .EXAMPLE
        $cred = Get-Credential
        $session = New-RedfishSession -BaseUri 'https://redfish.example.com' -Credential $cred
        Creates a new Redfish session using session-based authentication (default).

    .EXAMPLE
        $session = New-RedfishSession -BaseUri 'https://redfish.example.com' -Credential $cred -EnableMetrics
        $session.Metrics.GetStatistics()
        Creates a session with performance metrics enabled.

    .EXAMPLE
        $session = New-RedfishSession -BaseUri 'https://192.168.1.100' -Credential $cred -SkipCertificateCheck -MaxConnectionsPerServer 20
        Creates a high-performance session with 20 concurrent connections allowed.

    .OUTPUTS
        PSCustomObject representing the Redfish session with HttpClient and session details.

    .NOTES
        The session object contains an HttpClient instance that should be disposed when no longer needed.
        Use Remove-RedfishSession to properly clean up the session.
        Connection pooling is automatically enabled for better performance.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                if ($_ -match '^https?://') {
                    $true
                } else {
                    throw 'BaseUri must start with http:// or https://'
                }
            })]
        [string]
        $BaseUri,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [ValidateSet('Session', 'Basic')]
        [string]
        $AuthMethod = 'Session',

        [Parameter()]
        [switch]
        $SkipCertificateCheck,

        [Parameter()]
        [ValidateRange(1, 300)]
        [int]
        $TimeoutSeconds = 30,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]
        $MaxConnectionsPerServer = 10,

        [Parameter()]
        [ValidateRange(1, 60)]
        [int]
        $ConnectionLifetimeMinutes = 5,

        [Parameter()]
        [switch]
        $EnableMetrics
    )

    begin {
        Write-Verbose "Starting $($MyInvocation.MyCommand)"
    }

    process {
        try {
            # Normalize the BaseUri (remove trailing slash)
            $normalizedUri = $BaseUri.TrimEnd('/')

            if (-not $PSCmdlet.ShouldProcess($normalizedUri, 'Create Redfish session')) {
                return
            }

            # Create optimized HttpClientHandler with SocketsHttpHandler for better performance
            # Note: SocketsHttpHandler is the recommended handler for .NET Core/.NET 5+
            $handler = if ($PSVersionTable.PSVersion.Major -ge 7) {
                # Use SocketsHttpHandler for PowerShell 7+ (better performance)
                $socketsHandler = [System.Net.Http.SocketsHttpHandler]::new()

                # Configure connection pooling
                $socketsHandler.PooledConnectionLifetime = [TimeSpan]::FromMinutes($ConnectionLifetimeMinutes)
                $socketsHandler.PooledConnectionIdleTimeout = [TimeSpan]::FromMinutes([Math]::Max($ConnectionLifetimeMinutes - 1, 1))
                $socketsHandler.MaxConnectionsPerServer = $MaxConnectionsPerServer

                # Enable keep-alive
                $socketsHandler.EnableMultipleHttp2Connections = $true

                # Configure SSL/TLS
                if ($SkipCertificateCheck) {
                    Write-Warning 'SSL certificate validation is disabled. This is insecure and should only be used for testing.'
                    $socketsHandler.SslOptions = [System.Net.Security.SslClientAuthenticationOptions]@{
                        RemoteCertificateValidationCallback = { $true }
                    }
                } else {
                    # Enable modern TLS versions
                    $socketsHandler.SslOptions = [System.Net.Security.SslClientAuthenticationOptions]@{
                        EnabledSslProtocols = [System.Security.Authentication.SslProtocols]::Tls12 -bor
                        [System.Security.Authentication.SslProtocols]::Tls13
                    }
                }

                # Enable automatic decompression
                $socketsHandler.AutomaticDecompression = [System.Net.DecompressionMethods]::All

                $socketsHandler
            } else {
                # Fallback to HttpClientHandler for older PowerShell versions
                $httpHandler = [System.Net.Http.HttpClientHandler]::new()

                if ($SkipCertificateCheck) {
                    Write-Warning 'SSL certificate validation is disabled. This is insecure and should only be used for testing.'
                    $httpHandler.ServerCertificateCustomValidationCallback = { $true }
                }

                # Enable automatic decompression
                $httpHandler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor
                [System.Net.DecompressionMethods]::Deflate

                $httpHandler
            }

            # Create HttpClient with optimized settings
            $httpClient = [System.Net.Http.HttpClient]::new($handler)
            $httpClient.Timeout = [System.TimeSpan]::FromSeconds($TimeoutSeconds)
            $httpClient.DefaultRequestHeaders.Clear()

            # Set default headers for Redfish
            $httpClient.DefaultRequestHeaders.Add('Accept', 'application/json')
            $httpClient.DefaultRequestHeaders.Add('OData-Version', '4.0')
            $httpClient.DefaultRequestHeaders.Add('User-Agent', 'PSRedfish/2.0')

            $username = $Credential.UserName
            $password = $Credential.GetNetworkCredential().Password
            $sessionToken = $null
            $sessionUri = $null

            if ($AuthMethod -eq 'Session') {
                # Create Redfish session for token-based authentication
                Write-Verbose 'Creating Redfish session with token authentication'

                # First, use Basic auth to create the session
                $encodedAuth = [System.Convert]::ToBase64String(
                    [System.Text.Encoding]::ASCII.GetBytes("${username}:${password}")
                )
                $httpClient.DefaultRequestHeaders.Add('Authorization', "Basic $encodedAuth")

                $sessionBody = @{
                    UserName = $username
                    Password = $password
                } | ConvertTo-Json

                $sessionContent = [System.Net.Http.StringContent]::new(
                    $sessionBody,
                    [System.Text.Encoding]::UTF8,
                    'application/json'
                )

                # Retry session creation with exponential backoff
                $maxRetries = 3
                $retryDelay = 1000
                $sessionCreated = $false

                for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
                    try {
                        Write-Verbose "Attempting to create session (attempt $attempt/$maxRetries)"
                        $sessionResponse = $httpClient.PostAsync("$normalizedUri/redfish/v1/SessionService/Sessions", $sessionContent).GetAwaiter().GetResult()

                        if (-not $sessionResponse.IsSuccessStatusCode) {
                            $errorContent = $sessionResponse.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                            $statusCode = [int]$sessionResponse.StatusCode

                            # Retry on transient errors
                            if ($statusCode -in @(408, 429, 503, 504) -and $attempt -lt $maxRetries) {
                                Write-Warning "Session creation failed with HTTP $statusCode. Retrying in ${retryDelay}ms..."
                                $sessionResponse.Dispose()
                                Start-Sleep -Milliseconds $retryDelay
                                $retryDelay *= 2
                                continue
                            }

                            throw "Failed to create Redfish session. Status: $statusCode - $($sessionResponse.ReasonPhrase): $errorContent"
                        }

                        # Extract X-Auth-Token from response headers
                        if ($sessionResponse.Headers.Contains('X-Auth-Token')) {
                            $sessionToken = $sessionResponse.Headers.GetValues('X-Auth-Token')[0]
                            Write-Verbose 'Session token obtained successfully'
                        } else {
                            throw 'Server did not return X-Auth-Token header. Session authentication may not be supported.'
                        }

                        # Extract session Location URI
                        if ($sessionResponse.Headers.Contains('Location')) {
                            $sessionUri = $sessionResponse.Headers.GetValues('Location')[0]
                            Write-Verbose "Session created at: $sessionUri"
                        }

                        $sessionResponse.Dispose()
                        $sessionCreated = $true
                        break
                    } catch {
                        if ($attempt -eq $maxRetries) {
                            throw
                        }
                    }
                }

                $sessionContent.Dispose()

                if (-not $sessionCreated) {
                    throw 'Failed to create Redfish session after multiple attempts'
                }

                # Remove Basic auth and add token authentication
                $httpClient.DefaultRequestHeaders.Remove('Authorization')
                $httpClient.DefaultRequestHeaders.Add('X-Auth-Token', $sessionToken)
            } else {
                # Use Basic Authentication for all requests
                Write-Verbose 'Using HTTP Basic authentication'
                $encodedAuth = [System.Convert]::ToBase64String(
                    [System.Text.Encoding]::ASCII.GetBytes("${username}:${password}")
                )
                $httpClient.DefaultRequestHeaders.Add('Authorization', "Basic $encodedAuth")
            }

            # Test the connection by getting the service root
            Write-Verbose "Testing connection to $normalizedUri/redfish/v1"
            $testUri = "$normalizedUri/redfish/v1"
            $response = $httpClient.GetAsync($testUri).GetAwaiter().GetResult()

            if (-not $response.IsSuccessStatusCode) {
                throw "Failed to connect to Redfish endpoint. Status: $($response.StatusCode) - $($response.ReasonPhrase)"
            }

            $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            $serviceRoot = $content | ConvertFrom-Json

            Write-Verbose "Successfully connected to Redfish service: $($serviceRoot.Name)"
            $response.Dispose()

            # Initialize metrics if enabled
            $metrics = if ($EnableMetrics) {
                [PSCustomObject]@{
                    PSTypeName         = 'PSRedfish.Metrics'
                    TotalRequests      = 0
                    SuccessfulRequests = 0
                    FailedRequests     = 0
                    RequestDurations   = [System.Collections.Generic.List[double]]::new()
                    SessionStartTime   = [DateTime]::UtcNow
                } | Add-Member -MemberType ScriptMethod -Name GetStatistics -Value {
                    $duration = [DateTime]::UtcNow - $this.SessionStartTime

                    [PSCustomObject]@{
                        TotalRequests      = $this.TotalRequests
                        SuccessfulRequests = $this.SuccessfulRequests
                        FailedRequests     = $this.FailedRequests
                        SuccessRate        = if ($this.TotalRequests -gt 0) {
                            [Math]::Round(($this.SuccessfulRequests / $this.TotalRequests) * 100, 2)
                        } else { 0 }
                        AverageLatencyMs   = if ($this.RequestDurations.Count -gt 0) {
                            [Math]::Round(($this.RequestDurations | Measure-Object -Average).Average, 2)
                        } else { 0 }
                        MinLatencyMs       = if ($this.RequestDurations.Count -gt 0) {
                            [Math]::Round(($this.RequestDurations | Measure-Object -Minimum).Minimum, 2)
                        } else { 0 }
                        MaxLatencyMs       = if ($this.RequestDurations.Count -gt 0) {
                            [Math]::Round(($this.RequestDurations | Measure-Object -Maximum).Maximum, 2)
                        } else { 0 }
                        P95LatencyMs       = if ($this.RequestDurations.Count -gt 0) {
                            $sorted = $this.RequestDurations | Sort-Object
                            $index = [Math]::Floor($sorted.Count * 0.95)
                            [Math]::Round($sorted[$index], 2)
                        } else { 0 }
                        P99LatencyMs       = if ($this.RequestDurations.Count -gt 0) {
                            $sorted = $this.RequestDurations | Sort-Object
                            $index = [Math]::Floor($sorted.Count * 0.99)
                            [Math]::Round($sorted[$index], 2)
                        } else { 0 }
                        SessionUptime      = $duration.ToString('hh\:mm\:ss')
                        RequestsPerSecond  = if ($duration.TotalSeconds -gt 0) {
                            [Math]::Round($this.TotalRequests / $duration.TotalSeconds, 2)
                        } else { 0 }
                    }
                } -PassThru
            } else {
                $null
            }

            # Create session object
            $sessionObject = [PSCustomObject]@{
                PSTypeName              = 'PSRedfish.Session'
                BaseUri                 = $normalizedUri
                ServiceRoot             = $serviceRoot
                HttpClient              = $httpClient
                AuthMethod              = $AuthMethod
                SessionToken            = $sessionToken
                SessionUri              = $sessionUri
                CreatedAt               = [DateTime]::UtcNow
                TimeoutSeconds          = $TimeoutSeconds
                Username                = $username
                SkipCertificateCheck    = $SkipCertificateCheck.IsPresent
                MaxConnectionsPerServer = $MaxConnectionsPerServer
                ConnectionLifetime      = [TimeSpan]::FromMinutes($ConnectionLifetimeMinutes)
                Metrics                 = $metrics
            }

            # Store session in script scope for potential retrieval
            if (-not $script:RedfishSessions) {
                $script:RedfishSessions = [System.Collections.Generic.List[PSCustomObject]]::new()
            }
            $script:RedfishSessions.Add($sessionObject)

            Write-Verbose 'Redfish session created successfully'
            if ($EnableMetrics) {
                Write-Verbose 'Performance metrics collection enabled. Access via $session.Metrics.GetStatistics()'
            }

            return $sessionObject
        } catch {
            Write-Verbose "$($MyInvocation.MyCommand) failed: $_"
            Write-Verbose "StackTrace: $($_.ScriptStackTrace)"

            # Clean up if HttpClient was created
            if ($null -ne $httpClient) {
                $httpClient.Dispose()
            }
            if ($null -ne $handler) {
                $handler.Dispose()
            }

            throw $_
        }
    }

    end {
        Write-Verbose "Completed $($MyInvocation.MyCommand)"
    }
}
#EndRegion './Public/New-RedfishSession.ps1' 390
#Region './Public/Remove-RedfishSession.ps1' -1

function Remove-RedfishSession {
    <#
    .SYNOPSIS
        Removes a Redfish session and disposes of associated resources.

    .DESCRIPTION
        Properly disposes of a Redfish session by cleaning up the HttpClient and removing
        the session from the session cache. This ensures proper resource cleanup and
        prevents memory leaks.

    .PARAMETER Session
        The Redfish session object to remove.

    .EXAMPLE
        Remove-RedfishSession -Session $session
        Removes the specified Redfish session and cleans up resources.

    .EXAMPLE
        $session | Remove-RedfishSession
        Removes the Redfish session from the pipeline.

    .OUTPUTS
        None

    .NOTES
        Always call this function when done with a Redfish session to ensure proper cleanup.
        Disposing the HttpClient will close any open connections.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [ValidateNotNull()]
        [ValidateScript({
                if ($_.PSTypeNames -contains 'PSRedfish.Session') {
                    $true
                } else {
                    throw 'Session parameter must be a valid Redfish session object created by New-RedfishSession'
                }
            })]
        [PSCustomObject]
        $Session
    )

    begin {
        Write-Verbose "Starting $($MyInvocation.MyCommand)"
    }

    process {
        try {
            $target = "$($Session.BaseUri) (User: $($Session.Username))"

            if ($PSCmdlet.ShouldProcess($target, 'Remove Redfish session')) {
                Write-Verbose "Removing Redfish session for $target"

                # Delete Redfish session if using session authentication
                if ($Session.AuthMethod -eq 'Session' -and $null -ne $Session.SessionUri) {
                    try {
                        Write-Verbose "Deleting Redfish session at: $($Session.SessionUri)"
                        $deleteRequest = [System.Net.Http.HttpRequestMessage]::new(
                            [System.Net.Http.HttpMethod]::Delete,
                            $Session.SessionUri
                        )
                        $deleteResponse = $Session.HttpClient.SendAsync($deleteRequest).GetAwaiter().GetResult()

                        if ($deleteResponse.IsSuccessStatusCode) {
                            Write-Verbose 'Redfish session deleted successfully'
                        } else {
                            Write-Warning "Failed to delete Redfish session: $($deleteResponse.StatusCode) - $($deleteResponse.ReasonPhrase)"
                        }

                        $deleteRequest.Dispose()
                        $deleteResponse.Dispose()
                    } catch {
                        Write-Warning "Failed to delete Redfish session: $_"
                    }
                }

                # Dispose HttpClient if present
                if ($Session.PSObject.Properties['HttpClient'] -and $null -ne $Session.HttpClient) {
                    try {
                        $Session.HttpClient.Dispose()
                        Write-Verbose 'HttpClient disposed successfully'
                    } catch {
                        Write-Warning "Failed to dispose HttpClient: $_"
                    }
                }

                # Remove from session cache
                if ($null -ne $script:RedfishSessions) {
                    $removed = $script:RedfishSessions.Remove($Session)
                    if ($removed) {
                        Write-Verbose 'Session removed from cache'
                    } else {
                        Write-Verbose 'Session was not found in cache'
                    }
                }

                Write-Verbose 'Redfish session removed successfully'
            }
        } catch {
            Write-Verbose "$($MyInvocation.MyCommand) failed: $_"
            Write-Verbose "StackTrace: $($_.ScriptStackTrace)"
            throw $_
        }
    }

    end {
        Write-Verbose "Completed $($MyInvocation.MyCommand)"
    }
}
#EndRegion './Public/Remove-RedfishSession.ps1' 111
