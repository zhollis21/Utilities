$repo = "/my-repo.git"
$baseBranch = "develop"

# Counters
$deletedCount = 0
$skippedCount = 0

# Define the GitHub repository URL and local path
$repobase = "git@github.com:MyOrg"
$repoUrl = $repobase + $repo
$repoName = ($repo -split "/")[-1] -replace ".git", ""
$localPath = Join-Path "C:\GitHub" $repoName

# Clone the repository

if (-Not (Test-Path $localPath)) {
    git clone $repoUrl $localPath
}

Set-Location $localPath

# Fetch all branches
git fetch --all

# Checkout branch and make sure it's up to date
git checkout $baseBranch
git pull origin $baseBranch

# Get the list of remote feature branches (assuming naming convention 'feature/*')
$featureBranches = git branch -r | Where-Object { $_ -match "feature/" }


$branchNumber = 1
$branchCount = $featureBranches.Count

foreach ($branch in $featureBranches) {
    $shortName = ($branch -replace "origin/", "").Trim()

    # Get commits in the feature branch not in base (by SHA)
    $featureCommits = git log --pretty=format:"%s" origin/$baseBranch..origin/$shortName

    # Skip if no commits — might be already merged or empty
    if (-not $featureCommits) {
        Write-Host "$shortName has no unique commits." -ForegroundColor Green
        $deletedCount++
        $branchNumber++;
        continue
    }

    $lastCommitDate = git log -1 --format=%ci origin/$shortName
    if ([datetime]$lastCommitDate -lt (Get-Date).AddMonths(-12)) {
        Write-Host "$shortName is older than 12 months — skipping." -ForegroundColor DarkGreen
        $deletedCount++
        $branchNumber++;
        continue
    }

    # Now get all commit messages in the base branch (develop)
    $baseMessages = git log origin/$baseBranch --pretty=format:"%s"

    # Check how many commit messages from the feature branch appear in the base
    $matchCount = 0
    foreach ($msg in $featureCommits) {
        if ($baseMessages -match [regex]::Escape($msg)) {
            $matchCount++
        }
    }

    $total = $featureCommits.Count
    $percent = ($matchCount / $total) * 100

    if ($percent -ge 80) {
        Write-Host "$shortName appears to be merged ($percent% commit match)." -ForegroundColor Green
        $deletedCount++
    }
    else {
        Write-Host "$shortName likely not merged ($percent% match)." -ForegroundColor Yellow
        $skippedCount++
    }

    if ($branchNumber % 10 -eq 0) {
        Write-Host "Processed $branchNumber of $branchCount branches so far..." -ForegroundColor Cyan
    }

    $branchNumber++;
}


Write-Host "`nSummary:"
Write-Host "Total not merged into $baseBranch : $skippedCount"
Write-Host "Total merged into $baseBranch : $deletedCount"