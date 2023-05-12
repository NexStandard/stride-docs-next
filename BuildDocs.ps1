param (
    [switch]$BuildAll
)

# Define constants
$Settings = [PSCustomObject]@{
    LanguageJsonPath = ".\languages.json"
    TempDirectory = "_tmp"
    SiteDirectory = "_site"
    HostUrl = "http://localhost:8080/en/index.html"
    IndexFileName = "index.md"
    ManualFolderName = "manual"
}

# To Do fix, GitHub references, fix sitemap links to latest/en/

function Read-LanguageConfigurations {
    return Get-Content $Settings.LanguageJsonPath -Encoding UTF8 | ConvertFrom-Json
}

function Get-UserInput {
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

function Ask-IncludeAPI {
    Write-Host ""
    Write-Host -ForegroundColor Cyan "Do you want to include API?"
    Write-Host ""
    Write-Host -ForegroundColor Yellow "  [Y] Yes"
    Write-Host -ForegroundColor Yellow "  [N] No"
    Write-Host ""

    return (Read-Host -Prompt "Your choice (Y/N)").ToLower() -eq "y"
}

function Copy-ExtraItems {
    Copy-Item en/ReleaseNotes/ReleaseNotes.md "$($Settings.SiteDirectory)/en/ReleaseNotes/"
}

function Start-LocalWebsite {
    Write-Host -ForegroundColor Green "Running local website..."
    Write-Host -ForegroundColor Green "Navigate manually to non English website, if you didn't build English documentation."
    Stop-Transcript
    New-Item -ItemType Directory -Verbose -Force -Path $Settings.SiteDirectory | Out-Null
    Set-Location $Settings.SiteDirectory
    Start-Process -FilePath $Settings.HostUrl
    docfx serve
    Set-Location ..
    exit
}

function Generate-APIDoc {
    Write-Host -ForegroundColor Green "Generating API documentation..."

    # Build metadata from C# source, docfx runs dotnet restore
    docfx metadata en/docfx.json

    if ($LastExitCode -ne 0)
    {
        Write-Host -ForegroundColor Red "Failed to generate API metadata"
        exit $LastExitCode
    }
}

function Remove-APIDoc {
    if (Test-Path en/api/.manifest) {
        Write-Host -ForegroundColor Green "Erasing API documentation..."
        Remove-Item en/api/*yml -recurse -Verbose
        Remove-Item en/api/.manifest -Verbose
    }
}

function Build-EnglishDoc {
    Write-Host -ForegroundColor Yellow "Start building English documentation."

    # Output to both build.log and console
    docfx build en\docfx.json

    if ($LastExitCode -ne 0)
    {
        Write-Host -ForegroundColor Red "Failed to build English documentation"
        exit $LastExitCode
    }
}

function Build-NonEnglishDoc {
    param (
        $SelectedLanguage
    )

    if ($SelectedLanguage -and $SelectedLanguage.language -ne 'en') {

        Write-Host -ForegroundColor Yellow "Start building $($SelectedLanguage.name) documentation."

        $langFolder = "$($SelectedLanguage.language)$($Settings.TempDirectory)"


        if(Test-Path $langFolder){
            Remove-Item $langFolder/* -recurse -Verbose
        }
        else{
            New-Item -Path $langFolder -ItemType Directory -Verbose
        }

        # Copy all files from en folder to the selected language folder, this way we can keep en files that are not translated
        Copy-Item en/* -Recurse $langFolder -Force

        # Get all translated files from the selected language folder
        $posts = Get-ChildItem $langFolder/manual/*.md -Recurse -Force

        Write-Host "Start write files:"

        # Mark files as not translated if they are not in the toc.md file
        foreach ($post in $posts)
        {
            if($post.ToString().Contains("toc.md")) {
                continue;
            }

            $data = Get-Content $post -Encoding UTF8
            for ($i = 0; $i -lt $data.Length; $i++)
            {
                $line = $data[$i];
                if ($line.length -le 0)
                {
                    Write-Host $post

                    $data[$i-1]="> [!WARNING]`r`n> " + $SelectedLanguage.notTranslatedMessage + "`r`n"

                    $data | Out-File -Encoding UTF8 $post

                    break
                }
            }
        }

        Write-Host "End write files"
        $indexFile = $Settings.IndexFileName
        # overwrite en manual page with translated manual page
        if (Test-Path ($SelectedLanguage.language + "/" + $indexFile)) {
            Copy-Item ($SelectedLanguage.language + "/" + $indexFile) $langFolder -Force
        }
        else {
            Write-Host -ForegroundColor Yellow "Warning: $($SelectedLanguage.language)/"+ $indexFile +" not found. English version will be used."
        }

        # overwrite en manual pages with translated manual pages
        if (Test-Path ($SelectedLanguage.language + "/" + $Settings.ManualFolderName)) {
            Copy-Item ($SelectedLanguage.language + "/" + $Settings.ManualFolderName) -Recurse -Destination $langFolder -Force
        }
        else {
            Write-Host -ForegroundColor Yellow "Warning: $($SelectedLanguage.language)/manual not found."
        }

        # we copy the docfx.json file from en folder to the selected language folder, so we can keep the same settings and maitain just one docfx.json file
        Copy-Item en/docfx.json $langFolder -Force
        $SiteDir = $Settings.SiteDirectory
        (Get-Content $langFolder/docfx.json) -replace "$SiteDir/en","$SiteDir/$($SelectedLanguage.language)" | Set-Content -Encoding UTF8 $langFolder/docfx.json


        docfx build $langFolder\docfx.json

        Remove-Item $langFolder -Recurse -Verbose

        PostProcessing-DocFxDocUrl -SelectedLanguage $SelectedLanguage

        if ($LastExitCode -ne 0)
        {
            Write-Host -ForegroundColor Red "Failed to build $($SelectedLanguage.name) documentation"
            exit $LastExitCode
        }

        Write-Host -ForegroundColor Green "$($SelectedLanguage.name) documentation built."
    }
}

function Build-AllLanguagesDocs {
    param (
        [array]$Languages
    )

    foreach ($lang in $Languages) {
        if ($lang.enabled -and -not $lang.isPrimary) {

            Build-NonEnglishDoc -SelectedLanguage $lang

        }
    }
}

# docfx generates GitHub link based on the temp _tmp folder, which we need to correct to correct
# GitHub links. This function does that.
function PostProcessing-DocFxDocUrl {
    param (
        $SelectedLanguage
    )

    $posts = Get-ChildItem "$($SelectedLanguage.language)/*.md" -Recurse -Force

    # Get a list of all HTML files in the _site/<language> directory
    $htmlFiles = Get-ChildItem "$($Settings.SiteDirectory)/$($SelectedLanguage.language)/*.html" -Recurse

    # Get the relative paths of the posts
    $relativePostPaths = $posts | ForEach-Object { $_.FullName.Replace((Resolve-Path $SelectedLanguage.language).Path + '\', '') }

    Write-Host -ForegroundColor Yellow "Post-processing docfx:docurl in $($htmlFiles.Count) files..."

    for ($i = 0; $i -lt $htmlFiles.Count; $i++) {
        $htmlFile = $htmlFiles[$i]
        # Get the relative path of the HTML file
        $relativeHtmlPath = $htmlFile.FullName.Replace((Resolve-Path "$($Settings.SiteDirectory)/$($SelectedLanguage.language)").Path + '\', '').Replace('.html', '.md')

        # Read the content of the HTML file
        $content = Get-Content $htmlFile

        # Define a regex pattern to match the meta tag with name="docfx:docurl"
        $pattern = '(<meta name="docfx:docurl" content=".*?)(/' + $SelectedLanguage.language + $Settings.TempDirectory+ '/)(.*?">)'

        # Define a regex pattern to match the href attribute in the <a> tags
        $pattern2 = '(<a href=".*?)(/' + $SelectedLanguage.language + $Settings.TempDirectory + '/)(.*?">)'

        # Check if the HTML file is from the $posts collection
        if ($relativePostPaths -contains $relativeHtmlPath) {
            # Replace /<language>_tmp/ with /<language>/ in the content
            $content = $content -replace $pattern, "`${1}/$($SelectedLanguage.language)/`${3}"
            $content = $content -replace $pattern2, "`${1}/$($SelectedLanguage.language)/`${3}"
        } else {
            # Replace /<language>_tmp/ with /en/ in the content
            $content = $content -replace $pattern, '${1}/en/${3}'
            $content = $content -replace $pattern2, '${1}/en/${3}'
        }

        # Write the updated content back to the HTML file
        $content | Set-Content -Encoding UTF8 $htmlFile

        # Check if the script is running in an interactive session before writing progress
        # We don't want to write progress when running in a non-interactive session, such as in a build pipeline
        if ($host.UI.RawUI) {
            Write-Progress -Activity "Processing files" -Status "$i of $($htmlFiles.Count) processed" -PercentComplete (($i / $htmlFiles.Count) * 100)
        }
    }

    Write-Host -ForegroundColor Green "Post-processing completed."
}

# Main script execution starts here

$languages = Read-LanguageConfigurations

Start-Transcript -Path ".\build.log"

if ($BuildAll)
{
    $allLanguages = $true
    $API = $true
}
else
{
    $userInput = Get-UserInput

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
        $API = Ask-IncludeAPI
    }
}

if ($cancel)
{
    Write-Host -ForegroundColor Red "Operation canceled by user."
    Stop-Transcript
    Read-Host -Prompt "Press ENTER key to exit..."
    return
}

if ($runLocalWebsite)
{
    Start-LocalWebsite
}

# Generate API doc
if ($API)
{
    Generate-APIDoc
}
else
{
    Remove-APIDoc
}

Write-Host -ForegroundColor Green "Generating documentation..."
Write-Host ""
Write-Warning "Note that when building docs without API, you will get UidNotFound warnings and invalid references warnings"
Write-Host ""

if ($enLanguage -or $allLanguages)
{
   Build-EnglishDoc
}

# Do we need this?
# Copy-ExtraItems

# Build non-English language if selected or build all languages if selected
if ($allLanguages) {
    Build-AllLanguagesDocs -Languages $languages
} elseif ($selectedLanguage) {
    Build-NonEnglishDoc -SelectedLanguage $selectedLanguage
}

Stop-Transcript

Read-Host -Prompt "Press any ENTER to exit..."