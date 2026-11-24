// Rebuilds docs/js/plugins-data.js from the local plugin scan and the manuals index.
// data/ and manuals/ stay out of the public repo, so the generated file is the only artifact.
// It must never carry local paths. Run: node scripts/build-plugins-data.js
const fs = require('fs');
const path = require('path');

const rootDir = path.join(__dirname, '..');
const docsDir = path.join(rootDir, 'docs');
const pluginsJsonPath = path.join(rootDir, 'data', 'plugins.json');
const manualsIndexPath = path.join(rootDir, 'manuals', 'index.tsv');
const appJsPath = path.join(docsDir, 'js', 'app.js');
const outputPath = path.join(docsDir, 'js', 'plugins-data.js');

// Pages that list or compute, not pages that recommend plugins.
const PAGES_NOT_SCANNED = new Set(['index', 'plugins', 'calculators']);

// The scan guessed categories from file names. These guesses were wrong.
const CATEGORY_OVERRIDES = {
  'Coffee The Pun': 'channel-strip',
  'Coffee The Pun ZL': 'channel-strip',
};

// Scan names that are file names, not product names.
const DISPLAY_NAMES = {
  'Auburn Sounds Graillon 2': 'Graillon 2',
  'COFFEEPUN': 'Coffee The Pun',
  'COFFEEPUNZL': 'Coffee The Pun ZL',
  'GGD Smash and Grab v2': 'Smash and Grab 2',
  'ANA2': 'ANA 2',
  'JSTClip': 'JST Clip',
  'Toneforge - Misha Mansoor': 'Toneforge Misha Mansoor',
  'Toneforge - Misha Mansoor Advanced': 'Toneforge Misha Mansoor Advanced',
  'Harrison_De-Esser': 'Harrison De-Esser',
  'iZOzoneImager2': 'iZotope Ozone Imager 2',
  'iZOzoneSBImager': 'iZotope Ozone SB Imager',
  'iZTonalBalanceControl2': 'iZotope Tonal Balance Control 2',
  'iZRelay': 'iZotope Relay',
  'iZVinyl': 'iZotope Vinyl',
  'helm64': 'helm',
  'Obxd64': 'OB-Xd',
  'Obelisk64': 'Obelisk',
};

// Extra phrases a page may use for a plugin. Matched like names.
const EXTRA_ALIASES = {
  'Coffee The Pun': ['Coffee'],
  'Eiosis E2Deesser': ['E2Deesser', 'E2 Deesser'],
  'JST Clip': ['JSTClip'],
  'Smash and Grab 2': ['Smash and Grab', 'Smash & Grab'],
  'VM VCC MixBuss': ['VCC MixBuss', 'Slate VCC', 'Virtual Console Collection'],
  'VM FG-2A': ['FG-2A'],
  'VM SD-3A': ['SD-3A'],
};

// Single words that also mean something else in mixing prose.
const AMBIGUOUS_WORDS = new Set([
  'anvil', 'center', 'crack', 'relay', 'soar', 'temper', 'tick', 'surge', 'unlimited',
  'helm', 'emissary', 'supercharger', 'transify', 'multipass', 'disperser', 'kontakt',
  'reaktor', 'sitala', 'vastaus', 'dexed', 'trigger', 'inphase', 'repeater', 'buzzcut',
  'alterego', 'faturator', 'subdestroyer', 'sidewidener', 'gainstager', 'mikko',
]);
// Ambiguous words still count when the page writes them with this exact casing.
const CASE_SENSITIVE_OK = new Set(['Repeater', 'Kontakt', 'InPhase', 'SubDestroyer', 'Sidewidener', 'SideWidener', 'GainStager', 'BuzzCut', 'Disperser', 'Multipass', 'Faturator']);

function cleanScanName(raw) {
  if (DISPLAY_NAMES[raw]) return DISPLAY_NAMES[raw];
  return raw
    .replace(/-vst$/i, '')
    .replace(/[-.]x64$/i, '')
    .replace(/\s*\((64 Bit|64)\)$/i, '')
    .replace(/^Dragonfly(\w+?)(Reverb)?$/, (m, kind, reverb) => 'Dragonfly ' + kind.replace(/([a-z])([A-Z])/g, '$1 $2') + (reverb ? ' Reverb' : ''))
    .trim();
}

