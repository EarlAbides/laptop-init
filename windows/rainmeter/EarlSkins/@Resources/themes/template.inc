; Theme template — copy this file and fill in RGBA values to match your wallpaper.
; Rename to <theme-name>.inc and repoint the current.inc symlink:
;   Switch-RainmeterTheme <theme-name>
;
; Color format: R, G, B, A (0-255 each, A=200 is a good semi-transparent default)

[Variables]
; Label text (section headers, metric names) — pick a muted/secondary color from your wallpaper
fontColor.Label=128, 128, 128, 200
; Value text (numbers, readings) — pick a brighter/primary color for readability
fontColor.Text=200, 200, 200, 200
; Graph line color — accent color that stands out against the wallpaper
graph.line=100, 100, 100, 200
; Graph fill color — darker/subdued version of the line color
graph.fill=60, 60, 60, 200
; Graph background — darkest color, used for roundline/bar backgrounds
graph.background=30, 30, 30, 200
; Clock text color
clock.color=200, 200, 200, 200
; Font settings
FontName=Segoe UI
FontHeight=8
