/* WAP Mix Console - shell behavior. Classic script, no modules (file:// safe). */
(function () {
  "use strict";

  var PAGES = [
    { slug: "gain-staging", title: "Gain Staging", group: "Setup", groupColor: "master", file: "gain-staging.html" },
    { slug: "routing", title: "Routing", group: "Setup", groupColor: "master", file: "routing.html" },
    { slug: "mix-bus", title: "Mix Bus & Master", group: "Setup", groupColor: "master", file: "mix-bus.html" },
    { slug: "drums", title: "Drums", group: "Tracks", groupColor: "drums", file: "drums.html" },
    { slug: "bass", title: "Bass", group: "Tracks", groupColor: "bass", file: "bass.html" },
    { slug: "guitars", title: "Guitars", group: "Tracks", groupColor: "guitars", file: "guitars.html" },
    { slug: "vocals", title: "Vocals", group: "Tracks", groupColor: "vocals", file: "vocals.html" },
    { slug: "orchestral", title: "Orchestral", group: "Tracks", groupColor: "orch", file: "orchestral.html" },
    { slug: "synths-sfx", title: "Synths & SFX", group: "Tracks", groupColor: "synth", file: "synths-sfx.html" },
    { slug: "fx-returns", title: "FX Returns", group: "Tracks", groupColor: "fx", file: "fx-returns.html" },
    { slug: "checklist", title: "Checklist", group: "Tools", groupColor: "none", file: "checklist.html" },
    { slug: "calculators", title: "Calculators", group: "Tools", groupColor: "none", file: "calculators.html" },
    { slug: "plugins", title: "Plugins", group: "Tools", groupColor: "none", file: "plugins.html" }
  ];
  var GROUPS = ["Setup", "Tracks", "Tools"];

  var ICONS = {
    search: '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
    menu: '<line x1="4" x2="20" y1="6" y2="6"/><line x1="4" x2="20" y1="12" y2="12"/><line x1="4" x2="20" y1="18" y2="18"/>',
    close: '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
    copy: '<rect width="14" height="14" x="8" y="8" rx="2" ry="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/>',
    check: '<path d="M20 6 9 17l-5-5"/>'
  };

  function icon(name) {
    return '<svg class="icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false">' + ICONS[name] + "</svg>";
  }

  function escapeHtml(text) {
    return String(text)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function isTypingTarget(el) {
    if (!el) return false;
    var tag = el.tagName;
    return tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT" || el.isContentEditable;
  }

  /* ---------------------------------------------------------------- rail */
  function buildRail() {
    var rail = document.getElementById("rail");
    if (!rail) return;
    var current = document.body.dataset.page || "";
    rail.classList.add("rail");
    rail.setAttribute("aria-label", "Primary");

    var html = '<div class="rail__bar">' +
      '<a class="rail__brand" href="index.html"' + (current === "home" ? ' aria-current="page"' : "") + '>' +
      '<span class="rail__mark" aria-hidden="true"></span>WAP Mix Console</a>' +
      '<button type="button" class="rail__search" data-open-search aria-label="Search (Ctrl+K)">' +
      icon("search") + '<span class="rail__search-text">Search</span><kbd>Ctrl K</kbd></button>' +
      '<button type="button" class="rail__menu" aria-expanded="false" aria-controls="rail-drawer" aria-label="Open menu">' +
      icon("menu") + "</button>" +
      "</div>" +
      '<div class="rail__drawer" id="rail-drawer">';

    GROUPS.forEach(function (group) {
      html += '<div class="rail__group"><div class="rail__group-title label">' + group + '</div><ul class="rail__list">';
      PAGES.filter(function (p) { return p.group === group; }).forEach(function (p) {
        var active = p.slug === current;
        var chip = p.group === "Tracks"
          ? '<span class="gchip gchip--' + p.groupColor + '" aria-hidden="true"></span>'
          : '<span class="rail__dot" aria-hidden="true"></span>';
        html += '<li><a class="rail__link" href="' + p.file + '"' + (active ? ' aria-current="page"' : "") + ">" +
          chip + "<span>" + escapeHtml(p.title) + "</span></a></li>";
      });
      html += "</ul></div>";
    });
    html += "</div>";
    rail.innerHTML = html;

    var menuBtn = rail.querySelector(".rail__menu");
    function setDrawer(open) {
      rail.classList.toggle("is-open", open);
      menuBtn.setAttribute("aria-expanded", open ? "true" : "false");
      menuBtn.setAttribute("aria-label", open ? "Close menu" : "Open menu");
      menuBtn.innerHTML = icon(open ? "close" : "menu");
    }
    menuBtn.addEventListener("click", function () {
      setDrawer(!rail.classList.contains("is-open"));
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && rail.classList.contains("is-open")) {
        setDrawer(false);
        menuBtn.focus();
      }
    });
    rail.querySelectorAll(".rail__link").forEach(function (link) {
      link.addEventListener("click", function () { setDrawer(false); });
    });
  }

  /* ---------------------------------------------------------------- copy buttons */
  function textForCopy(target) {
    var items = target.querySelectorAll("dt");
    if (items.length) {
      var lines = [];
      items.forEach(function (dt) {
        var dd = dt.nextElementSibling;
        lines.push(dt.textContent.trim() + ": " + (dd ? dd.textContent.trim() : ""));
      });
      var heading = target.getAttribute("data-copy-title");
      return (heading ? heading + "\n" : "") + lines.join("\n");
    }
    return target.innerText.trim();
  }

  function writeClipboard(text) {
    if (navigator.clipboard && window.isSecureContext !== false) {
      return navigator.clipboard.writeText(text).catch(function () { return legacyCopy(text); });
    }
    return legacyCopy(text);
  }

  function legacyCopy(text) {
    return new Promise(function (resolve, reject) {
      var area = document.createElement("textarea");
      area.value = text;
      area.setAttribute("readonly", "");
      area.className = "visually-hidden";
      document.body.appendChild(area);
      area.select();
      var ok = false;
      try { ok = document.execCommand("copy"); } catch (err) { ok = false; }
      document.body.removeChild(area);
      if (ok) resolve(); else reject(new Error("copy failed"));
    });
  }

  function initCopyButtons() {
    document.querySelectorAll("[data-copy]").forEach(function (btn) {
      if (!btn.innerHTML.trim()) btn.innerHTML = icon("copy") + "<span>Copy</span>";
      var label = btn.querySelector("span");
      var timer = null;
      btn.addEventListener("click", function () {
        var target = document.getElementById(btn.getAttribute("data-copy"));
        if (!target) return;
        writeClipboard(textForCopy(target)).then(function () {
          btn.classList.add("is-copied");
          if (label) label.textContent = "Copied";
          clearTimeout(timer);
          timer = setTimeout(function () {
            btn.classList.remove("is-copied");
            if (label) label.textContent = "Copy";
          }, 1200);
        }, function () {
          if (label) label.textContent = "Failed";
        });
      });
    });
  }

  /* ---------------------------------------------------------------- search palette */
  var SEARCH_RESULT_LIMIT = 20;
  var PLUGIN_QUERY_HASH_PREFIX = "#q=";
  var LANDING_HIGHLIGHT_MS = 1600;
  var LANDING_HEADING_TAGS = { H1: true, H2: true, H3: true, H4: true };
  var preparedRecords = null;
  var landingHighlightTimer = null;

  function isPluginEntry(entry) {
    return entry.type === window.WAP_SEARCH.TYPE_PLUGIN;
  }

  function search(query) {
    var index = window.WAP_SEARCH_INDEX || [];
    if (!query.trim()) {
      return index.filter(function (e) { return !isPluginEntry(e) && !e.anchor; });
    }
    if (!preparedRecords) preparedRecords = window.WAP_SEARCH.prepareIndex(index);
    return window.WAP_SEARCH.rank(preparedRecords, query, SEARCH_RESULT_LIMIT)
      .map(function (result) { return result.entry; });
  }

  function hrefFor(entry) {
    if (isPluginEntry(entry)) return entry.file + PLUGIN_QUERY_HASH_PREFIX + encodeURIComponent(entry.title);
    return entry.file + (entry.anchor ? "#" + entry.anchor : "");
  }

  function highlightHtml(text, query) {
    var ranges = window.WAP_SEARCH.highlightRanges(text, query);
    var html = "";
    var cursor = 0;
    ranges.forEach(function (range) {
      html += escapeHtml(text.slice(cursor, range[0])) +
        '<mark class="palette__mark">' + escapeHtml(text.slice(range[0], range[1])) + "</mark>";
      cursor = range[1];
    });
    return html + escapeHtml(text.slice(cursor));
  }

  function resultContextText(entry) {
    if (isPluginEntry(entry)) return entry.vendor + " · " + entry.category;
    return entry.page;
  }

  function resultSnippetText(entry, query) {
    if (isPluginEntry(entry)) return entry.text ? "Used on " + entry.text : "Not used in the guide";
    return window.WAP_SEARCH.snippet(entry.text, query);
  }

  function resultItemHtml(entry, i, isSelected, query) {
    var typeLabel = isPluginEntry(entry) ? "Plugin" : "Section";
    var snippetText = resultSnippetText(entry, query);
    return '<li><a class="palette__item" role="option" id="palette-opt-' + i + '" href="' + escapeHtml(hrefFor(entry)) + '"' +
      ' aria-selected="' + isSelected + '" data-index="' + i + '" tabindex="-1">' +
      '<span class="palette__item-head">' +
      '<span class="palette__item-title">' + highlightHtml(entry.title, query) + "</span>" +
      '<span class="palette__type label">' + typeLabel + "</span>" +
      "</span>" +
      '<span class="palette__item-page">' + escapeHtml(resultContextText(entry)) + "</span>" +
      (snippetText ? '<span class="palette__item-snippet">' + highlightHtml(snippetText, query) + "</span>" : "") +
      "</a></li>";
  }

  function currentPageFile() {
    return window.location.pathname.split("/").pop() || "index.html";
  }

  function landingTarget() {
    var hash = window.location.hash;
    if (!hash || hash.indexOf(PLUGIN_QUERY_HASH_PREFIX) === 0) return null;
    var target = document.getElementById(hash.slice(1));
    return target && LANDING_HEADING_TAGS[target.tagName] ? target : null;
  }

  function highlightLandingTarget() {
    var target = landingTarget();
    if (!target) return;
    target.scrollIntoView({ block: "start" });
    target.classList.add("is-landed");
    clearTimeout(landingHighlightTimer);
    landingHighlightTimer = setTimeout(function () { target.classList.remove("is-landed"); }, LANDING_HIGHLIGHT_MS);
  }

  function initLandingHighlight() {
    highlightLandingTarget();
    window.addEventListener("hashchange", highlightLandingTarget);
  }

  function initPalette() {
    var root = document.createElement("div");
    root.className = "palette";
    root.innerHTML =
      '<button type="button" class="palette__backdrop" tabindex="-1" aria-label="Close search"></button>' +
      '<div class="palette__panel" role="dialog" aria-modal="true" aria-label="Search">' +
      '<div class="palette__field">' + icon("search") +
      '<input class="palette__input" type="text" placeholder="Search pages, sections and plugins" autocomplete="off" spellcheck="false"' +
      ' role="combobox" aria-expanded="true" aria-controls="palette-results" aria-autocomplete="list">' +
      '<kbd>Esc</kbd></div>' +
      '<ul class="palette__results" id="palette-results" role="listbox"></ul>' +
      '<div class="palette__foot"><span><kbd>Up</kbd> <kbd>Down</kbd> move</span><span><kbd>Enter</kbd> open</span><span><kbd>Esc</kbd> close</span></div>' +
      "</div>";
    document.body.appendChild(root);

    var input = root.querySelector(".palette__input");
    var list = root.querySelector(".palette__results");
    var results = [];
    var selected = 0;
    var returnFocus = null;

    function render() {
      results = search(input.value);
      if (!results.length) {
        list.innerHTML = '<li class="palette__empty">No matches.</li>';
        input.removeAttribute("aria-activedescendant");
        return;
      }
      if (selected >= results.length) selected = results.length - 1;
      list.innerHTML = results.map(function (entry, i) {
        return resultItemHtml(entry, i, i === selected, input.value);
      }).join("");
      input.setAttribute("aria-activedescendant", "palette-opt-" + selected);
    }

    function move(delta) {
      if (!results.length) return;
      selected = (selected + delta + results.length) % results.length;
      list.querySelectorAll(".palette__item").forEach(function (el, i) {
        el.setAttribute("aria-selected", i === selected ? "true" : "false");
        if (i === selected) el.scrollIntoView({ block: "nearest" });
      });
      input.setAttribute("aria-activedescendant", "palette-opt-" + selected);
    }

    function open() {
      if (root.classList.contains("is-open")) return;
      returnFocus = document.activeElement;
      root.classList.add("is-open");
      input.value = "";
      selected = 0;
      render();
      input.focus();
    }

    function close() {
      root.classList.remove("is-open");
      if (returnFocus && returnFocus.focus) returnFocus.focus();
    }

    function go(entry) {
      close();
      var href = hrefFor(entry);
      var hash = href.slice(entry.file.length);
      var isSameLocation = entry.file === currentPageFile() && hash === window.location.hash;
      // Re-selecting the current URL fires no hashchange, so replay it for the landing highlight and plugin filter.
      if (isSameLocation) window.dispatchEvent(new Event("hashchange"));
      else window.location.href = href;
    }

    input.addEventListener("input", function () { selected = 0; render(); });
    input.addEventListener("keydown", function (e) {
      if (e.key === "ArrowDown") { e.preventDefault(); move(1); }
      else if (e.key === "ArrowUp") { e.preventDefault(); move(-1); }
      else if (e.key === "Enter") { e.preventDefault(); if (results[selected]) go(results[selected]); }
      else if (e.key === "Escape") { e.preventDefault(); close(); }
      else if (e.key === "Tab") { e.preventDefault(); }
    });
    list.addEventListener("click", function (e) {
      var item = e.target.closest(".palette__item");
      if (!item) return;
      e.preventDefault();
      go(results[Number(item.getAttribute("data-index"))]);
    });
    list.addEventListener("mousemove", function (e) {
      var item = e.target.closest(".palette__item");
      if (!item) return;
      var i = Number(item.getAttribute("data-index"));
      if (i !== selected) move(i - selected);
    });
    root.querySelector(".palette__backdrop").addEventListener("click", close);

    document.addEventListener("keydown", function (e) {
      var isCtrlK = (e.ctrlKey || e.metaKey) && (e.key === "k" || e.key === "K");
      var isSlash = e.key === "/" && !e.ctrlKey && !e.metaKey && !e.altKey && !isTypingTarget(document.activeElement);
      if (isCtrlK || isSlash) {
        e.preventDefault();
        open();
      }
    });
    document.querySelectorAll("[data-open-search]").forEach(function (btn) {
      btn.addEventListener("click", open);
    });
  }

  document.addEventListener("DOMContentLoaded", function () {
    buildRail();
    initCopyButtons();
    initPalette();
    initLandingHighlight();
  });
})();
