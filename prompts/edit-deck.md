# Edit a deck

Change copy in the deck YAML only. Then rebuild. Never edit files under `docs/`.

```powershell
Import-Module ./ProposalDecks.psd1
Build-ProposalSite -Path <customer-repo>
```

## Rules

- One deck file per talk. The landing page does not list a deck until `index.yaml` has its path.
- `layout` picks the slide variation: `hero`, `list`, `cards`, `phase`, `map`, `ask`, `close`.
- Titles may use `<br>`, `__ACCENT__`, and `__ACCENT2__`. Do not put other HTML in YAML.
- `{{contact}}` in a footer is replaced from `contact` in `index.yaml`.
- Do not mention price, fee, or payment unless the customer asked for it in the YAML.
- Portrait is `<slug>.html`. Landscape is `<slug>.wide.html`. Same YAML, same `theme.css`.

## Slide shapes

```yaml
layout: "hero"     # tag, title, subtitle, stats
layout: "list"     # title, list
layout: "cards"    # cards: title, text, optional pillar
layout: "phase"    # phase and/or timeline, title, list
layout: "map"      # map: zones or routes, plus caption. Needs maps.yml
layout: "ask"      # ask: title, text, button, button_href
layout: "close"    # title, subtitle, list, footer
```

## Done when

The YAML says what the user asked, both HTML files were regenerated, and you did not edit the HTML by hand.
