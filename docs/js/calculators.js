/* WAP Mix Console - calculators. Classic script, no modules (file:// safe).
   Pure math lives on window.WAP_CALC so Node tests can load it without a DOM. */
(function (root) {
  "use strict";

  /* ================================================================ pure math */

  var NOTE_NAMES = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"];
  var SHARP_TO_FLAT = { "C#": "Db", "D#": "Eb", "F#": "Gb", "G#": "Ab", "A#": "Bb" };
  var A4_HZ = 440;
  var A4_MIDI = 69;

  var DIVISIONS = [1, 2, 4, 8, 16, 32, 64];
  var FEEL_FACTOR = { straight: 1, dotted: 1.5, triplet: 2 / 3 };

  // Reference values for normalization targets. Platforms change these; check before release.
  var PLATFORMS = [
    { name: "Spotify (Normal)", target: -14 },
    { name: "Spotify (Loud)", target: -11 },
    { name: "Apple Music (Sound Check)", target: -16 },
    { name: "YouTube", target: -14 },
    { name: "Tidal", target: -14 },
    { name: "Amazon Music", target: -14 }
  ];

  // Low string first. Drop tunings: low note, then a fifth, then standard 7-string intervals.
  var DROP_INTERVALS = [0, 7, 12, 17, 22, 26, 31];
  var STANDARD_INTERVALS = [0, 5, 10, 15, 20, 24, 29];
  var TUNINGS = [
    { id: "drop-g", label: "7-string Drop G", lowMidi: 31, intervals: DROP_INTERVALS },
    { id: "drop-ab", label: "7-string Drop Ab", lowMidi: 32, intervals: DROP_INTERVALS },
    { id: "drop-a", label: "7-string Drop A", lowMidi: 33, intervals: DROP_INTERVALS },
    { id: "drop-bb", label: "7-string Drop Bb", lowMidi: 34, intervals: DROP_INTERVALS },
    { id: "standard-b", label: "7-string standard B (reference)", lowMidi: 35, intervals: STANDARD_INTERVALS }
  ];

  // Values the guide pages already state. The calculator quotes them, it does not derive them.
  var GUIDE = {
    bassHpfLow: 30,
    bassHpfHigh: 35,
    rhythmHpfLow: 85,
    rhythmHpfHigh: 100,
    kickPunchLow: 50,
    kickPunchHigh: 70,
    loudnessTargetLoud: -7.5,
    loudnessTargetQuiet: -8.5,
    loudnessCeiling: -7,
    truePeakMax: -1,
    spotifyLoudTruePeak: -2,
    spotifyReference: -14
  };

  function isNumber(n) {
    return typeof n === "number" && isFinite(n);
  }

  function quarterMs(bpm) {
    return 60000 / bpm;
  }

  // division: 4 = quarter note, 8 = eighth. feel: straight | dotted | triplet.
  function noteMs(bpm, division, feel) {
    if (!(bpm > 0) || !(division > 0)) return NaN;
    var factor = FEEL_FACTOR[feel || "straight"];
    return quarterMs(bpm) * (4 / division) * factor;
  }

  function msToHz(ms) {
    return ms > 0 ? 1000 / ms : NaN;
  }

  function tempoTable(bpm) {
    return DIVISIONS.map(function (division) {
      var row = { division: division };
      Object.keys(FEEL_FACTOR).forEach(function (feel) {
        var ms = noteMs(bpm, division, feel);
        row[feel] = { ms: ms, hz: msToHz(ms) };
      });
      return row;
    });
  }

  function tempoSuggestions(bpm) {
    var preDelay = noteMs(bpm, 64);
    return {
      preDelay64: preDelay,
      preDelay128: noteMs(bpm, 128),
      decayQuarter: noteMs(bpm, 4) - preDelay,
      decayHalf: noteMs(bpm, 2) - preDelay,
      decayBar: noteMs(bpm, 1) - preDelay,
      release8: noteMs(bpm, 8),
      release16: noteMs(bpm, 16)
    };
  }

  function dbToLinear(db) {
    return Math.pow(10, db / 20);
  }

  function linearToDb(linear) {
    return linear > 0 ? 20 * Math.log10(linear) : NaN;
  }

  function sumDb(values) {
    return values.reduce(function (total, v) { return total + v; }, 0);
  }

  function clipPctToDbfs(pct) {
    return pct > 0 ? 20 * Math.log10(pct / 100) : NaN;
  }

  function dbfsToClipPct(dbfs) {
    return 100 * Math.pow(10, dbfs / 20);
  }

  // Positive result = dB the platform turns the master down. 0 when the master is at or below target.
  function turnDown(lufs, target) {
    return Math.max(0, lufs - target);
  }

  function truePeakVerdict(lufs, truePeak) {
    if (truePeak > GUIDE.truePeakMax) return "over-ceiling";
    if (truePeak > GUIDE.spotifyLoudTruePeak && lufs > GUIDE.spotifyReference) return "spotify-loud";
    return "ok";
  }

  function loudnessVsTarget(lufs) {
    if (lufs > GUIDE.loudnessCeiling) return "too-loud";
    if (lufs > GUIDE.loudnessTargetLoud) return "above-target";
    if (lufs >= GUIDE.loudnessTargetQuiet) return "on-target";
    return "below-target";
  }

  function midiToHz(midi) {
    return A4_HZ * Math.pow(2, (midi - A4_MIDI) / 12);
  }

  function hzToMidi(hz) {
    return hz > 0 ? A4_MIDI + 12 * Math.log2(hz / A4_HZ) : NaN;
  }

  function noteIndex(name) {
    var clean = String(name).trim();
    if (!clean) return -1;
    clean = clean.charAt(0).toUpperCase() + clean.slice(1);
    clean = SHARP_TO_FLAT[clean] || clean;
    return NOTE_NAMES.indexOf(clean);
  }

  function noteToMidi(name, octave) {
    var index = noteIndex(name);
    if (index < 0 || !isNumber(octave)) return NaN;
    return 12 * (octave + 1) + index;
  }

  function noteToHz(name, octave) {
    var midi = noteToMidi(name, octave);
    return isNumber(midi) ? midiToHz(midi) : NaN;
  }

  function midiToName(midi) {
    var rounded = Math.round(midi);
    var index = ((rounded % 12) + 12) % 12;
    return NOTE_NAMES[index] + (Math.floor(rounded / 12) - 1);
  }

  function nearestNote(hz) {
    var exact = hzToMidi(hz);
    if (!isNumber(exact)) return null;
    var midi = Math.round(exact);
    return {
      midi: midi,
      name: midiToName(midi),
      hz: midiToHz(midi),
      cents: (exact - midi) * 100
    };
  }

  function tuningById(id) {
    for (var i = 0; i < TUNINGS.length; i++) {
      if (TUNINGS[i].id === id) return TUNINGS[i];
    }
    return null;
  }

  // Strings low (7) to high (1).
  function tuningStrings(id) {
    var tuning = tuningById(id);
    if (!tuning) return [];
    return tuning.intervals.map(function (interval, i) {
      var midi = tuning.lowMidi + interval;
      return { string: 7 - i, midi: midi, name: midiToName(midi), hz: midiToHz(midi) };
    });
  }

  function tuningZones(id) {
    var strings = tuningStrings(id);
    if (!strings.length) return null;
    var low = strings[0].hz;
    return {
      lowName: strings[0].name,
      lowHz: low,
      secondHarmonicHz: low * 2,
      guitarFloorHz: low * 0.9,
      bassUnisonName: strings[0].name,
      bassUnisonHz: low,
      bassOctaveName: midiToName(strings[0].midi - 12),
      bassOctaveHz: low / 2,
      bassHpfGapHz: low - GUIDE.bassHpfHigh,
      lowInKickWindow: low >= GUIDE.kickPunchLow && low <= GUIDE.kickPunchHigh,
      octaveBelowBassHpf: low / 2 < GUIDE.bassHpfHigh
    };
  }

  root.WAP_CALC = {
    NOTE_NAMES: NOTE_NAMES,
    PLATFORMS: PLATFORMS,
    TUNINGS: TUNINGS,
    GUIDE: GUIDE,
    DIVISIONS: DIVISIONS,
    quarterMs: quarterMs,
    noteMs: noteMs,
    msToHz: msToHz,
    tempoTable: tempoTable,
    tempoSuggestions: tempoSuggestions,
    dbToLinear: dbToLinear,
    linearToDb: linearToDb,
    sumDb: sumDb,
    clipPctToDbfs: clipPctToDbfs,
    dbfsToClipPct: dbfsToClipPct,
    turnDown: turnDown,
    truePeakVerdict: truePeakVerdict,
    loudnessVsTarget: loudnessVsTarget,
    midiToHz: midiToHz,
    hzToMidi: hzToMidi,
    noteToMidi: noteToMidi,
    noteToHz: noteToHz,
    midiToName: midiToName,
    nearestNote: nearestNote,
    tuningStrings: tuningStrings,
    tuningZones: tuningZones
  };

  if (typeof document === "undefined") return;

  /* ================================================================ DOM */

  var C = root.WAP_CALC;

  function $(id) {
    return document.getElementById(id);
  }

  // Empty or malformed input reads as NaN, so callers show nothing instead of "NaN".
  function readNumber(input) {
    var raw = String(input.value).trim().replace(",", ".");
    if (raw === "") return NaN;
    var n = Number(raw);
    return isNumber(n) ? n : NaN;
  }

  function fixed(n, digits) {
    if (!isNumber(n)) return "";
    var text = n.toFixed(digits);
    return Number(text) === 0 ? (0).toFixed(digits) : text;
  }

  function signed(n, digits) {
    var text = fixed(n, digits);
    if (!text) return "";
    return n > 0 && Number(text) !== 0 ? "+" + text : text;
  }

  function hzText(hz) {
    if (!isNumber(hz)) return "";
    return fixed(hz, hz < 10 ? 3 : 2);
  }

  function setText(id, text) {
    var el = $(id);
    if (el) el.textContent = text;
  }

  function escapeHtml(text) {
    return String(text)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function setTone(el, tone) {
    ["ok", "warn", "danger", "info"].forEach(function (t) {
      el.classList.toggle("callout--" + t, t === tone);
    });
  }

  /* ---------------------------------------------------------------- 1. tempo */
  function initTempo() {
    var bpmInput = $("tempo-bpm");
    var body = $("tempo-rows");
    if (!bpmInput || !body) return;

    var derivedIds = ["tempo-pre64", "tempo-pre128", "tempo-decay4", "tempo-decay2", "tempo-decay1", "tempo-rel8", "tempo-rel16"];

    function render() {
      var bpm = readNumber(bpmInput);
      var valid = bpm > 0 && bpm <= 1000;
      setText("tempo-quarter", valid ? fixed(C.quarterMs(bpm), 2) + " ms" : "");

      if (!valid) {
        body.innerHTML = '<tr><td colspan="7" class="muted">Enter a BPM above 0.</td></tr>';
        derivedIds.forEach(function (id) { setText(id, "-"); });
        return;
      }

      body.innerHTML = C.tempoTable(bpm).map(function (row) {
        return "<tr><th scope=\"row\" class=\"mono\">1/" + row.division + "</th>" +
          ["straight", "dotted", "triplet"].map(function (feel) {
            return '<td class="mono">' + fixed(row[feel].ms, 2) + '</td><td class="mono muted">' + hzText(row[feel].hz) + "</td>";
          }).join("") + "</tr>";
      }).join("");

      var s = C.tempoSuggestions(bpm);
      setText("tempo-pre64", fixed(s.preDelay64, 1) + " ms");
      setText("tempo-pre128", fixed(s.preDelay128, 1) + " ms");
      setText("tempo-decay4", fixed(s.decayQuarter / 1000, 2) + " s");
      setText("tempo-decay2", fixed(s.decayHalf / 1000, 2) + " s");
      setText("tempo-decay1", fixed(s.decayBar / 1000, 2) + " s");
      setText("tempo-rel8", fixed(s.release8, 0) + " ms");
      setText("tempo-rel16", fixed(s.release16, 0) + " ms");
    }

    bpmInput.addEventListener("input", render);
    render();
  }

  /* ---------------------------------------------------------------- 2. gain */
  // Two inputs that convert into each other. Typing in one rewrites the other.
  function linkPair(leftInput, rightInput, toRight, toLeft, rightDigits, leftDigits) {
    leftInput.addEventListener("input", function () {
      var out = toRight(readNumber(leftInput));
      rightInput.value = isNumber(out) ? fixed(out, rightDigits) : "";
    });
    rightInput.addEventListener("input", function () {
      var out = toLeft(readNumber(rightInput));
      leftInput.value = isNumber(out) ? fixed(out, leftDigits) : "";
    });
  }

  function initGain() {
    var db = $("gain-db");
    var linear = $("gain-linear");
    if (db && linear) {
      linkPair(db, linear,
        function (v) { return isNumber(v) ? C.dbToLinear(v) : NaN; },
        function (v) { return v > 0 ? C.linearToDb(v) : NaN; },
        4, 2);
    }

    var pct = $("clip-pct");
    var dbfs = $("clip-dbfs");
    if (pct && dbfs) {
      linkPair(pct, dbfs,
        function (v) { return v > 0 ? C.clipPctToDbfs(v) : NaN; },
        function (v) { return isNumber(v) ? C.dbfsToClipPct(v) : NaN; },
        2, 1);
    }

    var stack = $("gain-stack");
    if (!stack) return;
    function renderStack() {
      var tokens = stack.value.split(/[\s,;]+/).filter(Boolean);
      var values = tokens.map(function (t) { var n = Number(t.replace(/db$/i, "")); return isNumber(n) ? n : NaN; });
      var valid = values.length > 0 && values.every(isNumber);
      var total = valid ? C.sumDb(values) : NaN;
      setText("gain-stack-total", valid ? signed(total, 2) + " dB" : "-");
      setText("gain-stack-linear", valid ? "x " + fixed(C.dbToLinear(total), 4) : "-");
      setText("gain-stack-count", valid ? String(values.length) : "-");
    }
    stack.addEventListener("input", renderStack);
    renderStack();
  }

  /* ---------------------------------------------------------------- 3. loudness */
  var VERDICT_TEXT = {
    "over-ceiling": { tone: "danger", title: "True peak over -1.0 dBTP", body: "Lossy encoding can clip. Lower the limiter ceiling until true peak reads -1.0 dBTP or lower." },
    "spotify-loud": { tone: "warn", title: "Spotify headroom", body: "Spotify asks for true peak below -2 dBTP on masters louder than -14 LUFS." },
    "ok": { tone: "ok", title: "True peak OK", body: "True peak sits inside the ceiling for this loudness." }
  };
  var TARGET_TEXT = {
    "too-loud": "Louder than -7 LUFS. The mix bus page says go no louder. Each extra dB of limiting costs kick and snare punch.",
    "above-target": "Above the -8.5 to -7.5 LUFS print target, under the -7 LUFS limit.",
    "on-target": "Inside the -8.5 to -7.5 LUFS print target.",
    "below-target": "Quieter than the -8.5 to -7.5 LUFS print target."
  };

  function initLoudness() {
    var lufsInput = $("loud-lufs");
    var tpInput = $("loud-tp");
    var body = $("loud-rows");
    var verdict = $("loud-verdict");
    if (!lufsInput || !tpInput || !body || !verdict) return;

    function render() {
      var lufs = readNumber(lufsInput);
      var tp = readNumber(tpInput);
      var lufsValid = lufs < 0 && lufs > -70;
      var tpValid = isNumber(tp) && tp > -60 && tp < 12;

      if (!lufsValid) {
        body.innerHTML = '<tr><td colspan="3" class="muted">Enter integrated loudness, for example -8.</td></tr>';
      } else {
        body.innerHTML = C.PLATFORMS.map(function (p) {
          var down = C.turnDown(lufs, p.target);
          var change = down > 0 ? "-" + fixed(down, 1) + " dB" : "0.0 dB";
          var note = down > 0 ? "Turned down" : "At or below target, no turn-down";
          return "<tr><td>" + escapeHtml(p.name) + '</td><td class="mono">' + fixed(p.target, 0) + ' LUFS</td><td class="mono">' +
            change + ' <span class="muted">' + note + "</span></td></tr>";
        }).join("");
      }

      verdict.hidden = !(lufsValid && tpValid);
      setText("loud-target", lufsValid ? TARGET_TEXT[C.loudnessVsTarget(lufs)] : "");
      if (lufsValid && tpValid) {
        var v = VERDICT_TEXT[C.truePeakVerdict(lufs, tp)];
        setTone(verdict, v.tone);
        setText("loud-verdict-title", v.title);
        setText("loud-verdict-body", v.body);
      }
    }

    lufsInput.addEventListener("input", render);
    tpInput.addEventListener("input", render);
    render();
  }

  /* ---------------------------------------------------------------- 4. tuning */
  function initTuning() {
    var select = $("tune-select");
    var body = $("tune-rows");
    if (!select || !body) return;

    select.innerHTML = C.TUNINGS.map(function (t) {
      return '<option value="' + t.id + '">' + escapeHtml(t.label) + "</option>";
    }).join("");

    function render() {
      var strings = C.tuningStrings(select.value);
      var z = C.tuningZones(select.value);
      if (!z) return;

      var rows = strings.map(function (s) {
        return '<tr><th scope="row" class="mono">' + s.string + '</th><td>Guitar</td><td class="mono">' + s.name +
          '</td><td class="mono">' + hzText(s.hz) + "</td></tr>";
      });
      rows.push('<tr><th scope="row">Bass</th><td>Low string, unison (bass page)</td><td class="mono">' + z.bassUnisonName +
        '</td><td class="mono">' + hzText(z.bassUnisonHz) + "</td></tr>");
      rows.push('<tr><th scope="row">Bass</th><td>Octave below (reference)</td><td class="mono">' + z.bassOctaveName +
        '</td><td class="mono">' + hzText(z.bassOctaveHz) + "</td></tr>");
      body.innerHTML = rows.join("");

      var g = C.GUIDE;
      setText("tune-low", z.lowName + " " + hzText(z.lowHz) + " Hz");
      setText("tune-h2", hzText(z.secondHarmonicHz) + " Hz");
      setText("tune-floor", fixed(z.guitarFloorHz, 0) + " Hz");
      setText("tune-rhythm", g.rhythmHpfLow + "-" + g.rhythmHpfHigh + " Hz");
      setText("tune-bass-hpf", g.bassHpfLow + "-" + g.bassHpfHigh + " Hz");
      setText("tune-bass-gap", fixed(z.bassHpfGapHz, 0) + " Hz");

      var notes = [];
      notes.push("Rhythm HPF " + g.rhythmHpfLow + "-" + g.rhythmHpfHigh + " Hz is a tone choice from the guitars page, not a fundamental. It sits above the " +
        hzText(z.lowHz) + " Hz low note on purpose" +
        (g.rhythmHpfLow < z.secondHarmonicHz ? " and below its " + hzText(z.secondHarmonicHz) + " Hz 2nd harmonic." : "."));
      if (z.lowInKickWindow) {
        notes.push("The low note sits in the " + g.kickPunchLow + "-" + g.kickPunchHigh + " Hz kick punch window. The SC_KICK duck on the bass matters.");
      }
      if (z.octaveBelowBassHpf) {
        notes.push("A bass an octave below (" + hzText(z.bassOctaveHz) + " Hz) sits under the " + g.bassHpfLow + "-" + g.bassHpfHigh +
          " Hz bass HPF. The bass page plays in unison with the guitar, so the HPF stays below the fundamental.");
      }
      $("tune-notes").innerHTML = notes.map(function (n) { return "<li>" + escapeHtml(n) + "</li>"; }).join("");
    }

    select.value = "drop-g";
    select.addEventListener("change", render);
    render();
  }

  /* ---------------------------------------------------------------- 5. note <-> Hz */
  function initNoteHz() {
    var nameSelect = $("note-name");
    var octaveInput = $("note-octave");
    var hzInput = $("hz-in");
    if (!nameSelect || !octaveInput || !hzInput) return;

    nameSelect.innerHTML = C.NOTE_NAMES.map(function (n) {
      return '<option value="' + n + '">' + n + "</option>";
    }).join("");
    nameSelect.value = "A";

    function renderNote() {
      var octave = readNumber(octaveInput);
      var valid = isNumber(octave) && Math.floor(octave) === octave && octave >= -1 && octave <= 9;
      var midi = valid ? C.noteToMidi(nameSelect.value, octave) : NaN;
      setText("note-out-hz", isNumber(midi) ? hzText(C.midiToHz(midi)) + " Hz" : "-");
      setText("note-out-midi", isNumber(midi) ? String(midi) : "-");
    }

    function renderHz() {
      var hz = readNumber(hzInput);
      var near = hz > 0 && hz <= 24000 ? C.nearestNote(hz) : null;
      setText("hz-out-note", near ? near.name : "-");
      setText("hz-out-cents", near ? signed(near.cents, 1) + " cents" : "-");
      setText("hz-out-exact", near ? hzText(near.hz) + " Hz" : "-");
    }

    nameSelect.addEventListener("change", renderNote);
    octaveInput.addEventListener("input", renderNote);
    hzInput.addEventListener("input", renderHz);
    renderNote();
    renderHz();
  }

  document.addEventListener("DOMContentLoaded", function () {
    initTempo();
    initGain();
    initLoudness();
    initTuning();
    initNoteHz();
  });
})(typeof window !== "undefined" ? window : this);
