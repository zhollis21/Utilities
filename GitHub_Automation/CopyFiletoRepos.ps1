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

$targetDir = "C:\Dev\Temp"              # Temporary directory to clone repos in
$newBranch = "feature/auto-codeowner"   # Feature branch used to commit changes to
$sourceFile = "C:\Dev\CODEOWNERS"       # Source File to copy to every repo
$destinationFileName = "CODEOWNERS"     # File name to use in the repo
$baseBranch = "main"                    # Branch used to fork and target pull requests
$title = "CODEOWNERS"                   # Title of the pull requests
$body = "Add New CODEOWNERS File"       # Body of the pull requests
$reviewers = "Person1,Person2,Person3"  # Comma separated list of reviewers (GitHub username(s)) 


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

# Get All Repos
$allRepos = @()
$page = 1
$perPage = 100
do {
    #$url = "https://api.github.com/orgs/$org/teams/$teamSlug/repos?per_page=$perPage&page=$page" # Pull an orgs repos by team
    $url = "https://api.github.com/user/repos?affiliation=owner&per_page=$perPage&page=$page" # Pull my personal repos

    $response = Invoke-RestMethod -Uri $url -Headers $headers

    $allRepos += $response
    $page++
} while ($response.Count -eq $perPage)

if (!$allRepos) {
    Write-Host "`nNo Repos Returned" -ForegroundColor Red
    exit 1
}

# Confirm how many we got
Write-Host "Total repos retrieved: $($allRepos.Count)"

# Loop through each repository
foreach ($repo in $allRepos) {
    # Extract repo name
    $repoName = $repo.full_name
    Write-Host "`nUpdating $repoName ($loopCount of $($allRepos.Count))"

    # Clone the repository
    git clone $fullRepoPath $repo

    # Change to repo directory
    Set-Location $repoPath

    $remoteBranches = git branch -r

    if ($remoteBranches -match "origin/develop") {
        $baseBranch = "develop"
    }
    elseif ($remoteBranches -match "origin/main") {
        $baseBranch = "main"
    }
    else {
        $baseBranch = "master"
    }

    # Checkout develop and create new branch
    git checkout $baseBranch
    git pull origin $baseBranch
    git checkout -b $newBranch
    
    # Create .github folder
    $githubFolderPath = Join-Path $repoPath ".github"
    New-Item -Path $githubFolderPath -ItemType Directory

    # Copy the file
    Copy-Item -Path $sourceFile -Destination (Join-Path $githubFolderPath $destinationFileName) -Force

    # Commit the changes
    git add ".github/$destinationFileName"
    git commit -m "Add $destinationFileName to $newBranch"
    git push origin $newBranch 
    
    # Create the pull request using GitHub CLI
    $command = "gh pr create --base $baseBranch --head $newBranch --title `"$title`" --body `"$body`" --reviewer $reviewers"
    Invoke-Expression $command
    
    <# 
    **********************************************************************************************************
    If we have to re-run the script we'll need to remove the topics so we don't double-up
    **********************************************************************************************************
    #>
    if ($rerunning) {
        # Remove Topics on repo
        $command = "gh repo edit Pipeline-1-0/$repoName --remove-topic vmf --remove-topic originations"
        Invoke-Expression $command
    }
    
    
    # Add Topics to repo
    $command = "gh repo edit Pipeline-1-0/$repoName --add-topic vmf --add-topic originations"
    Invoke-Expression $command 

    # Return to original directory
    Set-Location $targetDir

    # Delete the local repository
    Remove-Item -Recurse -Force $repoPath
}