[CmdletBinding()]
# Define variables
# INSTALL the GitHub CLI first (you should alraedy have Git Bash installed)
# https://cli.github.com/

<#
    Required:
    Set a GitHub Classic PAT as an environment variable before running:

    Add to your powershell profile with these 2 commands:
    notepad $PROFILE
    $env:GITHUB_TOKEN = "your-token-here"
#>

$org = "zhollis21"
$teamSlug = "my-team"
$branchesToProtect = @("main", "master", "develop")
$teamsToGiveAccess = @("Team-Admins", "Team-Developers")

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

# Get All Repos Under Team
$allRepos = @()
$page = 1
$perPage = 100
do {
    $url = "https://api.github.com/orgs/$org/teams/$teamSlug/repos?per_page=$perPage&page=$page"
    $response = Invoke-RestMethod -Uri $url -Headers $headers

    $allRepos += $response
    $page++
} while ($response.Count -eq $perPage)

# Confirm how many we got
Write-Host "Total repos retrieved: $($allRepos.Count)"

$loopCount = 1
# Loop through each repository
foreach ($repo in $allRepos) {  

    $repoName = $repo.full_name
    Write-Host "`nUpdating $repoName ($loopCount of $($allRepos.Count))"

    ###########################
    # Only Allow Squash Merge #
    ###########################
    $command = "gh repo edit $repoName --enable-squash-merge=true --enable-merge-commit=false --enable-rebase-merge=false"
    Invoke-Expression $command


    ####################################
    # Remove and Re-Add Topics to repo #
    ####################################
    $command = "gh repo edit $repoName --remove-topic my-topic --remove-topic my-topic-2"
    Invoke-Expression $command

    $command = "gh repo edit $repoName --add-topic my-topic --add-topic my-topic-2"
    Invoke-Expression $command

    ######################################################
    # Add PR Requirement to master/main/develop branches #
    ######################################################
    Write-Host "🔒 Applying branch protection to $repoName" -ForegroundColor Cyan
    foreach ($branch in $branchesToProtect) {
        $url = "https://api.github.com/repos/$repoName/branches/$branch/protection"

        $protectionRules = @{            
            required_pull_request_reviews    = @{
                dismiss_stale_reviews           = $true
                require_code_owner_reviews      = $true
                required_approving_review_count = 1
                require_last_push_approval      = $false
            }
            required_status_checks           = @{
                strict   = $true    # Require branches to be up to date before merging
                contexts = @()      # No required status checks
            }
            restrictions                     = $null
            enforce_admins                   = $true
            allow_force_pushes               = $false            
            allow_deletions                  = $false   
            allow_fork_syncing               = $false
            block_creations                  = $false  
            lock_branch                      = $false      
            required_conversation_resolution = $false
            required_linear_history          = $false
        } | ConvertTo-Json -Depth 10

        try {
            Invoke-RestMethod -Uri $url -Method PUT -Headers $headers -Body $protectionRules -ContentType "application/json"
            Write-Host "✅ Protection applied for '$branch' on '$repoName'" -ForegroundColor Green
        }
        catch {
            Write-Warning "❌ Failed to apply protection to '$branch' on '$repoName': $($_.Exception.Message)"
        }
    }


    ###################
    # Add Other Teams #
    ###################
    foreach ($team in $teamsToGiveAccess) {
        $url = "https://api.github.com/orgs/$org/teams/$team/repos/$repoName"

        # Uncomment the below if you need to test your url
        # $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get

        $body = @{
            permission = "triage"
        } | ConvertTo-Json

        try {
            Invoke-RestMethod -Uri $url -Method PUT -Headers $headers -Body $body -ContentType "application/json"
            Write-Host "✅ Team '$teamSlug' granted 'triage' access to repo '$repoName'"
        }
        catch {
            Write-Warning "❌ Failed to set 'triage' permission for team '$team' on repo '$repoName': $($_.Exception.Message)"
        }
    }


    #################################
    # Set default branch to develop #
    #################################
    $command = "gh repo edit $repoName --default-branch develop"
    Invoke-Expression $command

    $loopCount++
}