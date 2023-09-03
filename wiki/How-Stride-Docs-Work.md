# Table of Contents

- [Intro](#intro)
- [Process](#process)
- [Documentation Build Workflow](#documentation-build-workflow)

# Intro
DocFX doesn't support generating multiple languages and versions of documentation at the moment. Stride team created a PowerShell script for each language that was used to generate multiple languages. The script was merged into `BuildAll.ps1` so currently there is only one script which can generate all languages.

The script is used by CI/CD to generate the documentation for all languages and the latest version.

- The script has an interactive command-line UI which allows the user to select which languages to generate.
- The script also has a non-interactive mode which can be used to generate the documentation for all languages and versions without any user interaction.


# Process

Let's describe the process of generating the documentation in a simple way.

The `/en` folder contains primary documentation files. If another language is built, the files from `/en` are copied to the language temp folder e.g. `/jp-tmp`. This will guarantee that another language will have all the files from `/en` and only the files that are translated will be overwritten (from the folder `/jp`) as not all files are translated.

DocFX then runs multiple times for each language and creates docs in `_site` folder, starting with the latest version loaded from `version.json`:

```
/_site/4.1/en
/_site/4.1/jp
```

The Documentation Build Workflow below will describe the process in more detail.


- Building 1620 file(s) in ResourceDocumentProcessor(ValidateResourceMetadata)...
- Building 304 file(s) in ConceptualDocumentProcessor(BuildConceptualDocument=>CountWord=>ValidateConceptualDocumentMetadata)...
- Building 2133 file(s) in ManagedReferenceDocumentProcessor(BuildManagedReferenceDocument=>SplitClassPageToMemberLevel=>ValidateManagedReferenceDocumentMetadata=>ApplyOverwriteDocumentForMref=>FillReferenceInformation)...
- Building 6 file(s) in TocDocumentProcessor(BuildTocDocument)...
- Applying templates to 4063 model(s)...

---

- Building 2516 file(s) in ManagedReferenceDocumentProcessor(BuildManagedReferenceDocument=>SplitClassPageToMemberLevel=>ValidateManagedReferenceDocumentMetadata=>ApplyOverwriteDocumentForMref=>FillReferenceInformation)...
- Applying templates to 4446 model(s)...

# Documentation Build Workflow

Let's describe individual steps of the documentation build workflow.

- Start
    - This step reads parameter `$BuildAll` and if it's set to No (used for local development with an interactive command-line UI), it will ask the user to select which languages to generate. If it's set to Yes (used for CI/CD), it will generate all languages and Stride API without asking the user.
    - This step also sets parameter `$Version` from the command-line argument `-Version` or the first item from the file `version.json` if the argument is not set.
- Read-LanguageConfigurations
    - This step reads the file `languages.json` which contains all languages to generate.
- BuildAll
    - If this step is processed, this step pre-sets some variables for non-interactive mode and Get-UserInput is skipped.
- Get-UserInput
    - This interactive step asks the user to select which languages to generate, including all languages or whether to launch local website.
- Ask-IncludeAPI
   - This interactive step asks if the Stride API should be included in the documentation.
- Start-LocalWebsite
   - This step (if it was selected) launches local web server which will host generated website
- Generate-APIDoc
   - This steps runs `docfx.exe` to generate Stride API metadata used for generating API documentation.
- Remove-APIDoc
   - This step removes the generated Stride API metadata
- Build-EnglishDoc
   - This step runs `docfx.exe` to generate English documentation, including Stride API documentation from the metadate.
   - 


``` mermaid
%% Define styles

%% Main Graph
graph TB

%% Nodes
    Start[Start]
    A[Read-LanguageConfigurations]
    B{BuildAll}
    C[Get-UserInput]
    D[Generate-APIDoc]
    E{Ask-IncludeAPI}
    End[End]
    F[Start-LocalWebsite]
    G[Cancel]
    H[Remove-APIDoc]
    M{isEnLanguage or isAllLanguages}
    N[Build-EnglishDoc]
    O[PostProcessing-FixingSitemap]
    O1[PostProcessing-Fixing404AbsolutePath]
    P[Copy-ExtraItems]
    R{isAllLanguages}
    S[Build-AllLanguagesDocs]
    T[Build-NonEnglishDoc]
    Y[PostProcessing-DocFxDocUrl]
    Z[End]

%% Edges
    Start --> A --> B
    B -->|Yes| D
    B -->|No| C
    subgraph User Interaction
    C --> E
    C --> F --> F1{{docfx serve}}
    C --> G
    end
    F1 --> End
    G --> End
    E -->|Yes| D
    E -->|No| H
    subgraph Documentation Generation
    H --> M
    D --> D1{{docfx metadata}} --> M
    M -->|Yes| N
    M -->|No| R
    N --> DocFX{{docfx build}} --> O --> O1--> P
    P --> R
    R -->|Yes| S
    R -->|No| T
    S --> T
    T --> X{{docfx build}}
    X --> Y
    Y --> Z
    end
```