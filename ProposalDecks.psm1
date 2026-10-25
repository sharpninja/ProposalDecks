Set-StrictMode -Version Latest

$script:ModuleRoot = $PSScriptRoot

function ConvertFrom-DeckYaml {
    param([Parameter(Mandatory)][string]$Text)
    $lines = $Text -split "`n"
    $root = [ordered]@{}
    $stack = New-Object System.Collections.Stack
    $stack.Push(@{ Indent = -1; Node = $root })
    function Next-Line([int]$i) {
        for ($j = $i + 1; $j -lt $lines.Count; $j++) {
            $l = $lines[$j]
            if ($l -match '^\s*#' -or $l -match '^\s*$') { continue }
            return $l
        }
        return ""
    }
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $raw = $lines[$i].TrimEnd("`r")
        if ($raw -match '^\s*#' -or $raw -match '^\s*$') { continue }
        if ($raw -match '^(\s*)-\s+(.*)$') {
            $indent = $Matches[1].Length
            $content = $Matches[2]
            while ($stack.Peek().Indent -ge $indent) { [void]$stack.Pop() }
            $parent = $stack.Peek().Node
            if ($parent -isnot [System.Collections.IList]) { throw "YAML error: $raw" }
            if ($content -match '^([A-Za-z_][\w]*):\s*(.*)$') {
                $obj = [ordered]@{}
                $obj[$Matches[1].Trim()] = $Matches[2].Trim().Trim('"').Trim("'")
                [void]$parent.Add($obj)
                $stack.Push(@{ Indent = $indent; Node = $obj })
            }
            else {
                [void]$parent.Add($content.Trim().Trim('"').Trim("'"))
            }
        }
        elseif ($raw -match '^(\s*)([^:]+):\s*(.*)$') {
            $indent = $Matches[1].Length
            $key = $Matches[2].Trim()
            $val = $Matches[3].Trim().Trim('"').Trim("'")
            while ($stack.Peek().Indent -ge $indent) { [void]$stack.Pop() }
            $parent = $stack.Peek().Node
            if ($parent -is [System.Collections.IList]) { throw "YAML error: $raw" }
            if ($val -eq '') {
                $nxt = Next-Line $i
                if ($nxt -match '^\s*-\s+') {
                    $lst = New-Object System.Collections.ArrayList
                    $parent[$key] = $lst
                    $stack.Push(@{ Indent = $indent; Node = $lst })
                }
                else {
                    $obj = [ordered]@{}
                    $parent[$key] = $obj
                    $stack.Push(@{ Indent = $indent; Node = $obj })
                }
            }
            else {
                $parent[$key] = $val
            }
        }
        else { throw "YAML error: $raw" }
    }
    return $root
}

function Read-DeckFile {
    param([string]$Path, [string]$Contact)
    $text = [System.IO.File]::ReadAllText($Path)
    if ($Contact) { $text = $text.Replace('{{contact}}', $Contact) }
    return ConvertFrom-DeckYaml $text
}

function ConvertTo-HtmlText([string]$Value) {
    if (-not $Value) { return "" }
    return [System.Net.WebUtility]::HtmlEncode($Value)
}

function Format-SlideTitle([string]$Value) {
    $t = $Value.Replace('__ACCENT__', '<span class="accent">').Replace('__ACCENT2__', '<span class="accent2">')
    $open = ([regex]::Matches($t, '<span')).Count
    $close = ([regex]::Matches($t, '</span>')).Count
    if ($open -gt $close) { $t += '</span>' * ($open - $close) }
    return $t
}

