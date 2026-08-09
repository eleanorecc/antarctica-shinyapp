const assert = require("assert");
const { computeRingRadii, RING_GOALS } = require("./sunburst-data.js");

// --- computeRingRadii ---
{
  const radii = computeRingRadii({ maxRadius: 200, holeFraction: 0.2 });
  assert.strictEqual(radii.length, 9, "expected 9 ring boundaries entries (one per goal)");
  assert.strictEqual(radii[0].goal, RING_GOALS[0], "ring order must match RING_GOALS");
  assert.strictEqual(radii[8].goal, RING_GOALS[8]);

  // inner hole
  assert.ok(Math.abs(radii[0].r0 - 40) < 1e-6, `first ring should start at holeFraction*maxRadius (40), got ${radii[0].r0}`);
  // outer edge
  assert.ok(Math.abs(radii[8].r1 - 200) < 1e-6, `last ring should end at maxRadius (200), got ${radii[8].r1}`);
  // contiguous
  for (let i = 0; i < 8; i++) {
    assert.ok(Math.abs(radii[i].r1 - radii[i + 1].r0) < 1e-6, `ring ${i} r1 must equal ring ${i + 1} r0`);
  }
  // equal area: pi*(r1^2 - r0^2) constant across all rings
  const areas = radii.map(r => Math.PI * (r.r1 * r.r1 - r.r0 * r.r0));
  for (let i = 1; i < areas.length; i++) {
    assert.ok(Math.abs(areas[i] - areas[0]) < 1e-6, `ring ${i} area (${areas[i]}) must equal ring 0 area (${areas[0]})`);
  }
  // thickness decreases outward (visual requirement: thicker toward center)
  for (let i = 0; i < 8; i++) {
    const thisThickness = radii[i].r1 - radii[i].r0;
    const nextThickness = radii[i + 1].r1 - radii[i + 1].r0;
    assert.ok(thisThickness > nextThickness, `ring ${i} (${thisThickness}) must be thicker than ring ${i + 1} (${nextThickness})`);
  }
}

console.log("computeRingRadii: OK");

const { SCORE_COLUMNS, parseRow } = require("./sunburst-data.js");

// --- SCORE_COLUMNS / parseRow ---
{
  assert.strictEqual(SCORE_COLUMNS.length, 9, "expected 9 score columns");
  assert.ok(SCORE_COLUMNS.includes("CarbonStorage_Cycling"));
  assert.ok(SCORE_COLUMNS.includes("Tourism_Recreation"));

  // Simulates a row as it comes back from d3.csv (all values are strings).
  const rawRow = {
    ParamName: "eDNA_WaterCol_AllBiota",
    FullName: "eDNA\nWater column\nAll biota",
    Category: "Biological",
    Goal: "SpeciesDiversity_FoodWeb",
    ServiceCategory: "Supporting",
    Fisheries_FoodProvision: "7",
    NaturalProducts_Krill: "8",
    IconicSpecies_Conservation: "8",
    SpecialPlaces_Protection: "7",
    Tourism_Recreation: "5",
    CleanWater_NutrientCycling: "6",
    SpeciesDiversity_FoodWeb: "9",
    HabitatIntegrity: "8",
    CarbonStorage_Cycling: "4",
  };
  const parsed = parseRow(rawRow);
  assert.strictEqual(parsed.paramName, "eDNA_WaterCol_AllBiota");
  assert.strictEqual(parsed.fullName, "eDNA\nWater column\nAll biota");
  assert.strictEqual(parsed.goal, "SpeciesDiversity_FoodWeb");
  assert.strictEqual(parsed.serviceCategory, "Supporting");
  assert.strictEqual(typeof parsed.scores.CarbonStorage_Cycling, "number", "scores must be numeric, not strings");
  assert.strictEqual(parsed.scores.CarbonStorage_Cycling, 4);
  assert.strictEqual(parsed.scores.SpeciesDiversity_FoodWeb, 9);
  assert.strictEqual(Object.keys(parsed.scores).length, 9, "scores object must have all 9 goal columns");
}

console.log("parseRow: OK");

const { computeAngularPartition } = require("./sunburst-data.js");

