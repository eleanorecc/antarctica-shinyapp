// Ring order inside -> out, per design doc Ring Structure section.
const RING_GOALS = [
  "CarbonStorage_Cycling",
  "HabitatIntegrity",
  "CleanWater_NutrientCycling",
  "SpeciesDiversity_FoodWeb",
  "Fisheries_FoodProvision",
  "NaturalProducts_Krill",
  "IconicSpecies_Conservation",
  "SpecialPlaces_Protection",
  "Tourism_Recreation",
];

const RING_SERVICE_CATEGORY = {
  CarbonStorage_Cycling: "Regulating",
  HabitatIntegrity: "Regulating",
  CleanWater_NutrientCycling: "Supporting",
  SpeciesDiversity_FoodWeb: "Supporting",
  Fisheries_FoodProvision: "Provisioning",
  NaturalProducts_Krill: "Provisioning",
  IconicSpecies_Conservation: "Cultural",
  SpecialPlaces_Protection: "Cultural",
  Tourism_Recreation: "Cultural",
};

// Equal-area ring boundaries: pi*(r1^2 - r0^2) is constant across all
// Nrings, starting at holeFraction*maxRadius and ending at maxRadius.
// Solving r_i = sqrt(holeR^2 + i*(maxRadius^2 - holeR^2)/N) gives radii
// where each successive band has equal area, and (by construction of
// area = 2*pi*r*thickness for a thin band) thickness shrinks as r grows.
function computeRingRadii({ maxRadius, holeFraction }) {
  const n = RING_GOALS.length;
  const holeR = maxRadius * holeFraction;
  const holeR2 = holeR * holeR;
  const maxR2 = maxRadius * maxRadius;
  const step = (maxR2 - holeR2) / n;

  const boundaries = [];
  for (let i = 0; i <= n; i++) {
    boundaries.push(Math.sqrt(holeR2 + i * step));
  }

  return RING_GOALS.map((goal, i) => ({
    goal,
    serviceCategory: RING_SERVICE_CATEGORY[goal],
    r0: boundaries[i],
    r1: boundaries[i + 1],
  }));
}

// Same 9 columns as RING_GOALS, kept as a separate exported name since
// this list means "every score field on a row" rather than "ring order".
const SCORE_COLUMNS = RING_GOALS.slice();

function parseRow(rawRow) {
  const scores = {};
  SCORE_COLUMNS.forEach((col) => {
    scores[col] = +rawRow[col];
  });
  return {
    paramName: rawRow.ParamName,
    fullName: rawRow.FullName,
    category: rawRow.Category,
    goal: rawRow.Goal,
    serviceCategory: rawRow.ServiceCategory,
    scores,
  };
}

// Groups rows into angular sectors ordered by RING_GOALS (matching ring
// order inside-out), sorted by descending score-on-own-goal within each
// sector, then assigns each row an equal angular width within [0, 1).
function computeAngularPartition(rows) {
  const goalIndex = {};
  RING_GOALS.forEach((g, i) => { goalIndex[g] = i; });

  const sorted = rows.slice().sort((a, b) => {
    const gi = goalIndex[a.goal] - goalIndex[b.goal];
    if (gi !== 0) return gi;
    return b.scores[b.goal] - a.scores[a.goal];
  });

  const width = 1 / sorted.length;
  return sorted.map((row, i) => ({
    ...row,
    angle0: i * width,
    angle1: (i + 1) * width,
  }));
}

// One base hue per ServiceCategory, per design doc Color encoding section.
// Deliberately deeper/more saturated than a strictly colorblind-safe
// categorical palette would allow (checked against the dataviz skill's
// palette validator — this set fails its lightness/chroma/CVD-separation
// checks) — accepted as a tradeoff because goal identity here is already
// carried by ring position and the text label, not by hue alone, and a
// richer "darkest" at full score-opacity was an explicit design request
// (raising saturation while lowering lightness, not just darkening,
// keeps the color vivid instead of muddy). Supporting is a blue in the
// family of the water tones in www/images/WeddellSea-Art.jpg; Regulating
// is a purple companion to that blue; Provisioning is a coral in the
// family of the artwork's orange-red accents; Cultural is in the family
// of www/style.css's --accent-green.
const CATEGORY_COLORS = {
  Regulating: "#34127d",   // purple
  Supporting: "#094b71",   // blue
  Provisioning: "#81180e", // coral
  Cultural: "#4f650b",     // green
};

// A brighter, vivid mid-tone of each category hue (same hue/high
// saturation as CATEGORY_COLORS, but at ~40-48% lightness instead of
// ~22-28%) — NOT derived by darkening or lightening CATEGORY_COLORS
// (which mixes in black/white and reads muddy/washed-out), but a fresh
// hand-picked mid-tone so it looks like "this hue, but vibrant," used
// for the relevant-ring-band hover highlight.
const CATEGORY_COLORS_MIDTONE = {
  Regulating: "#591fd6",   // vivid purple
  Supporting: "#1083c6",   // vivid blue
  Provisioning: "#d32717", // vivid coral/red
  Cultural: "#88ae13",     // vivid green
};

// Opacity scale: score in [scoreMin, scoreMax] -> opacity in [0.15, 1.0].
function scoreToOpacity(score, scoreMin, scoreMax) {
  if (scoreMax === scoreMin) return 1.0;
  const t = (score - scoreMin) / (scoreMax - scoreMin);
  return 0.15 + t * (1.0 - 0.15);
}

const HIGHLIGHT_THRESHOLD = 7;

function isHighlightRing(score) {
  return score >= HIGHLIGHT_THRESHOLD;
}

