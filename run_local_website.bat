mkdir _site
cd _site
start "" http://localhost:8080/en/index.html
docfx serve

rem stride-docs-next
rem launch and open in http://localhost:8080/
rem docfx en\docfx.json --serve