// --- computeAngularPartition ---
{
  // 3 rows: 2 in CarbonStorage_Cycling (scores 5 and 9 on that goal),
  // 1 in HabitatIntegrity. RING_GOALS order puts CarbonStorage_Cycling
  // before HabitatIntegrity, so all CarbonStorage_Cycling rays must come
  // first in angle order, and within that sector, score 9 (higher) must
  // come before score 5.
  const rows = [
    { paramName: "A", goal: "CarbonStorage_Cycling", scores: { CarbonStorage_Cycling: 5, HabitatIntegrity: 3 } },
    { paramName: "B", goal: "CarbonStorage_Cycling", scores: { CarbonStorage_Cycling: 9, HabitatIntegrity: 2 } },
    { paramName: "C", goal: "HabitatIntegrity", scores: { CarbonStorage_Cycling: 1, HabitatIntegrity: 7 } },
  ];

  const partition = computeAngularPartition(rows);
  assert.strictEqual(partition.length, 3);

  // order: B (score 9) before A (score 5), both before C
  assert.deepStrictEqual(partition.map(p => p.paramName), ["B", "A", "C"]);

  // angles span [0, 1) (fraction of full circle), contiguous, non-overlapping
  assert.ok(Math.abs(partition[0].angle0 - 0) < 1e-9);
  assert.ok(Math.abs(partition[2].angle1 - 1) < 1e-9);
  for (let i = 0; i < partition.length - 1; i++) {
    assert.ok(Math.abs(partition[i].angle1 - partition[i + 1].angle0) < 1e-9, `ray ${i} angle1 must equal ray ${i+1} angle0`);
  }
  // equal width per ray (3 rows -> each gets 1/3)
  partition.forEach(p => {
    assert.ok(Math.abs((p.angle1 - p.angle0) - 1 / 3) < 1e-9);
  });
}

console.log("computeAngularPartition: OK");

// --- computeAngularPartition: subset reuse (Task 5 will call this on a
// filtered single-goal subset and expects a full-circle re-partition) ---
{
  const singleGoalRows = [
    { paramName: "X", goal: "NaturalProducts_Krill", scores: { NaturalProducts_Krill: 6 } },
    { paramName: "Y", goal: "NaturalProducts_Krill", scores: { NaturalProducts_Krill: 9 } },
  ];
  const subset = computeAngularPartition(singleGoalRows);
  assert.strictEqual(subset.length, 2);
  // higher own-goal score (Y=9) sorts first, even though it's the only goal present
  assert.deepStrictEqual(subset.map(p => p.paramName), ["Y", "X"]);
  // still fills the full circle, not just a fraction of it
  assert.ok(Math.abs(subset[0].angle0 - 0) < 1e-9);
  assert.ok(Math.abs(subset[1].angle1 - 1) < 1e-9);
  assert.ok(Math.abs((subset[0].angle1 - subset[0].angle0) - 0.5) < 1e-9, "2 rows should each get half the circle");

  // empty input must not throw and must return an empty array
  const empty = computeAngularPartition([]);
  assert.deepStrictEqual(empty, []);
}

console.log("computeAngularPartition subset reuse: OK");

const { CATEGORY_COLORS, CATEGORY_COLORS_MIDTONE, scoreToOpacity, isHighlightRing, HIGHLIGHT_THRESHOLD } = require("./sunburst-data.js");

// --- CATEGORY_COLORS ---
{
  assert.strictEqual(typeof CATEGORY_COLORS.Regulating, "string");
  assert.strictEqual(typeof CATEGORY_COLORS.Supporting, "string");
  assert.strictEqual(typeof CATEGORY_COLORS.Provisioning, "string");
  assert.strictEqual(typeof CATEGORY_COLORS.Cultural, "string");
}
console.log("CATEGORY_COLORS: OK");

