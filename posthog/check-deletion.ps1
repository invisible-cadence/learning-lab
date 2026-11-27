# Checks PostHog person-deletion status via the API.
# Reads secrets from posthog/.env (git-ignored). Never put the key in this file.
#
# posthog/.env must contain:
#   POSTHOG_PERSONAL_API_KEY=phx_...
#   POSTHOG_PROJECT_ID=12345
#
# Run from the posthog folder:
#   powershell -ExecutionPolicy Bypass -File .\check-deletion.ps1
#   powershell -ExecutionPolicy Bypass -File .\check-deletion.ps1 -Status pending

param(
  [string]$Status = ""   # "", "pending" or "completed"
)

$envFile = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $envFile)) { throw "Missing $envFile" }

$config = @{}
foreach ($line in Get-Content $envFile) {
  if ($line -match '^\s*([A-Za-z_]+)\s*=\s*(.*)\s*$') { $config[$matches[1]] = $matches[2] }
}

$key = $config["POSTHOG_PERSONAL_API_KEY"]
$projectId = $config["POSTHOG_PROJECT_ID"]
if (-not $key -or -not $projectId) { throw "Set POSTHOG_PERSONAL_API_KEY and POSTHOG_PROJECT_ID in .env" }

# EU cloud. The private API lives on eu.posthog.com (not eu.i.posthog.com, which is for sending events).
$url = "https://eu.posthog.com/api/projects/$projectId/persons/deletion_status/"
if ($Status) { $url += "?status=$Status" }

$response = Invoke-RestMethod -Uri $url -Headers @{ Authorization = "Bearer $key" }
$response | ConvertTo-Json -Depth 10
