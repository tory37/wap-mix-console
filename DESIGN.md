# WAP Mix Console — Design System

Design read: desk-side reference for a power user in a dim studio. Precision & Density + console-hardware Tactile Brutalism. Dark only.

## Hard constraints
- Plain HTML/CSS/JS. Opens via `file://`. Zero network requests: no CDN, no web fonts, no fetch.
- No emoji. Icons are inline SVG (Lucide paths, copied in).
- No gradients, no blur, no drop shadows. Depth = 1px borders + surface steps.
- No left-accent-stripe cards. Group color shows as a small square chip or top rule only.
- All spacing from the 4px scale tokens. No inline `style=""`.
- Headings never wrap past 2 lines.

## Typography
- Display / labels: `"Bahnschrift", "DIN Alternate", "Arial Narrow", sans-serif` (ships with Windows; DIN console feel). Uppercase labels use `font-stretch: condensed; letter-spacing: .06em`.
- Body: `"Segoe UI Variable Text", "Segoe UI", system-ui, sans-serif`.
- Mono (settings, values, dB, Hz): `"Cascadia Mono", "Consolas", ui-monospace, monospace`. `font-variant-numeric: tabular-nums`.
- Scale ratio 1.25, base 15px:
  - `--fs-xs: .75rem` (12) · `--fs-sm: .8125rem` (13) · `--fs-md: .9375rem` (15) · `--fs-lg: 1.1875rem` (19) · `--fs-xl: 1.5rem` (24)
  - `--fs-h1: clamp(1.75rem, 1.2rem + 1.6vw, 2.5rem)`
- Line height: body 1.55, headings 1.15.

## Color tokens
| Token | Value | Use |
|---|---|---|
| `--bg` | `#0b0c0d` | page |
| `--surface-1` | `#131517` | cards, rack slots |
| `--surface-2` | `#1a1d20` | nested, table header, hover |
| `--border` | `#2a2e33` | all 1px rules |
| `--border-strong` | `#3a3f45` | focus-adjacent, active slot |
| `--text` | `#e6e8ea` | primary text |
| `--text-muted` | `#9aa1a9` | secondary |
| `--accent` | `#eab308` | print-bus gold; links, active nav, focus ring |
| `--accent-ink` | `#0b0c0d` | text on accent |
| `--ok` `--warn` `--danger` | `#34d399` `#fb923c` `#f43f5e` | meter zones, callouts |

Group colors equal the REAPER template palette. Source of truth: the constants at the top of `docs/reaper-scripts/wap_build_mix_template.lua`. Change both together.

Tracks run a rainbow down the track list. Each section bus takes the darker `-bus` shade.

| Group | Track token | Bus token |
|---|---|---|
| Drums | `--g-drums #ff0000` | `--g-drums-bus #c00000` |
| Bass | `--g-bass #ff8000` | `--g-bass-bus #c06000` |
| Guitars | `--g-guitars #ffff00` | `--g-guitars-bus #c0c000` |
| Orchestral | `--g-orch #00ff00` | `--g-orch-bus #00c000` |
| Synths | `--g-synth #0080ff` | none (synths sit in the green `orch_syn_bus`) |
| SFX | `--g-sfx #4000ff` | `--g-sfx-bus #3000c0` |
| Vocals | `--g-vocals #bf00ff` | `--g-vocals-bus #9000c0` |

- White `--g-master #ffffff`: `master_bus`, `print_bus`, `instrument_bus`, `vocal_master`.
- Gray `--g-fx #8a8a8a`: every FX return.
- Black `--g-hub #000000`: sidechain hubs.
- `--g-none #3a3f45`: site-only neutral for Tools pages. Not a REAPER color.
- Classes: `.gchip--<group>` and `.gchip--<group>-bus`; SVG dots use `.sf-dot--<group>` and `.sf-dot--<group>-bus`.
- White and black chips carry a 1px `--border-strong` inset rule so they stay visible on the dark UI. Chips carry no text.

Contrast (WCAG, computed from relative luminance):
- text on bg: 16.9:1 · text-muted on surface-1: 7.0:1 · accent on bg: 10.4:1 · accent-ink on accent: 10.4:1. All pass AA, most AAA.

## Spacing & grid
- Tokens: `--s1 4px` `--s2 8px` `--s3 12px` `--s4 16px` `--s6 24px` `--s8 32px` `--s12 48px` `--s16 64px`.
- Radii: 2px (chips), 4px (cards, inputs). Nothing rounder.
- Shell: fixed left rail 232px (nav) + content max 1040px, gutter `--s8`. Under 900px: rail collapses to top bar + drawer; gutter `--s4`.
- Content blocks use a gapless grid: 12 cols, gap `--s4`, every card spans whole column groups so edges align.

## Motion
- Hover/focus: border-color + background change, `120ms ease-out`. No scale on dense cards (reading tool, not a toy).
- Palette open: opacity + 8px translateY, `140ms ease-out`.
- `prefers-reduced-motion`: all transitions 0ms.
- Focus ring: `outline: 2px solid var(--accent); outline-offset: 2px` on every interactive element.

## Components
- **App rail** — injected by `js/app.js` from one page list. Groups: Setup (Gain Staging, Routing, Mix Bus & Master), Tracks (Drums, Bass, Guitars, Vocals, Orchestral, Synths & SFX, FX Returns), Tools (Checklist, Calculators, Plugins). Each track link carries its group color chip. Active page = accent text + 1px accent rule on the right edge.
- **Page header** — breadcrumb label (condensed caps, muted), H1, **Goal** line in a bordered strip with the group chip.
- **Signal chain rack** — ordered list of slots. Each slot: slot number (mono, large, muted) · plugin name · vendor chip · role tag (EQ/COMP/SAT…) · settings grid (mono key/value pairs) · one-line "why" · alternatives row (chips labeled SLATE / JST / STOCK / OTHER). Arrow connector between slots is a 1px vertical rule.
- **Problem → Fix table** — 3 cols: Problem, Fix, Tool. Mono for values.
- **Meter ladder** — horizontal dBFS scale bar with labeled target zones (gain staging).
- **Callout** — bordered box, small icon, tone variants ok/warn/danger/info. No stripe.
- **Copy button** — on any settings block; copies plain-text settings.
- **Search palette** — Ctrl+K / `/`. Modal, input + result list, arrow keys + Enter. Index from `js/search-index.js` (prebuilt).
- **Sources** — numbered list, muted, at page foot.
