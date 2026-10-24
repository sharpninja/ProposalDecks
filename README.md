# ProposalDecks

PowerShell module for proposal sites. A customer repo holds CSS and YAML. This module holds the portrait template, the landscape template, and the commands that create, build, and publish the site.

Both orientations are generated from `index.yaml`, the deck files it lists, and one `theme.css`.

```powershell
Import-Module ./ProposalDecks.psd1
Build-ProposalSite -Path ./examples/agape-farmstead
```

| Command | What it does |
|---|---|
| `New-ProposalProject` | Start a customer repo (CSS and YAML only) and, with `-Repository`, create it on GitHub |
| `Build-ProposalSite` | Write `docs/` — portrait, landscape, and the landing page |
| `Publish-ProposalSite` | Build, commit, push, and point GitHub Pages at `/docs` |

Agent prompts for those commands are in [prompts](prompts).

`index.yaml` is the landing page. Each entry under `decks` is a path to a deck file. Slide `layout` is one of `hero`, `list`, `cards`, `phase`, `map`, `ask`, `close`.

Portrait pages are `docs/<slug>.html`. Landscape pages are `docs/<slug>.wide.html`.
