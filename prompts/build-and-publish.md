# Build and publish

Generate both orientations, commit the customer repo, and push. GitHub Pages serves the `docs` folder on `main`.

```powershell
Import-Module ./ProposalDecks.psd1
Build-ProposalSite -Path <customer-repo>
Publish-ProposalSite -Path <customer-repo> -Message "Publish decks."
```

`Publish-ProposalSite` runs the build, commits `index.yaml`, `theme.css`, `maps.yml`, `decks/`, and `docs/`, pushes `main`, and sets Pages to `/docs` when the token allows it.

## Check before you push

- `docs/index.html` links every deck in `index.yaml`.
- `docs/index.wide.html` links the landscape files.
- `docs/theme.css` is the customer theme, not a second copy of the layout.
- `docs/deck.css` is the shared layout from the module. Leave it.
- Portrait and landscape of the same deck show the same words.

## Theme

Edit only `theme.css`. Both templates read the same variables: `--forest`, `--forest-mid`, `--green`, `--green-dim`, `--cream`, `--muted`, `--card`, `--accent2`, `--heading-font`, `--body-font`, `--radius`, `--slide-pad-x`, `--slide-pad-y`.

## Done when

The Pages site loads `docs/index.html`, each deck opens, and the Landscape link opens the wide file.
