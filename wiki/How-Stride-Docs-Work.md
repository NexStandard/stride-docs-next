# Table of Contents

- [Intro](#intro)
- [Documentation Build Workflow](#documentation-build-workflow)

# Intro
DocFX doesn't support generating multiple languages and versions of documentation at the moment. Stride team created a PowerShell script for each language that was used to generate multiple languages. The script was merged into `BuildAll.ps1` so currently there is only one script which can generate all languages.

The script is used by CI/CD to generate the documentation for all languages and the latest version.

- The script has an interactive command-line UI which allows the user to select which languages to generate.
- The script also has a non-interactive mode which can be used to generate the documentation for all languages and versions without any user interaction.

- Building 1620 file(s) in ResourceDocumentProcessor(ValidateResourceMetadata)...
- Building 304 file(s) in ConceptualDocumentProcessor(BuildConceptualDocument=>CountWord=>ValidateConceptualDocumentMetadata)...
- Building 2133 file(s) in ManagedReferenceDocumentProcessor(BuildManagedReferenceDocument=>SplitClassPageToMemberLevel=>ValidateManagedReferenceDocumentMetadata=>ApplyOverwriteDocumentForMref=>FillReferenceInformation)...
- Building 6 file(s) in TocDocumentProcessor(BuildTocDocument)...
- Applying templates to 4063 model(s)...

---

- Building 2516 file(s) in ManagedReferenceDocumentProcessor(BuildManagedReferenceDocument=>SplitClassPageToMemberLevel=>ValidateManagedReferenceDocumentMetadata=>ApplyOverwriteDocumentForMref=>FillReferenceInformation)...
- Applying templates to 4446 model(s)...

# Documentation Build Workflow

- **BuildAll - Yes** is used for CI/CD.
- **BuildAll - No** is used for local development with an interactive command-line UI.

``` mermaid
%% Define styles

%% Main Graph
graph TB

%% Nodes
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
    A --> B
    B -->|Yes| D
    B -->|No| C
    subgraph User Interaction
    C --> E
    C --> F
    C --> G
    end
    F --> End
    G --> End
    E -->|Yes| D
    E -->|No| H
    subgraph Documentation Generation
    H --> M
    D --> M
    M -->|Yes| N
    M -->|No| R
    N --> DocFX{{DocFX}} --> O --> O1--> P
    P --> R
    R -->|Yes| S
    R -->|No| T
    S --> T
    T --> X{{DocFX}}
    X --> Y
    Y --> Z
    end
```