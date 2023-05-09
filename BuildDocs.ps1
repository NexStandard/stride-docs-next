param (
    [switch]$API
)

# To Do fix, GitHub references, fix sitemap links to latest/en/

function Read-LanguageConfigurations {
    return Get-Content 'languages.json' -Encoding UTF8 | ConvertFrom-Json
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

        # Copy all files from en folder to the selected language folder, this way we can keep en files that are not translated
        Copy-Item en/* -Recurse $langFolder -Force

        # Get all translated files from the selected language folder
        $posts = Get-ChildItem $langFolder/manual/*.md -Recurse -Force

        Write-Host "Start write files:"

        # Mark files as not translated if they are not in the toc.md file
        Foreach ($post in $posts)
        {
            if($post.ToString().Contains("toc.md")) {
                continue;
            }

            $data = Get-Content $post -Encoding UTF8
            $i = 0;
            Foreach ($line in $data)
            {
                $i++
                if ($line.length -le 0)
                {
                    Write-Host $post

                    $data[$i-1]="> [!WARNING]`r`n" + "> " + $selectedLanguage.notTranslatedMessage + "`r`n"

                    $data | Out-File -Encoding UTF8 $post

                    break
                }
            }
        }

        Write-Host "End write files"

        # overwrite en manual page with translated manual page
        if (Test-Path ($selectedLanguage.language + "/index.md")) {
            Copy-Item ($selectedLanguage.language + "/index.md") $langFolder -Force
        }
        else {
            Write-Host -ForegroundColor Yellow "Warning: $($selectedLanguage.language)/index.md not found. English version will be used."
        }

        # overwrite en manual pages with translated manual pages
        if (Test-Path ($selectedLanguage.language + "/manual")) {
            Copy-Item ($selectedLanguage.language + "/manual") -Recurse -Destination $langFolder -Force
        }
        else {
            Write-Host -ForegroundColor Yellow "Warning: $($selectedLanguage.language)/manual not found."
        }

        # we copy the docfx.json file from en folder to the selected language folder, so we can keep the same settings and maitain just one docfx.json file
        Copy-Item en/docfx.json $langFolder -Force

        (Get-Content $langFolder/docfx.json) -replace "_site/en","_site/$($selectedLanguage.language)" | Set-Content -Encoding UTF8 $langFolder/docfx.json

        docfx build $langFolder\docfx.json

        Remove-Item $langFolder -recurse

        PostProcessingDocFxDocUrl -selectedLanguage $selectedLanguage

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

# docfx generates GitHub link based on the temp _tmp folder, which we need to correct to correct
# GitHub links. This function does that.
function PostProcessingDocFxDocUrl {
    param (
        $selectedLanguage
    )

    $posts = Get-ChildItem "$($selectedLanguage.language)/*.md" -Recurse -Force

    # Get a list of all HTML files in the _site/<language> directory
    $htmlFiles = Get-ChildItem _site/$($selectedLanguage.language)/*.html -Recurse

    # Get the relative paths of the posts
    $relativePostPaths = $posts | ForEach-Object { $_.FullName.Replace((Resolve-Path $selectedLanguage.language).Path + '\', '') }

    Write-Host -ForegroundColor Yellow "Post-processing docfx:docurl in $($htmlFiles.Count) files..."

    $processedCount = 0

    foreach ($htmlFile in $htmlFiles) {

        # Get the relative path of the HTML file
        $relativeHtmlPath = $htmlFile.FullName.Replace((Resolve-Path "_site/$($selectedLanguage.language)").Path + '\', '').Replace('.html', '.md')

        # Read the content of the HTML file
        $content = Get-Content $htmlFile

        # Define a regex pattern to match the meta tag with name="docfx:docurl"
        $pattern = '(<meta name="docfx:docurl" content=".*?)(/' + $selectedLanguage.language + '_tmp/)(.*?">)'

        # Define a regex pattern to match the href attribute in the <a> tags
        $pattern2 = '(<a href=".*?)(/' + $selectedLanguage.language + '_tmp/)(.*?">)'

        # Check if the HTML file is from the $posts collection
        if ($relativePostPaths -contains $relativeHtmlPath) {
            # Replace /<language>_tmp/ with /<language>/ in the content
            $content = $content -replace $pattern, "`${1}/$($selectedLanguage.language)/`${3}"
            $content = $content -replace $pattern2, "`${1}/$($selectedLanguage.language)/`${3}"
        } else {
            # Replace /<language>_tmp/ with /en/ in the content
            $content = $content -replace $pattern, '${1}/en/${3}'
            $content = $content -replace $pattern2, '${1}/en/${3}'
        }

        # Write the updated content back to the HTML file
        $content | Set-Content -Encoding UTF8 $htmlFile

        $processedCount++

        Write-Progress -Activity "Processing files" -Status "$processedCount of $($htmlFiles.Count) processed" -PercentComplete (($processedCount / $htmlFiles.Count) * 100)

    }

    Write-Host -ForegroundColor Green "Post-processing completed."
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