[CmdletBinding()]

<#
.SYNOPSIS
    Query GitHub environment variables across multiple environments.

.DESCRIPTION
    This script retrieves and displays environment variables from GitHub repository
    environments using the GitHub REST API. No CLI tools required.

.PREREQUISITES
    - GitHub Classic PAT set as environment variable

.SETUP
    Set a GitHub Classic PAT as an environment variable:
    
    Add to your PowerShell profile:
        notepad $PROFILE
        $env:GITHUB_TOKEN = "your-token-here"

.NOTES
    - Configure $repositoryName and $environments variables below before running
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
