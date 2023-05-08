param (
    [switch]$API
)

# To Do fix, GitHub references, fix sitemap links to latest/en/

function Read-LanguageConfigurations {
    return Get-Content 'languages.json' | ConvertFrom-Json
}

function Remove-BuildLogFile {
    if (Test-Path build.log) {
        Remove-Item build.log
    }
}

function Start-LogTranscript {
    Start-Transcript -Path build.log
}

function GetUserInput {
    Write-Host ""
    Write-Host -ForegroundColor Cyan "Please select an option:"
    Write-Host ""
    Write-Host -ForegroundColor Yellow "  [en] Build English documentation"
    foreach ($lang in $languages) {
        if ($lang.enabled -and -not $lang.isPrimary) {
            Write-Host -ForegroundColor Yellow "  [$($lang.language)] Build $($lang.name) documentation"
        }
    }
    Write-Host -ForegroundColor Yellow "  [all] Build documentation in all available languages"
    Write-Host -ForegroundColor Yellow "  [r] Run local website"
    Write-Host -ForegroundColor Yellow "  [c] Cancel"
    Write-Host ""

    return Read-Host -Prompt "Your choice"
}

function AskIncludeAPI {
    Write-Host ""
    Write-Host -ForegroundColor Cyan "Do you want to include API?"
    Write-Host ""
    Write-Host -ForegroundColor Yellow "  [Y] Yes"
    Write-Host -ForegroundColor Yellow "  [N] No"
    Write-Host ""

    return (Read-Host -Prompt "Your choice (Y/N)").ToLower() -eq "y"
}

function Copy-ExtraItems {
    Copy-Item en/ReleaseNotes/ReleaseNotes.md _site/en/ReleaseNotes/
}

function HandleCancel {
    Write-Host -ForegroundColor Red "Operation canceled by user."
    Stop-Transcript
    Read-Host -Prompt "Press ENTER key to exit..."
    exit
}

function RunLocalWebsite {
    Write-Host -ForegroundColor Green "Running local website..."
    Write-Host -ForegroundColor Green "Navigate manually to non English website, if you didn't build English documentation."
    Stop-Transcript
    New-Item -ItemType Directory -Force -Path _site | Out-Null
    Set-Location _site
    Start-Process -FilePath "http://localhost:8080/en/index.html"
    docfx serve
    Set-Location ..
    exit
}

function GenerateAPIDoc {
    Write-Host -ForegroundColor Green "Generating API documentation..."

    # Build metadata from C# source, docfx runs dotnet restore
    docfx metadata en/docfx.json

    if ($LastExitCode -ne 0)
    {
        Write-Host -ForegroundColor Red "Failed to generate API metadata"
        exit $LastExitCode
    }
}

function EraseAPIDoc {
    if (Test-Path en/api/.manifest) {
        Write-Host -ForegroundColor Green "Erasing API documentation..."
        Remove-Item en/api/*yml -recurse
        Remove-Item en/api/.manifest
    }
}

function BuildEnglishDoc {
    Write-Host -ForegroundColor Yellow "Start building English documentation."

    # Output to both build.log and console
    docfx build en\docfx.json

    if ($LastExitCode -ne 0)
    {
        Write-Host -ForegroundColor Red "Failed to build English documentation"
        exit $LastExitCode
    }
}

function BuildNonEnglishDoc {
    param (
        $selectedLanguage
    )

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
}

function BuildAllLanguagesDocs {
    param (
        [array]$languages
    )

    foreach ($lang in $languages) {
        if ($lang.enabled -and -not $lang.isPrimary) {

            BuildNonEnglishDoc -selectedLanguage $lang

        }
    }
}

# Main script execution starts here

$languages = Read-LanguageConfigurations

Remove-BuildLogFile

Start-LogTranscript

# If $API parameter is not provided, ask the user
if (-not $API)
{
    $userInput = GetUserInput

    $enLanguage = $userInput -eq "en"
    $allLanguages = $userInput -eq "all"
    $runLocalWebsite = $userInput -eq "r" -or $userInput -eq "R"
    $cancel = $userInput -eq "c" -or $userInput -eq "C"

    # Check if user input matches any non-English language build
    $selectedLanguage = $languages | Where-Object { $_.language -eq $userInput -and $_.enabled -and -not $_.isPrimary }

    if ($selectedLanguage)
    {
        $buildSelectedLanguage = $true
    }

    # Ask if the user wants to include API
    if ($enLanguage -or $allLanguages -or $buildSelectedLanguage) {
        $API = AskIncludeAPI
    }
}

if ($cancel)
{
    HandleCancel
}

if ($runLocalWebsite)
{
    RunLocalWebsite
}

# Generate API doc
if ($API)
{
    GenerateAPIDoc
}
else
{
    EraseAPIDoc
}

Write-Host -ForegroundColor Green "Generating documentation..."
Write-Host ""
Write-Warning "Note that when building docs without API, you will get UidNotFound warnings and invalid references warnings"
Write-Host ""

if ($enLanguage -or $allLanguages)
{
   BuildEnglishDoc
}

# Do we need this?
# Copy-ExtraItems

# Build non-English language if selected or build all languages if selected
if ($allLanguages) {
    BuildAllLanguagesDocs -languages $languages
} elseif ($selectedLanguage) {
    BuildNonEnglishDoc -selectedLanguage $selectedLanguage
}

Stop-Transcript

Read-Host -Prompt "Press any ENTER to exit..."