# New customer site

You are managing a proposal deck site with the ProposalDecks PowerShell module. A customer repository contains only CSS and YAML. Do not copy the module, the HTML templates, or this prompts folder into the customer repo.

## Create the repo

```powershell
Import-Module ./ProposalDecks.psd1
New-ProposalProject -Customer <slug> -DisplayName "<Name>" -Intro "<one sentence>" -Site "https://example.com" -SiteLabel "example.com" -Contact "<name · phone · email>" -Repository
```

`-Repository` creates `https://github.com/<you>/<slug>` and pushes the first build.

## What the customer repo is allowed to contain

- `index.yaml` — landing page. It links each deck.
- `theme.css` — colors, type, spacing. Both orientations use this file.
- `decks/*.yml` — one file per deck.
- `maps.yml` — only if a deck has `layout: "map"`.
- `docs/` — generated. Do not hand-edit it.

## Done when

`index.yaml` lists every deck, `Build-ProposalSite` writes portrait and landscape pages, and the GitHub repo exists.