// --- CATEGORY_COLORS_MIDTONE ---
{
  const categories = ["Regulating", "Supporting", "Provisioning", "Cultural"];
  categories.forEach((cat) => {
    assert.ok(/^#[0-9a-f]{6}$/i.test(CATEGORY_COLORS_MIDTONE[cat]), `${cat} must have a valid hex color`);
    assert.notStrictEqual(CATEGORY_COLORS_MIDTONE[cat], CATEGORY_COLORS[cat], `${cat} midtone must differ from its base color`);
  });

  // midtone should be lighter (higher luminance) than the base dark color
  // for every category, since it's meant to read as brighter/more vivid
  const luminance = (hex) => [1, 3, 5].reduce((sum, i) => sum + parseInt(hex.slice(i, i + 2), 16), 0);
  categories.forEach((cat) => {
    assert.ok(
      luminance(CATEGORY_COLORS_MIDTONE[cat]) > luminance(CATEGORY_COLORS[cat]),
      `${cat} midtone must be brighter than its base color`
    );
  });
}
console.log("CATEGORY_COLORS_MIDTONE: OK");

// --- scoreToOpacity ---
{
  const opacityMin = scoreToOpacity(2, 2, 10);
  const opacityMax = scoreToOpacity(10, 2, 10);
  const opacityMid = scoreToOpacity(6, 2, 10);
  assert.ok(Math.abs(opacityMin - 0.15) < 1e-9, `min score should map to 0.15, got ${opacityMin}`);
  assert.ok(Math.abs(opacityMax - 1.0) < 1e-9, `max score should map to 1.0, got ${opacityMax}`);
  assert.ok(opacityMid > opacityMin && opacityMid < opacityMax, "mid score must be strictly between min/max opacity");
}
console.log("scoreToOpacity: OK");

// --- isHighlightRing / HIGHLIGHT_THRESHOLD ---
{
  assert.strictEqual(HIGHLIGHT_THRESHOLD, 7);
  assert.strictEqual(isHighlightRing(7), true, "score exactly at threshold must highlight");
  assert.strictEqual(isHighlightRing(6.9), false);
  assert.strictEqual(isHighlightRing(10), true);
}
console.log("isHighlightRing: OK");

const { subsetByGoal } = require("./sunburst-data.js");

// --- subsetByGoal ---
{
  const rows = [
    { paramName: "A", goal: "CarbonStorage_Cycling", scores: { CarbonStorage_Cycling: 5 } },
    { paramName: "B", goal: "CarbonStorage_Cycling", scores: { CarbonStorage_Cycling: 9 } },
    { paramName: "C", goal: "HabitatIntegrity", scores: { CarbonStorage_Cycling: 1, HabitatIntegrity: 7 } },
  ];

  const subset = subsetByGoal(rows, "CarbonStorage_Cycling");
  assert.strictEqual(subset.length, 2, "only rows whose primary Goal matches should remain");
  // must be re-partitioned: full width [0,1) split across just the 2 matches, high score first
  assert.deepStrictEqual(subset.map(p => p.paramName), ["B", "A"]);
  assert.ok(Math.abs(subset[0].angle0 - 0) < 1e-9);
  assert.ok(Math.abs(subset[1].angle1 - 1) < 1e-9);
  assert.ok(Math.abs((subset[0].angle1 - subset[0].angle0) - 0.5) < 1e-9, "2 rows should each get half the circle");

  // empty-subset case (a goal with zero primary-Goal rows, e.g. Tourism_Recreation)
  const empty = subsetByGoal(rows, "Tourism_Recreation");
  assert.strictEqual(empty.length, 0);
}
console.log("subsetByGoal: OK");

const { subsetByGoalScore } = require("./sunburst-data.js");

// --- subsetByGoalScore ---
{
  const rows = [
    // primary goal is HabitatIntegrity, but scores 8 on CarbonStorage_Cycling
    // -- this row must be INCLUDED when subsetting CarbonStorage_Cycling by
    // score, unlike subsetByGoal (which filters by primary Goal only).
    { paramName: "A", goal: "HabitatIntegrity", scores: { CarbonStorage_Cycling: 8, HabitatIntegrity: 6 } },
    // primary goal IS CarbonStorage_Cycling, and scores 9 on it
    { paramName: "B", goal: "CarbonStorage_Cycling", scores: { CarbonStorage_Cycling: 9, HabitatIntegrity: 2 } },
    // scores only 5 on CarbonStorage_Cycling -- must be EXCLUDED at threshold 7
    { paramName: "C", goal: "CarbonStorage_Cycling", scores: { CarbonStorage_Cycling: 5, HabitatIntegrity: 7 } },
  ];

  const subset = subsetByGoalScore(rows, "CarbonStorage_Cycling", 7);
  assert.strictEqual(subset.length, 2, "only rows scoring >= threshold on the goal's score column should remain, regardless of primary Goal");
  // re-partitioned: full width [0,1) split across the 2 matches, high score first
  assert.deepStrictEqual(subset.map(p => p.paramName), ["B", "A"]);
  assert.ok(Math.abs(subset[0].angle0 - 0) < 1e-9);
  assert.ok(Math.abs(subset[1].angle1 - 1) < 1e-9);

  // threshold is inclusive (score exactly at threshold must be included)
  const inclusive = subsetByGoalScore(rows, "CarbonStorage_Cycling", 8);
  assert.strictEqual(inclusive.length, 2, "score exactly at threshold must be included");

  // empty-subset case (no row scores that high on this goal)
  const empty = subsetByGoalScore(rows, "CarbonStorage_Cycling", 10);
  assert.strictEqual(empty.length, 0);
}
console.log("subsetByGoalScore: OK");

const { darkenColor, textColorForFill } = require("./sunburst-data.js");

// --- darkenColor ---
{
  const base = "#2e7ba8"; // blue
  const darker = darkenColor(base, 0.15);
  assert.notStrictEqual(darker, base, "darkened color must differ from the original");
  assert.ok(/^#[0-9a-f]{6}$/i.test(darker), "must return a valid hex color");

  // hue should be preserved (same relative R/G/B ordering: B > G > R for this blue)
  const toRgb = (hex) => [
    parseInt(hex.slice(1, 3), 16),
    parseInt(hex.slice(3, 5), 16),
    parseInt(hex.slice(5, 7), 16),
  ];
  const [r, g, b] = toRgb(darker);
  assert.ok(b > g && g > r, "darkened blue should keep blue as the dominant channel");

  // black (amount clamps at 0 lightness) and white both round-trip without throwing
  assert.ok(/^#[0-9a-f]{6}$/i.test(darkenColor("#000000", 0.2)));
  assert.ok(/^#[0-9a-f]{6}$/i.test(darkenColor("#ffffff", 0.2)));
}
console.log("darkenColor: OK");

// --- textColorForFill ---
{
  assert.strictEqual(textColorForFill("#ffffff"), "#1a1a1a", "white fill needs dark text");
  assert.strictEqual(textColorForFill("#000000"), "#ffffff", "black fill needs white text");
  assert.strictEqual(textColorForFill("#5a3d99"), "#ffffff", "dark purple fill needs white text");
  assert.strictEqual(textColorForFill("#2e7ba8"), "#ffffff", "mid-dark blue fill needs white text");
}
console.log("textColorForFill: OK");

const { formatGoalLabel } = require("./sunburst-data.js");

// --- formatGoalLabel ---
{
  assert.strictEqual(formatGoalLabel("CarbonStorage_Cycling"), "CARBON STORAGE / CYCLING");
  assert.strictEqual(formatGoalLabel("HabitatIntegrity"), "HABITAT INTEGRITY", "no underscore -> no slash, just camelCase split + uppercase");
  assert.strictEqual(formatGoalLabel("CleanWater_NutrientCycling"), "CLEAN WATER / NUTRIENT CYCLING");
  assert.strictEqual(formatGoalLabel("SpeciesDiversity_FoodWeb"), "SPECIES DIVERSITY / FOOD WEB");
  assert.strictEqual(formatGoalLabel("Fisheries_FoodProvision"), "FISHERIES / FOOD PROVISION");
  assert.strictEqual(formatGoalLabel("NaturalProducts_Krill"), "NATURAL PRODUCTS / KRILL");
  // hand-written overrides (GOAL_LABEL_OVERRIDES), not the generic pattern
  assert.strictEqual(formatGoalLabel("IconicSpecies_Conservation"), "CONSERVATION OF ICONIC SPECIES");
  assert.strictEqual(formatGoalLabel("SpecialPlaces_Protection"), "PROTECTED SPECIAL PLACES");
  assert.strictEqual(formatGoalLabel("Tourism_Recreation"), "TOURISM");
}
console.log("formatGoalLabel: OK");

const { formatFullName } = require("./sunburst-data.js");

// --- formatFullName ---
{
  assert.strictEqual(
    formatFullName("Predator abundance – Leopard seal"),
    "Predator abundance\nLeopard seal",
    "en-dash separator becomes a line break"
  );
  // existing embedded \n separators (Habitat/Community lines) pass through untouched
  assert.strictEqual(
    formatFullName("eDNA\nWater column\nAll biota"),
    "eDNA\nWater column\nAll biota"
  );
  // no en-dash present -> unchanged
  assert.strictEqual(formatFullName("Sea ice growth"), "Sea ice growth");
}
console.log("formatFullName: OK");
