/* WAP Mix Console - search matching and ranking. Pure functions, no DOM.
   Classic script (file:// safe); also loadable in node with global.window = {}. */
(function () {
  "use strict";

  var TYPE_PLUGIN = "plugin";
  var SEPARATOR = "[^a-z0-9]*";
  var NON_ALNUM = /[^a-z0-9]+/g;

  var SCORE = {
    titleExact: 200,
    pluginNameExact: 150,
    titlePrefix: 60,
    titlePhrase: 25,
    titleWordStart: 30,
    titleContains: 15,
    secondaryWordStart: 8,
    secondaryContains: 4,
    textWordStart: 3,
    textContains: 1,
    textPhrase: 6,
    pageEntry: 5,
    usedPlugin: 12
  };

  var DEFAULT_RESULT_LIMIT = 20;
  var SNIPPET_LEAD_CHARS = 40;
  var SNIPPET_LENGTH = 160;
  var ELLIPSIS = "…";

  function compact(text) {
    return String(text || "").toLowerCase().replace(NON_ALNUM, "");
  }

  function looseBody(compactTerm) {
    return compactTerm.split("").join(SEPARATOR);
  }

  function buildTerm(compactTerm) {
    var body = looseBody(compactTerm);
    return {
      compact: compactTerm,
      isSingleChar: compactTerm.length === 1,
      contains: new RegExp(body),
      wordStart: new RegExp("(^|[^a-z0-9])(" + body + ")"),
      prefix: new RegExp("^" + SEPARATOR + body)
    };
  }

  function parseQuery(query) {
    var compactTokens = String(query || "").toLowerCase().split(/\s+/).map(compact).filter(Boolean);
    if (!compactTokens.length) return null;
    return {
      tokens: compactTokens.map(buildTerm),
      phrase: buildTerm(compactTokens.join("")),
      isMultiWord: compactTokens.length > 1
    };
  }

  function secondaryText(entry) {
    if (entry.type === TYPE_PLUGIN) return entry.vendor + " " + entry.category;
    return entry.page;
  }

  function prepareIndex(entries) {
    return entries.map(function (entry, position) {
      return {
        entry: entry,
        position: position,
        title: String(entry.title || "").toLowerCase(),
        titleCompact: compact(entry.title),
        secondary: String(secondaryText(entry) || "").toLowerCase(),
        text: String(entry.text || "").toLowerCase()
      };
    });
  }

  function fieldScore(field, term, wordStartPoints, containsPoints) {
    if (term.wordStart.test(field)) return wordStartPoints;
    if (term.contains.test(field)) return containsPoints;
    return 0;
  }

  function tokenScore(record, term) {
    return fieldScore(record.title, term, SCORE.titleWordStart, SCORE.titleContains) +
      fieldScore(record.secondary, term, SCORE.secondaryWordStart, SCORE.secondaryContains) +
      fieldScore(record.text, term, SCORE.textWordStart, SCORE.textContains);
  }

  function phraseScore(record, parsed) {
    var phrase = parsed.phrase;
    var isPlugin = record.entry.type === TYPE_PLUGIN;
    if (record.titleCompact === phrase.compact) {
      return SCORE.titleExact + (isPlugin ? SCORE.pluginNameExact : 0);
    }
    var score = 0;
    if (phrase.prefix.test(record.title)) score += SCORE.titlePrefix;
    else if (phrase.contains.test(record.title)) score += SCORE.titlePhrase;
    if (parsed.isMultiWord && phrase.contains.test(record.text)) score += SCORE.textPhrase;
    return score;
  }

  function entryBonus(entry) {
    if (entry.type === TYPE_PLUGIN) return entry.isUsedInGuide ? SCORE.usedPlugin : 0;
    return entry.anchor ? 0 : SCORE.pageEntry;
  }

  function scoreRecord(record, parsed) {
    var total = 0;
    for (var i = 0; i < parsed.tokens.length; i++) {
      var points = tokenScore(record, parsed.tokens[i]);
      if (!points) return 0;
      total += points;
    }
    return total + phraseScore(record, parsed) + entryBonus(record.entry);
  }

  function rank(records, query, limit) {
    var parsed = parseQuery(query);
    if (!parsed) return [];
    return records
      .map(function (record) { return { record: record, score: scoreRecord(record, parsed) }; })
      .filter(function (scored) { return scored.score > 0; })
      .sort(function (a, b) { return b.score - a.score || a.record.position - b.record.position; })
      .slice(0, limit || DEFAULT_RESULT_LIMIT)
      .map(function (scored) { return { entry: scored.record.entry, score: scored.score }; });
  }

  function termRanges(text, term) {
    var lower = text.toLowerCase();
    var pattern = term.isSingleChar ? term.wordStart : term.contains;
    var global = new RegExp(pattern.source, "g");
    var ranges = [];
    var match;
    while ((match = global.exec(lower)) !== null) {
      var leadLength = term.isSingleChar ? match[1].length : 0;
      var start = match.index + leadLength;
      ranges.push([start, match.index + match[0].length]);
    }
    return ranges;
  }

  function mergeRanges(ranges) {
    var sorted = ranges.slice().sort(function (a, b) { return a[0] - b[0]; });
    var merged = [];
    sorted.forEach(function (range) {
      var last = merged[merged.length - 1];
      if (last && range[0] <= last[1]) last[1] = Math.max(last[1], range[1]);
      else merged.push([range[0], range[1]]);
    });
    return merged;
  }

  function highlightRanges(text, query) {
    var parsed = parseQuery(query);
    if (!parsed || !text) return [];
    var all = [];
    parsed.tokens.forEach(function (term) { all = all.concat(termRanges(text, term)); });
    return mergeRanges(all);
  }

  function firstMatchIndex(text, parsed) {
    var lower = text.toLowerCase();
    var earliest = -1;
    parsed.tokens.forEach(function (term) {
      if (term.isSingleChar) return;
      var match = term.contains.exec(lower);
      if (match && (earliest === -1 || match.index < earliest)) earliest = match.index;
    });
    return earliest;
  }

  function snippet(text, query) {
    var source = String(text || "");
    if (source.length <= SNIPPET_LENGTH) return source;
    var parsed = parseQuery(query);
    var matchIndex = parsed ? firstMatchIndex(source, parsed) : -1;
    var start = Math.max(0, matchIndex - SNIPPET_LEAD_CHARS);
    if (start > 0) start = source.indexOf(" ", start) + 1;
    var end = Math.min(source.length, start + SNIPPET_LENGTH);
    var wordEnd = source.lastIndexOf(" ", end);
    if (end < source.length && wordEnd > start) end = wordEnd;
    return (start > 0 ? ELLIPSIS + " " : "") + source.slice(start, end) + (end < source.length ? " " + ELLIPSIS : "");
  }

  window.WAP_SEARCH = {
    TYPE_PLUGIN: TYPE_PLUGIN,
    compact: compact,
    parseQuery: parseQuery,
    prepareIndex: prepareIndex,
    scoreRecord: scoreRecord,
    rank: rank,
    highlightRanges: highlightRanges,
    snippet: snippet
  };
})();
