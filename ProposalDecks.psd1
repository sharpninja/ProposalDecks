@{
    RootModule        = 'ProposalDecks.psm1'
    ModuleVersion     = '1.1.0'
    GUID              = 'a0c9a2d4-b776-4bce-b0fe-dfa5096f9ef3'
    Author            = 'Payton Byrd'
    CompanyName       = 'Payton Byrd'
    Copyright         = '(c) 2026 Payton Byrd'
    Description       = 'Build portrait and landscape proposal decks from index.yaml, deck YAML, and one CSS theme. Create a customer GitHub repo and publish GitHub Pages.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @('Build-ProposalSite', 'Publish-ProposalSite', 'New-ProposalProject')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('proposal', 'deck', 'yaml', 'github-pages')
            ProjectUri   = 'https://github.com/sharpninja/ProposalDecks'
            LicenseUri   = 'https://github.com/sharpninja/ProposalDecks/blob/main/LICENSE'
            ReleaseNotes = 'Deck YAML is deserialized with powershell-yaml. No hand-written parser.'
        }
    }
}
