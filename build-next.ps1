param (
    [switch]$API
)

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
    Write-Host -ForegroundColor Yellow "  [C] Cancel"
    $userInput = Read-Host -Prompt "Your choice (y/n/c)"
    $API = $userInput -eq "y" -or $userInput -eq "Y"
    $cancel = $userInput -eq "c" -or $userInput -eq "C"
}

if ($cancel)
{
    Write-Host -ForegroundColor Red "Operation canceled by user."
    Stop-Transcript
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

Stop-Transcript
