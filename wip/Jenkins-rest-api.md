# Jenkins REST API to bridge web-based ticketing systems 

(like iRequest, ServiceNow, or Jira) with automated backend PowerShell scripts is a very standard enterprise workflow.
Because this server is running inside a strict corporate network with no internet access, this API architecture is actually the best solution. It allows external applications to trigger automation inside your isolated zone safely.
Here is the exact architecture and code required to make this work.
------------------------------
## Step 1: Create a "Parameterized" Jenkins Job

Before sending data via API, you must configure a Jenkins job that knows how to accept incoming data from iRequest and pass it into a PowerShell script.

   1. On your Jenkins dashboard, click New Item, type a name (e.g., iRequest-Automation), select Pipeline or Freestyle project, and click OK.
   2. Check the box that says "This project is parameterized".
   3. Click Add Parameter $\rightarrow$ String Parameter.Name: RequestID
   4. Click Add Parameter $\rightarrow$ String Parameter again. * Name: TargetServer
   5. Scroll down to the Build Steps section, click Add build step, and select Windows PowerShell.
   6. Paste your execution script block, using the variables exactly like this:

   ``` YAML
   Write-Output "Processing iRequest ticket: $env:RequestID"
   Write-Output "Target Execution Node: $env:TargetServer"# Call your custom enterprise module or code here
   Get-Process -ComputerName $env:TargetServer
   ```

   7. Click Save.

------------------------------

## Step 2: Generate an API Token

Jenkins requires an API authentication token instead of your raw corporate Active Directory password for programmatic access.

   1. In the top right corner of Jenkins, click your Username $\rightarrow$ Configure.
   2. Scroll down to the API Token section.
   3. Click Add new Token $\rightarrow$ name it iRequest-Link $\rightarrow$ click Generate.
   4. Copy the token string immediately (you will not be able to see it again).

------------------------------

## Step 3: Triggering Jenkins from iRequest (The API Call)

Your corporate iRequest tool just needs to send an HTTP POST request to your local Jenkins server web port.
If iRequest utilizes a PowerShell engine under the hood to send outbound API webhooks, it would execute this payload to kick off the automation build:

# 1. Define authentication headers (using your username and generated token)

```YAML
$Username = "your_jenkins_admin"
$Token = "1130d7b27xxxxxxxxxxxxxxxxxxxxxxxxx" # Your copied token
$Pair = "${Username}:${Token}"
$Bytes = [System.Text.Encoding]::ASCII.GetBytes($Pair)
$Base64 = [Convert]::ToBase64String($Bytes)
$Headers = @{ Authorization = "Basic $Base64" }
```

# 2. Define the payload parameters matching your Jenkins job settings

``` YAML
$Body = @{
    RequestID    = "REQ0012345"
    TargetServer = "C-Server-Prod01"
}
```

# 3. Construct the specific remote build trigger URL

``` YAML
$JenkinsURL = "http://localhost:8080/job/iRequest-Automation/buildWithParameters"
Invoke-RestMethod -Uri $JenkinsURL -Method Post -Headers $Headers -Body $Body
```

## How the workflow passes data:

   1. An end-user fills out an iRequest form requesting a task (e.g., provisioning a resource or restarting a service).
   2. The iRequest workflow engine executes the HTTP POST script natively behind the scenes.
   3. Your local Jenkins instance accepts the payload on port 8080, instantly extracts REQ0012345 and C-Server-Prod01, maps them into local environment variables, and launches your backend PowerShell script to do the work.

Does your corporate iRequest software run on a different server, or is it running on this same local machine? If it's on a different server, let me know so we can ensure your corporate firewalls allow traffic from the iRequest server IP to port 8080!

## To trigger your specific SCOM script through the Jenkins REST API from iRequest, you must use the buildWithParameters endpoint [1].

This allows iRequest to send a web request that forces Jenkins to run your local script file (C:\Users\98253\repos\image-build-automation\src\powershell\Automation\Public\Set-MaintenanceMode.ps1) while passing variable data (like Computer Name, Duration, and Reason) dynamically into it.
Here is the exact API configuration and execution commands to set this up:

## Step 1: Configure Your Parameterized Job in Jenkins

First, your Jenkins job must be configured to receive parameters from iRequest and forward them directly to your script file.

   1. Create a pipeline or freestyle job named SCOM-Maintenance-Mode.
   2. Check "This project is parameterized".
   3. Add three String Parameters with these exact names: 
      1. ComputerName (The server entering maintenance mode)
      2. DurationMinutes (How long to silence alerts)
      3. Reason (The ticket reference or justification)
   4. In the Build Steps, add a Windows PowerShell block and paste this execution line:#

   ```YAML
   & "C:\Users\98253\repos\image-build-automation\src\powershell\Automation\Public\Set-MaintenanceMode.ps1" -ComputerName "$env:ComputerName" -DurationMinutes "$env:DurationMinutes" -Reason "$env:Reason"
   ```

------------------------------

## Step 2: The iRequest API Command (PowerShell Payload)

When an iRequest form is submitted, the iRequest workflow engine must fire this specific raw HTTP POST command to pass the server details over to Jenkins.
Replace YOUR_JENKINS_USER and YOUR_API_TOKEN with your actual Jenkins credentials:

# 1. Setup secure credentials (Username + Jenkins API Token)

``` YAML
$User = "YOUR_JENKINS_USER"
$Token = "YOUR_API_TOKEN"
$AuthInfo = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("${User}:${Token}"))
$Headers = @{ Authorization = "Basic $AuthInfo" }
```

# 2. Map data fields straight from the submitted iRequest form

``` YAML
$Body = @{
    ComputerName    = "WebProdServer01.corporate.local"
    DurationMinutes = "60"
    Reason          = "Planned OS Patching via iRequest"
}
```

# 3. Target URL targeting the job's parameterized trigger endpoint

``` YAML
$JenkinsURL = "http://localhost:8080/job/SCOM-Maintenance-Mode/buildWithParameters"
```

# 4. Fire the command

``` YAML
Invoke-RestMethod -Uri $JenkinsURL -Method Post -Headers $Headers -Body $Body
```

------------------------------

## Step 3: Raw Curl Format (If iRequest cannot use PowerShell)

If your corporate iRequest engine uses a standard linux-style webhook runner instead of native Windows PowerShell, it must execute this standard curl string to perform the exact same task:

``` YAML
curl -X POST "http://localhost:8080/job/SCOM-Maintenance-Mode/buildWithParameters" \
     -u "YOUR_JENKINS_USER:YOUR_API_TOKEN" \
     --data-urlencode "ComputerName=WebProdServer01.corporate.local" \
     --data-urlencode "DurationMinutes=60" \
     --data-urlencode "Reason=Planned OS Patching via iRequest"
```

## ⚠️ Critical Security Notice for SCOM Scripts

Because Jenkins runs as a local background process on your machine, it might execute scripts under the LocalSystem context. SCOM management groups require domain credentials to modify server alerts.
If your script throws an "Unauthorized" or "Cannot connect to Management Server" error when triggered via the API, you will need to go to your Windows Services manager, double-click the Jenkins service, switch to the Log On tab, and explicitly change it to run as a Domain Service Account that has administrative rights inside your SCOM console.
When you run the API command, does the job trigger successfully on the Jenkins dashboard? If the script launches but fails to communicate with SCOM, let me know so we can adjust the execution permissions or execution policy flags!
