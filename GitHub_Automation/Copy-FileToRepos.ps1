[CmdletBinding()]

<#
.SYNOPSIS
    Copy a file to multiple GitHub repositories and create pull requests.

.DESCRIPTION
    This script clones multiple repositories, copies a specified file to each one,
    commits the change to a new branch, and creates a pull request for review.
    It can target repositories from a GitHub team or personal repositories.

.PREREQUISITES
    - Git CLI: https://git-scm.com/downloads
    - GitHub CLI: https://cli.github.com/
    - GitHub Classic PAT set as environment variable

.SETUP
    Set a GitHub Classic PAT as an environment variable:
    
    Add to your PowerShell profile:
        notepad $PROFILE
        $env:GITHUB_TOKEN = "your-token-here"

.NOTES
    Configure the variables below before running:
    - $org, $teamSlug, $targetDir, $sourceFile, etc.
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

# Initialize counter for progress tracking
$loopCount = 1

# Loop through each repository and apply changes
foreach ($repo in $allRepos) {
    # Extract repo name and construct paths
    $repoName = $repo.full_name
    $shortRepoName = $repo.name
    Write-Host "\nUpdating $repoName ($loopCount of $($allRepos.Count))"

    # Clone the repository to the target directory
    $fullRepoPath = $repo.clone_url
    $repoPath = Join-Path $targetDir $shortRepoName
    git clone $fullRepoPath $repoPath

    # Change to repo directory
    Set-Location $repoPath

    # Determine which base branch exists (develop, main, or master)
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
        $command = "gh repo edit $org/$repoName --remove-topic my-topic --remove-topic my-topic-2"
        Invoke-Expression $command
    }
    
    
    # Add Topics to repo
    $command = "gh repo edit $org/$repoName --add-topic my-topic --add-topic my-topic-2"
    Invoke-Expression $command 

    # Return to original directory
    Set-Location $targetDir

    # Delete the local repository
    Remove-Item -Recurse -Force $repoPath
    
    # Increment loop counter
    $loopCount++
}