// Filters to rows whose primary Goal matches, then re-runs the angular
// partition over just that subset so the result fills the full circle
// (matches design doc Click-to-select section, step 3).
function subsetByGoal(rows, goal) {
  const matches = rows.filter((r) => r.goal === goal);
  return computeAngularPartition(matches);
}

// Filters to rows scoring >= threshold on the given goal's score column
// (not each row's own primary Goal field), then re-runs the angular
// partition over just that subset so the result fills the full circle.
// This is what clicking a goal ring/label subsets by: "every EV strongly
// relevant to this goal," not just the EVs whose main category happens
// to be this goal.
function subsetByGoalScore(rows, goal, threshold) {
  const matches = rows.filter((r) => r.scores[goal] >= threshold);
  return computeAngularPartition(matches);
}

// Darkens a hex color by reducing HSL lightness by `amount` (0-1), holding
// hue/saturation fixed — used for the hover-highlight outline so it reads
// as "this color, but bolder" rather than an unrelated black stroke (per
// the dataviz skill's guidance: never draw a border in a color unrelated
// to the mark to separate/highlight it).
function darkenColor(hex, amount) {
  const r = parseInt(hex.slice(1, 3), 16) / 255;
  const g = parseInt(hex.slice(3, 5), 16) / 255;
  const b = parseInt(hex.slice(5, 7), 16) / 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  let h = 0;
  let s = 0;
  const l = (max + min) / 2;
  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    switch (max) {
      case r: h = (g - b) / d + (g < b ? 6 : 0); break;
      case g: h = (b - r) / d + 2; break;
      case b: h = (r - g) / d + 4; break;
    }
    h /= 6;
  }
  const newL = Math.max(0, l - amount);
  const hue2rgb = (p, q, t) => {
    let tt = t;
    if (tt < 0) tt += 1;
    if (tt > 1) tt -= 1;
    if (tt < 1 / 6) return p + (q - p) * 6 * tt;
    if (tt < 1 / 2) return q;
    if (tt < 2 / 3) return p + (q - p) * (2 / 3 - tt) * 6;
    return p;
  };
  let rr;
  let gg;
  let bb;
  if (s === 0) {
    rr = gg = bb = newL;
  } else {
    const q = newL < 0.5 ? newL * (1 + s) : newL + s - newL * s;
    const p = 2 * newL - q;
    rr = hue2rgb(p, q, h + 1 / 3);
    gg = hue2rgb(p, q, h);
    bb = hue2rgb(p, q, h - 1 / 3);
  }
  const toHex = (v) => Math.round(v * 255).toString(16).padStart(2, "0");
  return `#${toHex(rr)}${toHex(gg)}${toHex(bb)}`;
}

// Picks white or near-black text for a label placed on top of a filled
// background, based on that fill's relative luminance (WCAG formula) —
// per the dataviz skill's guidance that a label inside a colored fill is
// the one case where text should be white/ink chosen by the fill's
// luminance, computed rather than hardcoded.
function textColorForFill(hex) {
  const channel = (v) => {
    const c = v / 255;
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  };
  const r = channel(parseInt(hex.slice(1, 3), 16));
  const g = channel(parseInt(hex.slice(3, 5), 16));
  const b = channel(parseInt(hex.slice(5, 7), 16));
  const luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  return luminance > 0.45 ? "#1a1a1a" : "#ffffff";
}

// Hand-written overrides for goal labels that need different wording
// than the generic underscore/camelCase formatting below produces (a
// dropped word, or a reordered phrase) — checked first, by raw goal
// identifier, before falling back to the generic formatter.
const GOAL_LABEL_OVERRIDES = {
  Tourism_Recreation: "TOURISM",
  SpecialPlaces_Protection: "PROTECTED SPECIAL PLACES",
  IconicSpecies_Conservation: "CONSERVATION OF ICONIC SPECIES",
};

// Formats a raw goal identifier (e.g. "CarbonStorage_Cycling") into a
// display label: underscores become " / " (separating the two halves of
// a compound goal name), camelCase word boundaries get a space, and the
// whole thing is uppercased. "CarbonStorage_Cycling" -> "CARBON STORAGE
// / CYCLING". A handful of goals have hand-written overrides instead
// (GOAL_LABEL_OVERRIDES, above) that don't follow this generic pattern.
function formatGoalLabel(goal) {
  if (GOAL_LABEL_OVERRIDES[goal]) return GOAL_LABEL_OVERRIDES[goal];
  return goal
    .split("_")
    .map((part) => part.replace(/([a-z])([A-Z])/g, "$1 $2"))
    .join(" / ")
    .toUpperCase();
}

// Replaces an en-dash separator (e.g. "Predator abundance – Leopard
// seal", from parameters.csv's Parameter/FullName columns) with a line
// break, so the center-hover label wraps onto a new line at that point
// instead of showing the dash inline. Applied on top of FullName's
// existing embedded "\n" separators (Habitat/Community lines) — this
// only touches the en-dash, not those.
function formatFullName(fullName) {
  return fullName.replace(/\s*–\s*/g, "\n");
}

if (typeof module !== "undefined") {
  module.exports = {
    RING_GOALS,
    RING_SERVICE_CATEGORY,
    computeRingRadii,
    SCORE_COLUMNS,
    parseRow,
    computeAngularPartition,
    CATEGORY_COLORS,
    CATEGORY_COLORS_MIDTONE,
    scoreToOpacity,
    HIGHLIGHT_THRESHOLD,
    isHighlightRing,
    subsetByGoal,
    subsetByGoalScore,
    darkenColor,
    textColorForFill,
    formatGoalLabel,
    formatFullName,
  };
}