function New-CorridorSvg {
    param($Corridors, [switch]$Numbered, [string]$Hub, [string]$Radius)
    $cx = 200; $cy = 188
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('<svg viewBox="0 0 400 430" role="img">')
    [void]$sb.Append("<title>$Hub corridors</title>")
    [void]$sb.Append("<circle cx=`"$cx`" cy=`"$cy`" r=`"128`" fill=`"#f4efe4`" stroke=`"#6b7f3a`" stroke-width=`"1.5`" stroke-dasharray=`"4 5`"/>")
    [void]$sb.Append("<text x=`"$cx`" y=`"28`" text-anchor=`"middle`" fill=`"#6b7f3a`" font-size=`"12`" font-family=`"Georgia, serif`">$Radius</text>")
    $n = 0
    foreach ($road in $Corridors) {
        $n++
        $names = @($road['stops'].Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        $bearing = [double]$road['bearing']
        $color = $road['color']
        $rad = $bearing * [math]::PI / 180
        $coords = @("$cx,$cy")
        for ($i = 0; $i -lt $names.Count; $i++) {
            $r = 46 + ($i * (78 / [math]::Max(1, $names.Count - 1)))
            if ($names.Count -eq 1) { $r = 108 }
            $x = [math]::Round($cx + [math]::Sin($rad) * $r, 1)
            $y = [math]::Round($cy - [math]::Cos($rad) * $r, 1)
            $coords += "$x,$y"
        }
        $tipR = 128
        $tx = [math]::Round($cx + [math]::Sin($rad) * $tipR, 1)
        $ty = [math]::Round($cy - [math]::Cos($rad) * $tipR, 1)
        $id = "arrow$n"
        if ($Numbered) {
            [void]$sb.Append("<defs><marker id=`"$id`" viewBox=`"0 0 10 10`" refX=`"8`" refY=`"5`" markerWidth=`"7`" markerHeight=`"7`" orient=`"auto`"><path d=`"M0 1 L10 5 L0 9 z`" fill=`"$color`"/></marker></defs>")
            $coords += "$tx,$ty"
        }
        $points = $coords -join ' '
        $marker = ""
        if ($Numbered) { $marker = " marker-end=`"url(#$id)`"" }
        [void]$sb.Append("<polyline points=`"$points`" fill=`"none`" stroke=`"$color`" stroke-width=`"3`" stroke-linecap=`"round`" stroke-linejoin=`"round`"$marker/>")
        for ($i = 0; $i -lt $names.Count; $i++) {
            $pair = $coords[$i + 1].Split(',')
            $x = $pair[0]; $y = $pair[1]
            $label = $names[$i]
            if ($label -eq 'Adams') { $label = 'Adams · farm' }
            $anchor = 'start'
            $dx = 10
            if ([double]$x -lt $cx) { $anchor = 'end'; $dx = -10 }
            if ($Numbered) {
                [void]$sb.Append("<circle cx=`"$x`" cy=`"$y`" r=`"8`" fill=`"#f7f1e5`" stroke=`"$color`" stroke-width=`"2`"/>")
                $numY = [double]$y + 3.5
                [void]$sb.Append("<text x=`"$x`" y=`"$numY`" text-anchor=`"middle`" fill=`"$color`" font-size=`"10`" font-family=`"system-ui,sans-serif`" font-weight=`"700`">$($i + 1)</text>")
            }
            else {
                [void]$sb.Append("<circle cx=`"$x`" cy=`"$y`" r=`"4.5`" fill=`"$color`"/>")
            }
            $ly = [double]$y - 10
            $lx = [double]$x + $dx
            [void]$sb.Append("<text x=`"$lx`" y=`"$ly`" text-anchor=`"$anchor`" fill=`"#2a261f`" font-size=`"11`" font-family=`"system-ui,sans-serif`" font-weight=`"600`">$(ConvertTo-HtmlText $label)</text>")
        }
    }
    [void]$sb.Append("<circle cx=`"$cx`" cy=`"$cy`" r=`"7`" fill=`"#2f3a22`"/><circle cx=`"$cx`" cy=`"$cy`" r=`"3`" fill=`"#d5e3a4`"/>")
    $hy = $cy + 20
    [void]$sb.Append("<text x=`"$cx`" y=`"$hy`" text-anchor=`"middle`" fill=`"#2f3a22`" font-size=`"13`" font-family=`"Georgia, serif`" font-weight=`"700`">$(ConvertTo-HtmlText $Hub)</text>")
    [void]$sb.Append('</svg>')
    return $sb.ToString()
}

function New-SlideHtml {
    param($Slide, [int]$Index, $Maps, [string]$Hub, [string]$Radius)
    $layout = if ($Slide['layout']) { $Slide['layout'] } else { 'list' }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("<section class=`"slide $layout`" id=`"s$Index`">")
    [void]$sb.AppendLine('  <div class="inner">')
    if ($Slide['tag']) { [void]$sb.AppendLine("    <span class=`"tag`">$(ConvertTo-HtmlText $Slide['tag'])</span>") }
    if ($Slide['phase']) { [void]$sb.AppendLine("    <div class=`"phase-num`">$(ConvertTo-HtmlText $Slide['phase'])</div>") }
    if ($Slide['timeline']) { [void]$sb.AppendLine("    <div class=`"timeline`">$(ConvertTo-HtmlText $Slide['timeline'])</div>") }
    if ($Slide['title']) {
        $t = Format-SlideTitle $Slide['title']
        $tag = if ($t -match '<br') { 'h1' } else { 'h2' }
        [void]$sb.AppendLine("    <$tag>$t</$tag>")
    }
    if ($Slide['subtitle']) { [void]$sb.AppendLine("    <p class=`"sub`">$(ConvertTo-HtmlText $Slide['subtitle'])</p>") }
    if ($Slide['stats']) {
        [void]$sb.AppendLine('    <div class="stat-row">')
        foreach ($st in $Slide['stats']) {
            [void]$sb.AppendLine("      <div class=`"stat`"><div class=`"n`">$(ConvertTo-HtmlText $st['n'])</div><div class=`"l`">$(ConvertTo-HtmlText $st['l'])</div></div>")
        }
        [void]$sb.AppendLine('    </div>')
    }
    if ($layout -eq 'map' -and $Maps) {
        $kind = $Slide['map']
        $set = if ($kind -eq 'routes') { $Maps['routes'] } else { $Maps['zones'] }
        $svg = New-CorridorSvg -Corridors $set -Hub $Hub -Radius $Radius -Numbered:($kind -eq 'routes')
        [void]$sb.AppendLine('    <figure class="figure">')
        [void]$sb.AppendLine("      $svg")
        if ($Slide['caption']) { [void]$sb.AppendLine("      <figcaption>$(ConvertTo-HtmlText $Slide['caption'])</figcaption>") }
        [void]$sb.AppendLine('    </figure>')
    }
    if ($Slide['cards']) {
        [void]$sb.AppendLine('    <div class="two-col">')
        foreach ($c in $Slide['cards']) {
            [void]$sb.AppendLine('      <div class="card">')
            if ($c['pillar']) { [void]$sb.AppendLine("        <div class=`"pillar`">$(ConvertTo-HtmlText $c['pillar'])</div>") }
            if ($c['title']) { [void]$sb.AppendLine("        <h3>$(ConvertTo-HtmlText $c['title'])</h3>") }
            if ($c['text']) { [void]$sb.AppendLine("        <p>$(ConvertTo-HtmlText $c['text'])</p>") }
            [void]$sb.AppendLine('      </div>')
        }
        [void]$sb.AppendLine('    </div>')
    }
    if ($Slide['list']) {
        [void]$sb.AppendLine('    <ul>')
        foreach ($item in $Slide['list']) { [void]$sb.AppendLine("      <li>$(ConvertTo-HtmlText $item)</li>") }
        [void]$sb.AppendLine('    </ul>')
    }
    if ($Slide['note']) { [void]$sb.AppendLine("    <div class=`"note-box`">$(ConvertTo-HtmlText $Slide['note'])</div>") }
    if ($Slide['ask']) {
        $a = $Slide['ask']
        [void]$sb.AppendLine('    <div class="ask-box">')
        if ($a['title']) { [void]$sb.AppendLine("      <div class=`"price`">$(ConvertTo-HtmlText $a['title'])</div>") }
        if ($a['text']) { [void]$sb.AppendLine("      <p class=`"sub`" style=`"margin-top:8px`">$(ConvertTo-HtmlText $a['text'])</p>") }
        if ($a['button']) {
            $href = if ($a['button_href']) { $a['button_href'] } else { '#' }
            [void]$sb.AppendLine("      <a class=`"btn`" href=`"$(ConvertTo-HtmlText $href)`">$(ConvertTo-HtmlText $a['button'])</a>")
        }
        [void]$sb.AppendLine('    </div>')
    }
    if ($Slide['footer']) { [void]$sb.AppendLine("    <p class=`"footer-note`">$(ConvertTo-HtmlText $Slide['footer'])</p>") }
    [void]$sb.AppendLine('  </div>')
    [void]$sb.AppendLine('</section>')
    return $sb.ToString()
}

function New-LandingHtml {
    param($Index, $Decks, [string]$Suffix, [switch]$Paged)
    $sb = New-Object System.Text.StringBuilder
    if (-not $Paged) {
        [void]$sb.AppendLine('<section class="slide hero" id="s1"><div class="inner">')
        [void]$sb.AppendLine('  <span class="tag">Proposals</span>')
        [void]$sb.AppendLine("  <h1>$(ConvertTo-HtmlText $Index['name'])</h1>")
        if ($Index['intro']) { [void]$sb.AppendLine("  <p class=`"sub`">$(ConvertTo-HtmlText $Index['intro'])</p>") }
        [void]$sb.AppendLine('  <div class="deck-links" style="margin-top:22px">')
        foreach ($deck in $Decks) {
            $meta = $deck.Meta
            $href = "$($meta['slug'])$Suffix"
            [void]$sb.AppendLine("    <a class=`"card deck-link`" href=`"$href`">")
            if ($meta['eyebrow']) { [void]$sb.AppendLine("      <div class=`"pillar`">$(ConvertTo-HtmlText $meta['eyebrow'])</div>") }
            [void]$sb.AppendLine("      <h3>$(ConvertTo-HtmlText $meta['og_title'])</h3>")
            if ($meta['blurb']) { [void]$sb.AppendLine("      <p>$(ConvertTo-HtmlText $meta['blurb'])</p>") }
            [void]$sb.AppendLine('    </a>')
        }
        [void]$sb.AppendLine('  </div>')
        if ($Index['contact']) { [void]$sb.AppendLine("  <p class=`"footer-note`" style=`"margin-top:18px`">$(ConvertTo-HtmlText $Index['contact'])</p>") }
        [void]$sb.AppendLine('</div></section>')
        return $sb.ToString()
    }
    $n = 1
    [void]$sb.AppendLine("<section class=`"slide hero`" id=`"s$n`"><div class=`"inner`">")
    [void]$sb.AppendLine('  <span class="tag">Proposals</span>')
    [void]$sb.AppendLine("  <h1>$(ConvertTo-HtmlText $Index['name'])</h1>")
    if ($Index['intro']) { [void]$sb.AppendLine("  <p class=`"sub`">$(ConvertTo-HtmlText $Index['intro'])</p>") }
    [void]$sb.AppendLine('  <p class="sub">Swipe sideways for each proposal.</p>')
    if ($Index['contact']) { [void]$sb.AppendLine("  <p class=`"footer-note`" style=`"margin-top:18px`">$(ConvertTo-HtmlText $Index['contact'])</p>") }
    [void]$sb.AppendLine('</div></section>')
    foreach ($deck in $Decks) {
        $n++
        $meta = $deck.Meta
        $href = "$($meta['slug'])$Suffix"
        [void]$sb.AppendLine("<section class=`"slide cards`" id=`"s$n`"><div class=`"inner`">")
        if ($meta['eyebrow']) { [void]$sb.AppendLine("  <span class=`"tag`">$(ConvertTo-HtmlText $meta['eyebrow'])</span>") }
        [void]$sb.AppendLine("  <h2>$(ConvertTo-HtmlText $meta['og_title'])</h2>")
        if ($meta['blurb']) { [void]$sb.AppendLine("  <p class=`"sub`">$(ConvertTo-HtmlText $meta['blurb'])</p>") }
        [void]$sb.AppendLine("  <p style=`"margin-top:18px`"><a class=`"btn`" href=`"$href`">Open</a></p>")
        [void]$sb.AppendLine('</div></section>')
    }
    return $sb.ToString()
}

function Write-DeckPage {
    param($Template, $Replacements, [string]$OutFile)
    $html = $Template
    foreach ($k in $Replacements.Keys) { $html = $html.Replace($k, [string]$Replacements[$k]) }
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($OutFile, $html, $utf8)
}

function Build-ProposalSite {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$OutDir = ""
    )
    $root = (Resolve-Path $Path).Path
    $indexPath = Join-Path $root 'index.yaml'
    if (-not (Test-Path $indexPath)) { throw "index.yaml not found in $root" }
    $index = Read-DeckFile $indexPath ""
    $contact = [string]$index['contact']
    if (-not $OutDir) { $OutDir = Join-Path $root 'docs' }
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    Copy-Item (Join-Path $root 'theme.css') (Join-Path $OutDir 'theme.css') -Force
    Copy-Item (Join-Path $script:ModuleRoot 'Assets/deck.css') (Join-Path $OutDir 'deck.css') -Force
    Set-Content -Path (Join-Path $OutDir '.nojekyll') -Value '' -Encoding ascii

    $maps = $null
    $mapPath = Join-Path $root 'maps.yml'
    if (Test-Path $mapPath) { $maps = Read-DeckFile $mapPath $contact }
    $hub = if ($maps -and $maps['hub']) { [string]$maps['hub'] } else { 'Nashville' }
    $radius = if ($maps -and $maps['radius']) { [string]$maps['radius'] } else { '' }

    $decks = @()
    foreach ($rel in $index['decks']) {
        $file = Join-Path $root ($rel -replace '\\','/')
        $data = Read-DeckFile $file $contact
        $decks += [pscustomobject]@{ File = $file; Meta = $data['meta']; Slides = $data['slides'] }
    }

    $portrait = [System.IO.File]::ReadAllText((Join-Path $script:ModuleRoot 'Assets/portrait.html'))
    $landscape = [System.IO.File]::ReadAllText((Join-Path $script:ModuleRoot 'Assets/landscape.html'))
    $site = if ($index['site']) { [string]$index['site'] } else { '#' }
    $label = if ($index['siteLabel']) { [string]$index['siteLabel'] } else { $site }
    $color = if ($index['themeColor']) { [string]$index['themeColor'] } else { '#3d4a2c' }

    $landing = New-LandingHtml -Index $index -Decks $decks -Suffix '.html'
    Write-DeckPage $portrait @{
        '__TITLE__' = "$($index['name']) — $($index['title'])"
        '__DESCRIPTION__' = [string]$index['intro']
        '__OG_TITLE__' = [string]$index['name']
        '__OG_DESCRIPTION__' = [string]$index['intro']
        '__THEME_COLOR__' = $color
        '__SITE_URL__' = $site
        '__SITE_LABEL__' = $label
        '__SLIDES__' = $landing
        '__FLIP__' = 'index.wide.html'
        '__CSS__' = ''
    } (Join-Path $OutDir 'index.html')
    Write-DeckPage $landscape @{
        '__TITLE__' = "$($index['name']) — $($index['title'])"
        '__DESCRIPTION__' = [string]$index['intro']
        '__OG_TITLE__' = [string]$index['name']
        '__OG_DESCRIPTION__' = [string]$index['intro']
        '__THEME_COLOR__' = $color
        '__SITE_URL__' = $site
        '__SITE_LABEL__' = $label
        '__SLIDES__' = (New-LandingHtml -Index $index -Decks $decks -Suffix '.wide.html' -Paged)
        '__FLIP__' = 'index.html'
        '__CSS__' = ''
    } (Join-Path $OutDir 'index.wide.html')

    $written = @('index.html', 'index.wide.html')
    foreach ($deck in $decks) {
        $meta = $deck.Meta
        $slidesHtml = ""
        $i = 1
        foreach ($slide in $deck.Slides) {
            $slidesHtml += (New-SlideHtml -Slide $slide -Index $i -Maps $maps -Hub $hub -Radius $radius) + "`n"
            $i++
        }
        $slug = [string]$meta['slug']
        $title = [string]$meta['title']
        $desc = [string]$meta['description']
        $common = @{
            '__TITLE__' = $title
            '__DESCRIPTION__' = $desc
            '__OG_TITLE__' = [string]$meta['og_title']
            '__OG_DESCRIPTION__' = [string]$meta['og_description']
            '__THEME_COLOR__' = $color
            '__SITE_URL__' = $site
            '__SITE_LABEL__' = $label
            '__SLIDES__' = $slidesHtml.TrimEnd()
            '__CSS__' = ''
        }
        $portraitMap = [ordered]@{}
        foreach ($k in $common.Keys) { $portraitMap[$k] = $common[$k] }
        $portraitMap['__FLIP__'] = "$slug.wide.html"
        Write-DeckPage $portrait $portraitMap (Join-Path $OutDir "$slug.html")
        $wideMap = [ordered]@{}
        foreach ($k in $common.Keys) { $wideMap[$k] = $common[$k] }
        $wideMap['__FLIP__'] = "$slug.html"
        Write-DeckPage $landscape $wideMap (Join-Path $OutDir "$slug.wide.html")
        $written += @("$slug.html", "$slug.wide.html")
    }
    Write-Output ([pscustomobject]@{ OutDir = $OutDir; Pages = $written })
}

function Publish-ProposalSite {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$Message = "Publish proposal decks."
    )
    $root = (Resolve-Path $Path).Path
    Build-ProposalSite -Path $root | Out-Null
    Push-Location $root
    try {
        if (-not (Test-Path '.git')) { throw "Not a git repository: $root" }
        git add index.yaml theme.css maps.yml decks docs
        git commit -m $Message
        git push origin HEAD
        $remote = git remote get-url origin
        if ($remote -match 'github\.com[:/]([^/]+)/([^/.]+)') {
            $repo = "$($Matches[1])/$($Matches[2])"
            gh api --method POST "/repos/$repo/pages" -f 'source[branch]=main' -f 'source[path]=/docs' 2>$null
            gh api --method PUT "/repos/$repo/pages" -f 'source[branch]=main' -f 'source[path]=/docs' 2>$null
        }
    }
    finally { Pop-Location }
}

function New-ProposalProject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Customer,
        [Parameter(Mandatory)][string]$DisplayName,
        [string]$Owner = "",
        [string]$Destination = "",
        [string]$Intro = "Proposal decks.",
        [string]$Site = "https://example.com",
        [string]$SiteLabel = "example.com",
        [string]$Contact = "",
        [switch]$Repository,
        [switch]$Publish
    )
    if (-not $Destination) { $Destination = Join-Path (Get-Location) $Customer }
    New-Item -ItemType Directory -Force -Path (Join-Path $Destination 'decks') | Out-Null
    Copy-Item (Join-Path $script:ModuleRoot 'Assets/themes/agape-farm.css') (Join-Path $Destination 'theme.css') -Force
    $index = @"
name: "$DisplayName"
legalName: "$DisplayName"
title: "Proposal Decks"
site: "$Site"
siteLabel: "$SiteLabel"
contact: "$Contact"
intro: "$Intro"
preparedFor: "$DisplayName"
preparedBy: "Payton Byrd"
themeColor: "#3d4a2c"
decks:
  - "decks/01-intro.yml"
"@
    $deck = @"
meta:
  slug: "intro"
  title: "$DisplayName — Intro"
  description: "$Intro"
  og_title: "Intro"
  og_description: "$Intro"
  eyebrow: "Start Here"
  blurb: "$Intro"
slides:
  - tag: "Intro"
    layout: "hero"
    title: "$DisplayName"
    subtitle: "$Intro"
    footer: "{{contact}}"
"@
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText((Join-Path $Destination 'index.yaml'), $index.Trim(), $utf8)
    [System.IO.File]::WriteAllText((Join-Path $Destination 'decks/01-intro.yml'), $deck.Trim() + "`n", $utf8)
    Build-ProposalSite -Path $Destination | Out-Null
    if ($Repository) {
        if (-not $Owner) {
            $Owner = gh api user --jq .login
        }
        Push-Location $Destination
        try {
            git init -b main
            git add index.yaml theme.css decks docs
            git -c user.name="Payton Byrd" -c user.email="plbyrd@gmail.com" commit -m "Start $DisplayName proposal decks."
            gh repo create "$Owner/$Customer" --public --source=. --remote=origin --push --description "$DisplayName proposal decks"
        }
        finally { Pop-Location }
    }
    if ($Publish) { Publish-ProposalSite -Path $Destination -Message "Publish $DisplayName decks." }
    Write-Output $Destination
}

Export-ModuleMember -Function Build-ProposalSite, Publish-ProposalSite, New-ProposalProject
