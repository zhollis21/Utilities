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
$environments = @("dev", "itg", "qua", "prod")

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
Write-Host "GitHub Environment Variables Query" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Repository: $repositoryName" -ForegroundColor Yellow
Write-Host ""

foreach ($envName in $environments) {
    Write-Host ""
    Write-Host "Environment: [$envName]" -ForegroundColor Yellow
    Write-Host "----------------------------------------" -ForegroundColor Yellow

    try {
        $url = "https://api.github.com/repos/$repositoryName/environments/$envName/variables"
        $response = Invoke-RestMethod -Uri $url -Headers $headers -ErrorAction Stop

        if ($response.variables.Count -eq 0) {
            Write-Host "  No variables found" -ForegroundColor Gray
        }
        else {
            foreach ($var in $response.variables) {
                Write-Host "  • $($var.name) = $($var.value)" -ForegroundColor Green
            }
        }
    }
    catch {
        Write-Host "  ✗ Failed to query variables: $($_.Exception.Message)" -ForegroundColor Red
    }
}