// Splits camel case and letter/digit joins, so "Ozone 9Maximizer" and "soothe2" line up with page prose.
function normalize(text) {
  return String(text)
    .replace(/([a-z])([A-Z])/g, '$1 $2')
    .replace(/([A-Z]+)([A-Z][a-z])/g, '$1 $2')
    .replace(/([A-Za-z])(\d)/g, '$1 $2')
    .replace(/(\d)([A-Za-z])/g, '$1 $2')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

function compact(text) {
  return normalize(text).replace(/ /g, '');
}

function stripTags(html) {
  return html
    .replace(/<script[\s\S]*?<\/script>/g, ' ')
    .replace(/<svg[\s\S]*?<\/svg>/g, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&ndash;|&mdash;/g, '-')
    .replace(/&amp;/g, '&').replace(/&gt;/g, '>').replace(/&lt;/g, '<')
    .replace(/&[a-z]+;/g, ' ')
    .replace(/\s+/g, ' ');
}

function readPageOrder() {
  const source = fs.readFileSync(appJsPath, 'utf8');
  const pattern = /slug:\s*"([^"]+)",\s*title:\s*"([^"]+)"/g;
  return [...source.matchAll(pattern)].map(m => ({ slug: m[1], title: m[2] }));
}

function readPages(pageOrder) {
  return pageOrder
    .filter(p => !PAGES_NOT_SCANNED.has(p.slug))
    .filter(p => fs.existsSync(path.join(docsDir, p.slug + '.html')))
    .map(p => {
      const text = stripTags(fs.readFileSync(path.join(docsDir, p.slug + '.html'), 'utf8'));
      return { slug: p.slug, raw: text, normalized: ' ' + normalize(text) + ' ' };
    });
}

function matchPhrasesFor(name) {
  const phrases = new Set([name]);
  (EXTRA_ALIASES[name] || []).forEach(a => phrases.add(a));
  // "VM FG-116 Vintage" is written "FG-116 Vintage" on pages. Keep the prefix when the rest is a plain word.
  const prefixed = name.match(/^(VM|VBC|VMR)\s+(.+)$/);
  if (prefixed && (/[\d-]/.test(prefixed[2]) || normalize(prefixed[2]).indexOf(' ') !== -1)) phrases.add(prefixed[2]);
  const kilohearts = name.match(/^kHs\s+(.+)$/);
  if (kilohearts) phrases.add('Kilohearts ' + kilohearts[1]);
  return [...phrases];
}

function pageMentions(page, phrase) {
  const needle = normalize(phrase);
  if (!needle) return false;
  const isSingleWord = needle.indexOf(' ') === -1;
  if (isSingleWord && (needle.length < 4 || AMBIGUOUS_WORDS.has(needle))) {
    if (!CASE_SENSITIVE_OK.has(phrase)) return false;
    return new RegExp('(^|[^A-Za-z0-9])' + phrase.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '([^A-Za-z0-9]|$)').test(page.raw);
  }
  return page.normalized.indexOf(' ' + needle + ' ') !== -1;
}

function readManualRows() {
  const lines = fs.readFileSync(manualsIndexPath, 'utf8').replace(/^﻿/, '').split(/\r?\n/).slice(1);
  return lines
    .map(line => line.split('\t'))
    .filter(cols => cols.length >= 2 && cols[1])
    .map(([vendor, plugin, , officialUrl = '', status = '']) => {
      const urlMatch = officialUrl.trim().match(/^https?:\/\/\S+/);
      const parts = plugin
        .replace(/\([^)]*\)/g, ' ')
        .replace(/(\d)\.0\b/g, '$1')
        .split('/')
        .map(s => s.trim())
        .filter(Boolean);
      // "VM FG-116 Vintage / Modern" means "VM FG-116 Modern" for the second part.
      const firstStem = parts.length ? parts[0].split(/\s+/).slice(0, -1).join(' ') : '';
      const names = parts.map((part, i) => (i > 0 && firstStem && !/\s/.test(part) && !/\d|-/.test(part)) ? firstStem + ' ' + part : part);
      return {
        vendor: vendor.trim(),
        keys: names.map(normalize).filter(k => k.replace(/ /g, '').length >= 3),
        url: status.trim() !== 'none' && urlMatch ? urlMatch[0] : '',
        status: status.trim() || 'none',
      };
    });
}

