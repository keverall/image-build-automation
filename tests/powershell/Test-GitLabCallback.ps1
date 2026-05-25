#
# Test-GitLabCallback.ps1 — Test callback mechanism for GitLab maintenance integration
# Spins up a mock HTTP listener to receive callbacks from GitLab CI
#
[CmdletBinding()]
param(
    [int] $Port = 8080,
    [string] $CallbackPath = "/api/maintenance/callback"
)

$ErrorActionPreference = 'Stop'

# Start HTTP listener for callback testing
$listener = [System.Net.HttpListener]::new()
$prefix = "http://localhost:$Port$CallbackPath/"
$listener.Prefixes.Add($prefix)
$listener.Start()

Write-Host "Mock iRequest callback endpoint listening on $prefix"
Write-Host "Press Ctrl+C to stop"

$callbackReceived = @()

try {
    while ($true) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $body = [System.IO.StreamReader]::new($request.InputStream).ReadToEnd()

        $callback = @{
            timestamp = (Get-Date).ToString('o')
            method = $request.HttpMethod
            path = $request.Url.AbsolutePath
            headers = @{}
            body = $null
        }

        foreach ($key in $request.Headers.AllKeys) {
            $callback.headers[$key] = $request.Headers[$key]
        }

        if ($body) {
            try {
                $callback.body = $body | ConvertFrom-Json -ErrorAction Stop
            } catch {
                $callback.body = $body
            }
        }

        $callbackReceived += $callback

        $response.StatusCode = 200
        $response.StatusDescription = "OK"
        $response.Close()

        Write-Host "Callback received: $($callback.body | ConvertTo-Json -Compress)"
        Write-Host "Total callbacks: $($callbackReceived.Count)"
    }
}
finally {
    $listener.Stop()
    $listener.Dispose()
}

# vim: ts=4 sw=4 et