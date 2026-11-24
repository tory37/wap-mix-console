/* WAP Mix Console - plugin list. Classic script, no modules (file:// safe).
   Data: window.WAP_PLUGINS and window.WAP_PLUGIN_PAGES from js/plugins-data.js. */
(function () {
  "use strict";

  var MANUAL_STATUS_LABEL = { pdf: "PDF", html: "Docs", "product-page": "Product page" };
  var QUERY_HASH_PREFIX = "#q=";

  function escapeHtml(text) {
    return String(text)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function uniqueSorted(values) {
    var seen = {};
    values.forEach(function (v) { seen[v] = true; });
    return Object.keys(seen).sort(function (a, b) { return a.toLowerCase().localeCompare(b.toLowerCase()); });
  }

  function optionsHtml(values) {
    return values.map(function (v) {
      return '<option value="' + escapeHtml(v) + '">' + escapeHtml(v) + "</option>";
    }).join("");
  }

  function isSafeUrl(url) {
    return /^https:\/\//.test(url);
  }

  function rowHtml(plugin, pageTitles) {
    var used = plugin.usedOn.length
      ? '<ul class="page-links">' + plugin.usedOn.map(function (slug) {
          return '<li><a href="' + escapeHtml(slug) + '.html">' + escapeHtml(pageTitles[slug] || slug) + "</a></li>";
        }).join("") + "</ul>"
      : '<span class="muted">-</span>';

    var manual = plugin.manualUrl && isSafeUrl(plugin.manualUrl)
      ? '<a href="' + escapeHtml(plugin.manualUrl) + '" target="_blank" rel="noopener" aria-label="Manual for ' +
        escapeHtml(plugin.name) + ' (opens in a new tab)">Manual</a>' +
        (MANUAL_STATUS_LABEL[plugin.manualStatus] ? ' <span class="chip">' + MANUAL_STATUS_LABEL[plugin.manualStatus] + "</span>" : "")
      : '<span class="muted">-</span>';

    return "<tr>" +
      '<th scope="row" class="plugin-name">' + escapeHtml(plugin.name) +
      '<span class="plugin-formats">' + escapeHtml(plugin.formats.join(" / ")) + "</span></th>" +
      "<td>" + escapeHtml(plugin.vendor) + "</td>" +
      '<td><span class="tag">' + escapeHtml(plugin.category) + "</span></td>" +
      "<td>" + used + "</td>" +
      '<td class="plugin-manual">' + manual + "</td>" +
      "</tr>";
  }

  function init() {
    var plugins = window.WAP_PLUGINS || [];
    var pageTitles = window.WAP_PLUGIN_PAGES || {};
    var form = document.getElementById("plugin-filters");
    var query = document.getElementById("plugin-query");
    var vendor = document.getElementById("plugin-vendor");
    var category = document.getElementById("plugin-category");
    var usedOnly = document.getElementById("plugin-used");
    var body = document.getElementById("plugin-rows");
    var count = document.getElementById("plugin-count");
    if (!form || !body) return;

    vendor.insertAdjacentHTML("beforeend", optionsHtml(uniqueSorted(plugins.map(function (p) { return p.vendor; }))));
    category.insertAdjacentHTML("beforeend", optionsHtml(uniqueSorted(plugins.map(function (p) { return p.category; }))));

    var haystacks = plugins.map(function (p) {
      return [p.name, p.vendor, p.category, p.usedOn.map(function (s) { return pageTitles[s] || s; }).join(" ")].join(" ").toLowerCase();
    });

    function render() {
      var tokens = query.value.toLowerCase().split(/\s+/).filter(Boolean);
      var matches = plugins.filter(function (p, i) {
        if (vendor.value && p.vendor !== vendor.value) return false;
        if (category.value && p.category !== category.value) return false;
        if (usedOnly.checked && !p.usedOn.length) return false;
        return tokens.every(function (t) { return haystacks[i].indexOf(t) !== -1; });
      });

      body.innerHTML = matches.length
        ? matches.map(function (p) { return rowHtml(p, pageTitles); }).join("")
        : '<tr><td colspan="5" class="muted">No plugins match these filters.</td></tr>';
      count.textContent = matches.length + " of " + plugins.length + " plugins";
    }

    function applyQueryFromHash() {
      var hash = window.location.hash;
      if (hash.indexOf(QUERY_HASH_PREFIX) !== 0) return;
      try {
        query.value = decodeURIComponent(hash.slice(QUERY_HASH_PREFIX.length));
      } catch (malformedHash) {
        return;
      }
      vendor.value = "";
      category.value = "";
      usedOnly.checked = false;
      render();
      query.scrollIntoView({ block: "start" });
    }

    form.addEventListener("submit", function (e) { e.preventDefault(); });
    window.addEventListener("hashchange", applyQueryFromHash);
    query.addEventListener("input", render);
    vendor.addEventListener("change", render);
    category.addEventListener("change", render);
    usedOnly.addEventListener("change", render);
    render();
    applyQueryFromHash();
  }

  document.addEventListener("DOMContentLoaded", init);
})();
