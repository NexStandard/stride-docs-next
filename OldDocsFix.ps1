$path = 'd:\Projects\GitHub\stride-docs-live-fix\' # specify your directory path

$replacements = @{
    '//stride3d.net/css/site.css' = '/css/site.css';
    '//xenko.com/css/site.css' = '/css/site.css';
    '//stride3d.net/scripts/site.doc.js' = '/scripts/site.doc.js';
    '//xenko.com/scripts/site.doc.js' = '/scripts/site.doc.js';
    '//stride3d.net/favicon.png' = '/favicon.png';
    '//xenko.com/favicon.png' = '/favicon.png';
    '//stride3d.net/scripts/theme.js' = '/scripts/theme.js';
    '//xenko.com/scripts/theme.js' = '/scripts/theme.js';
}

$files = Get-ChildItem -Path $path -Filter *.html -Recurse
$fileCount = $files.Count
$i = 0

foreach ($file in $files) {
    # if ($i -ge 100) { break } # Exit loop after 100 items

    $i++
    $content = Get-Content $file.FullName -Encoding UTF8
    $replacements.Keys | ForEach-Object {
        $content = $content -replace $_, $replacements[$_]
    }
    Set-Content -Path $file.FullName -Value $content -Encoding UTF8

    # Update progress bar
    Write-Progress -Activity "Processing Files" -Status "$i of $fileCount processed" -PercentComplete (($i / $fileCount) * 100)
}

Write-Progress -Activity "Processing Files" -Completed