const STATUS_RANK = { pdf: 0, html: 1, 'product-page': 2 };

// A prefix of up to this many letters may differ: "VBC FG-Red" vs "FG-Red", "Eiosis E2Deesser" vs "E2Deesser".
const MAX_PREFIX_CHARS = 7;

// Loose match: equal ignoring spacing, or one name is the other plus a short prefix at a word boundary.
function namesMatch(a, b) {
  if (a.replace(/ /g, '') === b.replace(/ /g, '')) return true;
  const [longer, shorter] = a.length >= b.length ? [a, b] : [b, a];
  return shorter.replace(/ /g, '').length >= 4 &&
    longer.endsWith(' ' + shorter) &&
    longer.length - shorter.length - 1 <= MAX_PREFIX_CHARS;
}

function findManual(name, rows) {
  const key = normalize(name);
  const hits = rows.filter(row => row.keys.some(k => namesMatch(k, key)));
  if (!hits.length) return null;
  const withUrl = hits
    .filter(h => h.url)
    .sort((a, b) => (STATUS_RANK[a.status] ?? 9) - (STATUS_RANK[b.status] ?? 9));
  return { vendor: hits[0].vendor, url: withUrl.length ? withUrl[0].url : '', status: withUrl.length ? withUrl[0].status : 'none' };
}

function isGenericVendor(vendor) {
  return /other|unknown/i.test(vendor);
}

// The scan is written by PowerShell, which adds a UTF-8 BOM.
const scan = JSON.parse(fs.readFileSync(pluginsJsonPath, 'utf8').replace(/^﻿/, ''));
const pageOrder = readPageOrder();
const pages = readPages(pageOrder);
const manualRows = readManualRows();

const byKey = new Map();
for (const vendorGroup of scan.vendors) {
  for (const plugin of vendorGroup.plugins) {
    const name = cleanScanName(plugin.name);
    const key = compact(name);
    const existing = byKey.get(key);
    if (existing) {
      (plugin.formats || []).forEach(f => { if (!existing.formats.includes(f)) existing.formats.push(f); });
      if (isGenericVendor(existing.vendor) && !isGenericVendor(vendorGroup.vendor)) existing.vendor = vendorGroup.vendor;
      continue;
    }
    byKey.set(key, {
      name,
      vendor: vendorGroup.vendor,
      category: CATEGORY_OVERRIDES[name] || plugin.category || 'other',
      formats: (plugin.formats || []).slice(),
    });
  }
}

const plugins = [...byKey.values()].map(p => {
  const phrases = matchPhrasesFor(p.name);
  const usedOn = pages.filter(page => phrases.some(phrase => pageMentions(page, phrase))).map(page => page.slug);
  const manual = findManual(p.name, manualRows);
  let vendor = manual && isGenericVendor(p.vendor) ? manual.vendor : p.vendor;
  if (isGenericVendor(vendor) && /^Coffee The Pun/.test(p.name)) vendor = 'Acustica Audio';
  return {
    name: p.name,
    vendor,
    category: p.category,
    formats: p.formats.sort(),
    usedOn,
    manualUrl: manual ? manual.url : '',
    manualStatus: manual ? manual.status : 'none',
  };
}).sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()));

const pageTitles = {};
pageOrder.forEach(p => { pageTitles[p.slug] = p.title; });

const output =
  '/* Generated by scripts/build-plugins-data.js. Do not edit by hand. */\n' +
  'window.WAP_PLUGIN_PAGES = ' + JSON.stringify(pageTitles) + ';\n' +
  'window.WAP_PLUGINS = [\n' +
  plugins.map(p => '  ' + JSON.stringify(p)).join(',\n') +
  '\n];\n';

// The site is public. Refuse to write anything that looks like a local path or user folder.
const leak = output.match(/[A-Za-z]:\\|\\\\|Users[\\/]|AppData|ProgramData|Program Files/);
if (leak) {
  console.error('refusing to write: local path fragment found: ' + leak[0]);
  process.exit(1);
}

fs.writeFileSync(outputPath, output);
const usedCount = plugins.filter(p => p.usedOn.length).length;
const manualCount = plugins.filter(p => p.manualUrl).length;
console.log(`wrote ${plugins.length} plugins (${usedCount} used in guide, ${manualCount} with manual links) to docs/js/plugins-data.js`);
