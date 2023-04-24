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

# Generate API doc
if ($API)
{
    Write-Host "Generating API documentation..."

    # Build metadata from C# source, docfx runs dotnet restore

    docfx metadata en/docfx.json

    if ($LastExitCode -ne 0)
    {
        Write-Host "Failed to generate API metadata"

        exit $LastExitCode
    }
}
else
{
    If(Test-Path en/api/.manifest)
    {
        Write-Host "Erasing API documentation..."
        Remove-Item en/api/*yml -recurse
        Remove-Item en/api/.manifest
    }
}

Write-Host "Generating documentation..."

# Output to both build.log and console

docfx build en\docfx.json

if ($LastExitCode -ne 0)
{
    Write-Host "Failed to build doc"
    exit $LastExitCode
}

# Copy extra items
# Copy-Item en/ReleaseNotes/ReleaseNotes.md _site/en/ReleaseNotes/
Stop-Transcript