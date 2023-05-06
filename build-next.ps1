param (
    [switch]$API
)

# Read language configurations from JSON file
$languages = Get-Content 'languages.json' | ConvertFrom-Json

# Remove build.log file
If(Test-Path build.log)
{
    Remove-Item build.log
}

# Write the output to build.log file
Start-Transcript -Path build.log

# If $API parameter is not provided, ask the user
if (-not $API)
{
    Write-Host -ForegroundColor Cyan "Please select an option:"
    Write-Host -ForegroundColor Yellow "  [Y] Include API"
    Write-Host -ForegroundColor Yellow "  [N] Exclude API"
    Write-Host -ForegroundColor Yellow "  [R] Run local website"
    Write-Host -ForegroundColor Yellow "  [C] Cancel"
    foreach ($lang in $languages)
    {
        if ($lang.enabled -and -not $lang.isPrimary)
        {
            Write-Host -ForegroundColor Yellow "  [$($lang.language)] Build $($lang.name) documentation"
        }
    }

    $userInput = Read-Host -Prompt "Your choice (y/n/r/c/build)"
    $API = $userInput -eq "y" -or $userInput -eq "Y"
    $runLocalWebsite = $userInput -eq "r" -or $userInput -eq "R"
    $cancel = $userInput -eq "c" -or $userInput -eq "C"

    # Check if user input matches any non-English language build
    $selectedLanguage = $languages | Where-Object { $_.language -eq $userInput -and $_.enabled -and -not $_.isPrimary }
    if ($selectedLanguage)
    {
        $buildSelectedLanguage = $true
    }
}

if ($cancel)
{
    Write-Host -ForegroundColor Red "Operation canceled by user."
    Stop-Transcript
    exit
}

if ($runLocalWebsite)
{
    Write-Host -ForegroundColor Green "Running local website..."
    Stop-Transcript
    New-Item -ItemType Directory -Force -Path _site | Out-Null
    Set-Location _site
    Start-Process -FilePath "http://localhost:8080/en/index.html"
    docfx serve
    Set-Location ..
    exit
}

# Generate API doc
if ($API)
{
    Write-Host -ForegroundColor Green "Generating API documentation..."

    # Build metadata from C# source, docfx runs dotnet restore
    docfx metadata en/docfx.json

    if ($LastExitCode -ne 0)
    {
        Write-Host -ForegroundColor Red "Failed to generate API metadata"
        exit $LastExitCode
    }
}
else
{
    If(Test-Path en/api/.manifest)
    {
        Write-Host -ForegroundColor Green "Erasing API documentation..."
        Remove-Item en/api/*yml -recurse
        Remove-Item en/api/.manifest
    }
}

Write-Host -ForegroundColor Green "Generating documentation..."

# Output to both build.log and console
docfx build en\docfx.json

if ($LastExitCode -ne 0)
{
    Write-Host -ForegroundColor Red "Failed to build doc"
    exit $LastExitCode
}

# Copy extra items
Copy-Item en/ReleaseNotes/ReleaseNotes.md _site/en/ReleaseNotes/


# Build non-English language if selected
if ($selectedLanguage -and $selectedLanguage.language -ne 'en') {
    Write-Host -ForegroundColor Yellow "Start building $($selectedLanguage.name) documentation."

    $langFolder = "$($selectedLanguage.language)_tmp"

    If(Test-Path $langFolder){
        Remove-Item $langFolder/* -recurse
    }
    Else{
        New-Item -Path $langFolder -ItemType "directory"
    }

    Copy-Item en/* -Recurse $langFolder -Force

    $posts = Get-ChildItem $langFolder/manual/*.md -Recurse -Force

    Write-Host "Start write files:"

    Foreach ($post in $posts)
    {
        if($post.ToString().Contains("toc.md")) {
            continue;
        }

        $data = Get-Content $post
        $i = 0;
        Foreach ($line in $data)
        {
            $i++
            if ($line.length -le 0)
            {
                Write-Host $post
                $data[$i-1]="<div class='doc-no-translated'/>"
                $data | out-file $post
                break
            }
        }
    }

    Write-Host "End write files"

    Copy-Item ($selectedLanguage.language + "/index.md") $langFolder -Force
    Copy-Item ($selectedLanguage.language + "/manual") -Recurse -Destination $langFolder -Force

    Copy-Item en/docfx.json $langFolder -Force

    (Get-Content $langFolder/docfx.json) -replace "_site/en","_site/$($selectedLanguage.language)" | Set-Content $langFolder/docfx.json

    docfx build $langFolder\docfx.json

    Remove-Item $langFolder -recurse

    if ($LastExitCode -ne 0)
    {
        Write-Host -ForegroundColor Red "Failed to build $($selectedLanguage.name) documentation"
        exit $LastExitCode
    }

    Write-Host -ForegroundColor Green "$($selectedLanguage.name) documentation built."
}

Stop-Transcript

Read-Host -Prompt "Press any key to exit..."