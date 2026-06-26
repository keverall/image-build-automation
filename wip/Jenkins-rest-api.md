# CI Pipeline REST API to bridge web-based ticketing systems

(like iRequest, ServiceNow, or Jira) with automated backend PowerShell scripts is a very standard enterprise workflow.
Because this server is running inside a strict corporate network with no internet access, this API architecture is actually the best solution. It allows external applications to trigger automation inside your isolated zone safely.
Here is the exact architecture and code required to make this work.
------------------------------
## Step 1: Configure Pipeline Variables

Before sending data via API, you must configure a CI pipeline that knows how to accept incoming data from iRequest and pass it into a PowerShell script.

   1. In your CI system, configure a pipeline that triggers via webhook.
   2. Define variables that will be passed to the pipeline:
      - ComputerName (The server entering maintenance mode)
      - DurationMinutes (How long to silence alerts)
      - Reason (The ticket reference or justification)
   3. In the pipeline script, use these variables in PowerShell:

   ```yaml
   powershell:
     - pwsh -File ./scripts/Set-MaintenanceMode.ps1 -ComputerName $env:COMPUTERNAME -DurationMinutes $env:DURATIONMINUTES -Reason $env:REASON
   ```

------------------------------

## Step 2: Generate a Pipeline Trigger Token

The CI system requires a trigger token for authentication instead of your raw corporate Active Directory password for programmatic access.

   1. In your CI dashboard, navigate to the project → **Settings > CI/CD > Pipeline triggers**
   2. Click **Add trigger**
   3. Give it a description (e.g., `iRequest-Link`)
   4. Click **Save** and **copy the token** - it is displayed **once only**

------------------------------

## Step 3: Triggering CI from iRequest (The API Call)

Your corporate iRequest tool just needs to send an HTTP POST request to your local CI server web port.
If iRequest utilizes a PowerShell engine under the hood to send outbound API webhooks, it would execute this payload to kick off the automation build:

# 1. Define trigger token

```powershell
$GitLabUrl    = "https://gitlab.your-company.local"
$ProjectId    = "1234"
$TriggerToken = "glptt-xxxxxxxxxxxxxxxxxxxxxxxxxx"
```

# 2. Define the payload parameters matching your pipeline settings

```powershell
$Variables = @{
    ComputerName    = "WebProdServer01.corporate.local"
    DurationMinutes = "60"
    Reason          = "Planned OS Patching via iRequest"
}
```

# 3. Construct the trigger URL and send

```powershell
$Uri = "$GitLabUrl/api/v4/projects/$ProjectId/trigger/pipeline"
$Body = @{
    token     = $TriggerToken
    ref       = "main"
    variables = $Variables
}
Invoke-RestMethod -Uri $Uri -Method Post -Body $Body -ContentType 'application/x-www-form-urlencoded'
```

## How the workflow passes data:

   1. An end-user fills out an iRequest form requesting a task (e.g., provisioning a resource or restarting a service).
   2. The iRequest workflow engine executes the HTTP POST script natively behind the scenes.
   3. Your local CI instance accepts the payload, extracts the variables, and launches your backend PowerShell script to do the work.

## To trigger your specific SCOM script through the CI REST API from iRequest, you must use the trigger pipeline endpoint.

This allows iRequest to send a web request that triggers your CI pipeline to run your local script file while passing variable data (like Computer Name, Duration, and Reason) dynamically into it.

------------------------------

## Step 2: The iRequest API Command (PowerShell Payload)

When an iRequest form is submitted, the iRequest workflow engine must fire this specific raw HTTP POST command to pass the server details over to the CI pipeline.
Replace YOUR_GITLAB_URL, YOUR_PROJECT_ID, and YOUR_TRIGGER_TOKEN with your actual CI credentials:

# 1. Setup secure credentials

```powershell
$GitLabUrl    = "https://gitlab.your-company.local"
$ProjectId    = "1234"
$TriggerToken = "glptt-xxxxxxxxxxxxxxxxxxxxxxxxxx"
```

# 2. Map data fields straight from the submitted iRequest form

```powershell
$Variables = @{
    ComputerName    = "WebProdServer01.corporate.local"
    DurationMinutes = "60"
    Reason          = "Planned OS Patching via iRequest"
}
```

# 3. Target URL targeting the pipeline trigger endpoint

```powershell
$Uri = "$GitLabUrl/api/v4/projects/$ProjectId/trigger/pipeline"
```

# 4. Fire the command

```powershell
$Body = @{
    token     = $TriggerToken
    ref       = "main"
    variables = $Variables
}
Invoke-RestMethod -Uri $Uri -Method Post -Body $Body -ContentType 'application/x-www-form-urlencoded'
```

------------------------------

## Step 3: Raw Curl Format (If iRequest cannot use PowerShell)

If your corporate iRequest engine uses a standard linux-style webhook runner instead of native Windows PowerShell, it must execute this standard curl string to perform the exact same task:

```bash
curl -X POST "https://gitlab.example.com/api/v4/projects/1234/trigger/pipeline" \
     --data-urlencode "token=glptt-xxxxxxxxxxxxxxxxxxxxxxxxxx" \
     --data-urlencode "ref=main" \
     --data-urlencode "variables[ComputerName]=WebProdServer01.corporate.local" \
     --data-urlencode "variables[DurationMinutes]=60" \
     --data-urlencode "variables[Reason]=Planned OS Patching via iRequest"
```

## ⚠️ Critical Security Notice for SCOM Scripts

Because CI runners execute scripts, ensure the runner service account has appropriate permissions to communicate with SCOM management groups. If your script throws an "Unauthorized" or "Cannot connect to Management Server" error when triggered via the API, you will need to configure the runner to execute as a Domain Service Account that has administrative rights inside your SCOM console.