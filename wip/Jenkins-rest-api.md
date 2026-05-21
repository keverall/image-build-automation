Yes, absolutely. Using the Jenkins REST API to bridge web-based ticketing systems (like iRequest, ServiceNow, or Jira) with automated backend PowerShell scripts is a very standard enterprise workflow.
Because your server is running inside a strict corporate network with no internet access, this API architecture is actually the best solution. It allows external applications to trigger automation inside your isolated zone safely.
Here is the exact architecture and code required to make this work.
------------------------------
## Step 1: Create a "Parameterized" Jenkins Job
Before sending data via API, you must configure a Jenkins job that knows how to accept incoming data from iRequest and pass it into a PowerShell script.

   1. On your Jenkins dashboard, click New Item, type a name (e.g., iRequest-Automation), select Pipeline or Freestyle project, and click OK.
   2. Check the box that says "This project is parameterized".
   3. Click Add Parameter $\rightarrow$ String Parameter.
   * Name: RequestID
   4. Click Add Parameter $\rightarrow$ String Parameter again.
   * Name: TargetServer
   5. Scroll down to the Build Steps section, click Add build step, and select Windows PowerShell.
   6. Paste your execution script block, using the variables exactly like this:
   
   Write-Output "Processing iRequest ticket: $env:RequestID"
   Write-Output "Target Execution Node: $env:TargetServer"# Call your custom enterprise module or code here
   Get-Process -ComputerName $env:TargetServer
   
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
$Username = "your_jenkins_admin"
$Token = "1130d7b27xxxxxxxxxxxxxxxxxxxxxxxxx" # Your copied token
$Pair = "${Username}:${Token}"
$Bytes = [System.Text.Encoding]::ASCII.GetBytes($Pair)
$Base64 = [Convert]::ToBase64String($Bytes)
$Headers = @{ Authorization = "Basic $Base64" }
# 2. Define the payload parameters matching your Jenkins job settings
$Body = @{
    RequestID    = "REQ0012345"
    TargetServer = "C-Server-Prod01"
}
# 3. Construct the specific remote build trigger URL
$JenkinsURL = "http://localhost:8080/job/iRequest-Automation/buildWithParameters"
# 4. Fire the web request to Jenkins
Invoke-RestMethod -Uri $JenkinsURL -Method Post -Headers $Headers -Body $Body

## How the workflow passes data:

   1. An end-user fills out an iRequest form requesting a task (e.g., provisioning a resource or restarting a service).
   2. The iRequest workflow engine executes the HTTP POST script natively behind the scenes.
   3. Your local Jenkins instance accepts the payload on port 8080, instantly extracts REQ0012345 and C-Server-Prod01, maps them into local environment variables, and launches your backend PowerShell script to do the work.

Does your corporate iRequest software run on a different server, or is it running on this same local machine? If it's on a different server, let me know so we can ensure your corporate firewalls allow traffic from the iRequest server IP to port 8080!

