[CmdletBinding()]
# Define variables
# INSTALL the GitHub CLI first (you should already have Git Bash installed)
# https://cli.github.com/

<#
    Required:
    Set a GitHub Classic PAT as an environment variable before running:

    Add to your powershell profile with these 2 commands:
    notepad $PROFILE
    $env:GITHUB_TOKEN = "your-token-here"
#>

# Configuration - Edit these values
$repositoryName = "owner/repository-name"
$variablesToSet = @(
    @{
        Name = "vmf_specific_vantage_event_url"
        Dev  = "https://vanderbiltmortgage--vmfdev1.sandbox.my.salesforce.com/services/data/v60.0/sobjects/VMF_LOS_Event__e"
        Itg  = "https://vanderbiltmortgage--qa.sandbox.my.salesforce.com/services/oauth2/token"
        Qua  = "https://vanderbiltmortgage--partial.sandbox.my.salesforce.com/services/oauth2/token"
        Prod = "https://vanderbiltmortgage.my.salesforce.com/services/oauth2/token"
    }
    # @{
    #     Name = "DATABASE_HOST"
    #     Dev  = "dev-db.local"
    #     Itg  = "itg-db.local"
    #     Qua  = "qua-db.local"
    #     Prod = "prod-db.cloud"
    # }
)

# Verify token is set
if ($env:GITHUB_TOKEN) {
    "Token is set ✅"
}
else {
    "Token is NOT set ❌"
    exit 1
}

# Set GitHub API token
$headers = @{ 
    Authorization = "token $env:GITHUB_TOKEN" 
    Accept        = "application/vnd.github+json"
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "GitHub Environment Variables Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Repository: $repositoryName" -ForegroundColor Yellow
Write-Host ""

$totalSuccess = 0
$totalFailure = 0

# Process each variable
foreach ($variable in $variablesToSet) {
    $variableName = $variable.Name
    $environments = @{
        "dev"  = $variable.Dev
        "itg"  = $variable.Itg
        "qua"  = $variable.Qua
        "prod" = $variable.Prod
    }

    Write-Host ""
    Write-Host "Processing variable: $variableName" -ForegroundColor Yellow
    Write-Host "----------------------------------------" -ForegroundColor Yellow

    $successCount = 0
    $failureCount = 0

    # Set variables for each environment
    foreach ($env in $environments.GetEnumerator()) {
        $envName = $env.Key
        $envValue = $env.Value

        Write-Host "Setting variable in [$envName] environment..." -ForegroundColor Magenta

        try {
            # Set the variable using GitHub API
            $url = "https://api.github.com/repos/$repositoryName/environments/$envName/variables"
            $body = @{
                name  = $variableName
                value = $envValue
            } | ConvertTo-Json

            $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ErrorAction Stop
            
            Write-Host "  ✓ Successfully set $variableName in $envName" -ForegroundColor Green
            $successCount++
        }
        catch {
            Write-Host "  ✗ Failed to set $variableName in $envName : $($_.Exception.Message)" -ForegroundColor Red
            $failureCount++
        }
    }

    $totalSuccess += $successCount
    $totalFailure += $failureCount

    Write-Host ""
    Write-Host "Verification Phase" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Cyan

    # Verify variables were set
    foreach ($env in $environments.GetEnumerator()) {
        $envName = $env.Key
        $envValue = $env.Value

        Write-Host "Verifying [$envName] environment..." -ForegroundColor Magenta

        try {
            # Get the variable value using GitHub API
            $url = "https://api.github.com/repos/$repositoryName/environments/$envName/variables/$variableName"
            $response = Invoke-RestMethod -Uri $url -Headers $headers -ErrorAction Stop

            if ($response.value -eq $envValue) {
                Write-Host "  ✓ Verified: $variableName = $($response.value)" -ForegroundColor Green
            }
            else {
                Write-Host "  ⚠ Mismatch in $envName" -ForegroundColor Yellow
                Write-Host "    Expected: $envValue" -ForegroundColor Yellow
                Write-Host "    Got: $($response.value)" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "  ✗ Failed to verify $variableName in $envName : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
