// r2d3 entry point. Globals `svg`, `data`, `options`, `width`, `height`
// are pre-bound by r2d3 (see flowerplot.js for the established pattern);
// `preview.html` shims the same globals for standalone dev.
// Depends on sunburst-data.js being loaded first (defines these on window
// in the browser; required via CommonJS in sunburst-data.test.js).

svg.selectAll("*").remove();
svg.attr("id", "svg-sunburst");
svg.style("background-color", "transparent");

const totalWidth = Math.min(width, height);
// Ray tip labels are gone (removed — see note below), so the outer band
// no longer needs margin reserved for radial label text; the rings can
// reach much closer to the container edge again. 0.96 still leaves a
// sliver of room for the ray-tick marks (drawn at maxRadius + up to 8px)
// — already near its ceiling. The 9 rings' total radial spread is
// (maxRadius - holeR), so a SMALLER holeFraction gives the rings (and
// their mid-radius goal labels) MORE room, not less — a larger hole
// fraction shrinks that available span instead.
const maxRadius = 0.5 * totalWidth * 0.96;
const holeFraction = 0.15;

const g = svg.append("g")
  .attr("transform", `translate(${width / 2}, ${height / 2})`);

const ringRadii = computeRingRadii({ maxRadius, holeFraction });

// Each ring datum's .current/.target track {r0, r1, opacity} so the arc
// tween can interpolate between old and new geometry smoothly. Seeded
// here (immediately after ringRadii is created) rather than later in the
// file, since the ray/ring labels below also read d.current for their
// initial position and must not see it undefined.
ringRadii.forEach((r) => {
  r.current = { r0: r.r0, r1: r.r1, opacity: 0.15 };
});

// --- load and shape the EV rows ---
const rows = data.map(parseRow);
const partitioned = computeAngularPartition(rows);

// score domain across the whole matrix, for the opacity scale
let scoreMin = Infinity;
let scoreMax = -Infinity;
rows.forEach((r) => {
  SCORE_COLUMNS.forEach((col) => {
    const v = r.scores[col];
    if (v < scoreMin) scoreMin = v;
    if (v > scoreMax) scoreMax = v;
  });
});

// Parameters sweep counterclockwise from 3 o'clock (90deg) to 6 o'clock
// (180deg), a 270deg arc. In this convention (0=12 o'clock, angle
// increases clockwise), sweeping counterclockwise from 90 to 180 is the
// same as sweeping clockwise (increasing) from 180 to 90+360=450 — so
// sweepStart/sweepEnd below are given in that increasing form. The
// remaining 90deg wedge (180deg through 360/0deg to 90deg, i.e. the
// lower-right through right side of the circle) stays empty for the
// vertical goal-name labels.
const sweepStart = (180 * Math.PI) / 180;
const sweepEnd = ((90 + 360) * Math.PI) / 180;

const angleScale = d3.scaleLinear()
  .domain([0, 1])
  .range([sweepStart, sweepEnd]);

// --- backing wedge ---
// The SVG background is transparent (so the app's dark page background
// shows through around the plot), but the ring/cell fills are drawn at
// partial opacity — without a solid backing behind them, that dark page
// color would bleed through the bands and wash out their colors. A
// dimgrey donut wedge, matching the exact ring sweep (same angles, same
// inner/outer radii as the rings themselves) and drawn first (so
// everything else paints on top of it), keeps the bands themselves
// legible on a neutral backing while leaving the empty wedge (goal
// labels) and the area outside the rings transparent to the page behind.
const backingArc = d3.arc()
  .startAngle(sweepStart)
  .endAngle(sweepEnd)
  .innerRadius(ringRadii[0].r0)
  .outerRadius(maxRadius);

g.append("path")
  .attr("class", "ring-backing")
  .attr("d", backingArc)
  .attr("fill", "#dee1e9e0");

// Ray tip labels were removed: at 6px they were largely illegible, and
// standard radial text inevitably renders upside-down on part of the
// sweep. The center-hover label (FullName, shown on .hover-target
// mouseover below) is the only way to identify an EV now. labelRadius is
// kept — it still sets hoverArc's outer radius, just past the ring edge.
const labelRadius = maxRadius * 1.05;

// Small angular gap between the ray-wedges (which end at sweepStart,
// 90deg/3 o'clock) and the goal-label text (which starts at the same
// 90deg line) — without this the labels sit flush against the outer edge
// of the first/last ray-band. Applied as a tangential (y-axis, pre-
// rotation) offset in ringLabelTransform below.
const ringLabelGap = 6;

// --- ring labels (goal name, vertical text down from the 3 o'clock edge) ---
// One label per ring, positioned along the horizontal 3 o'clock axis at
// that ring's own mid-radius, so the text is centered between the ring's
// inner and outer edges, with the text itself rotated 90deg so it reads
// top-to-bottom rather than left-to-right. Reads from d.current (not the
// static d.r0/d.r1) so the label's x-position tracks the ring's animated
// radius during the click-to-subset tween — when a ring expands to fill
// the full plot width, its label must shift outward in lockstep to stay
// centered in the growing band, not stay pinned at the original radius.
// The y-offset (ringLabelGap) shifts the label tangentially before the
// 90deg rotation, pushing it past the ray-wedge boundary at sweepStart
// rather than starting flush against it.
function ringLabelTransform(d) {
  const midRadius = (d.current.r0 + d.current.r1) / 2;
  return `translate(${midRadius}, ${ringLabelGap}) rotate(90)`;
}

g.selectAll(".ring-label")
  .data(ringRadii, (d) => d.goal)
  .join("text")
    .attr("class", "ring-label")
    .attr("transform", ringLabelTransform)
    .attr("text-anchor", "start")
    .attr("dy", "0.32em")
    .style("font-size", "13px")
    .style("font-weight", "800")
    .style("font-family", "Manrope, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif")
    .style("letter-spacing", "0.02em")
    .style("cursor", "pointer")
    .style("fill", "#ffffff")
    .on("click", function (event, d) {
      selectedGoal = d.goal;
      render();
    })
    .text((d) => formatGoalLabel(d.goal));

// --- hover: center FullName + highlight rings scoring >= 7 + dim others ---

// invisible full-height wedge per EV, drawn on top, used only for
// hover hit-testing (the visible .cell segments are per-ring, too thin
// individually to be a reliable hover target as a group).
const hoverArc = d3.arc()
  .startAngle((d) => angleScale(d.angle0))
  .endAngle((d) => angleScale(d.angle1))
  .innerRadius(0)
  .outerRadius(labelRadius);

// Whether a ring/cell for the given goal is part of the currently visible
// subset (full view, or this is the one selected goal) — mirrors the
// exact condition cellTarget()/the ring click handler use to decide
// visibility, so hover never re-reveals content hidden by an active
// click-to-subset selection.
function isRingVisible(goal) {
  return selectedGoal === null || goal === selectedGoal;
}

function handleRayHover(event, d) {
  g.selectAll(".cell")
    .attr("stroke", (c) => {
      if (!isRingVisible(c.ring.goal) || c.paramName !== d.paramName || !isHighlightRing(c.score)) return "none";
      // Outline in a darkened version of the cell's own category color,
      // not black — a highlight should read as "this color, bolder,"
      // never an unrelated stroke color (per dataviz skill guidance).
      return darkenColor(CATEGORY_COLORS[c.serviceCategory], 0.2);
    })
    .attr("stroke-width", (c) => (isRingVisible(c.ring.goal) && c.paramName === d.paramName && isHighlightRing(c.score) ? 1.5 : 0))
    .attr("fill-opacity", (c) => {
      if (!isRingVisible(c.ring.goal)) return 0; // stay hidden — a subset-hidden ring must never reappear on hover
      const base = scoreToOpacity(c.score, scoreMin, scoreMax);
      return c.paramName === d.paramName ? base : base * 0.25;
    });

  // Bold the ENTIRE ring band (not just the hovered EV's thin wedge
  // within it) for every goal where the hovered EV scores >= threshold —
  // this is what makes "which goals is this EV relevant to" readable at
  // a glance, since the wedge alone is too thin to see clearly. Relevant
  // rings switch to CATEGORY_COLORS_MIDTONE — a vivid mid-tone of the
  // same hue, not a darkened/lightened derivative of the base color
  // (mixing in black or white reads muddy/washed-out) — plus a higher
  // opacity; irrelevant rings fade well below the normal 0.15 baseline,
  // so the two states are unmistakably different at a glance.
  // Deliberately no stroke change — a stroke drawn around the full ring
  // reads as a dark outline circling the whole band, not a highlight on
  // the ray. The bold edge stays on the .cell wedge itself (above),
  // which is the actual EV-ray/ring intersection being called out. Rings
  // hidden by an active click-to-subset selection are skipped entirely
  // (left at their current, invisible state) rather than bolded/faded,
  // so a subset view's hidden goals never reappear on hover.
  g.selectAll(".ring")
    .attr("fill", (r) => {
      if (!isRingVisible(r.goal)) return CATEGORY_COLORS[r.serviceCategory];
      // Irrelevant rings fade to a dark blue-grey (not their own hue at
      // low opacity, which just blends toward the light backing color
      // and barely reads as "dimmed") — a dark, blue-tinted grey (not
      // neutral grey) shown at low-but-visible opacity is what "faded
      // dark/greyish" actually looks like.
      return isHighlightRing(d.scores[r.goal]) ? CATEGORY_COLORS_MIDTONE[r.serviceCategory] : "#33404d";
    })
    .attr("fill-opacity", (r) => {
      if (!isRingVisible(r.goal)) return r.target.opacity; // stays 0 — never re-reveal a subset-hidden ring
      // The ring-backing wedge (a light blue-grey, drawn behind every
      // ring) dominates the blend at low opacity — even pure black at
      // 0.25 opacity only reaches ~#a7a9af (light grey) over that
      // backing, not a dark color. 0.85 is needed for a black fill to
      // actually read as dark/near-black rather than light grey.
      return isHighlightRing(d.scores[r.goal]) ? 0.6 : 0.85;
    });

  // Font-size stays fixed on hover (no zoom) — only color changes to
  // signal relevance: white for relevant goals, a dim/muted steel-blue
  // for irrelevant ("dimblue" isn't a real CSS color name, unlike
  // "dimgrey" — #4a6b8a stands in for it).
  g.selectAll(".ring-label")
    .style("fill", (r) => (isRingVisible(r.goal) && isHighlightRing(d.scores[r.goal]) ? "#ffffff" : "#4a6b8a"));

  g.selectAll(".center-label").remove();
  const lines = formatFullName(d.fullName).split("\n");
  g.append("text")
    .attr("class", "center-label")
    .attr("text-anchor", "middle")
    .attr("dominant-baseline", "middle")
    .style("font-size", "14px")
    .style("font-weight", "600")
    .style("fill", "#1a1a1a") // dark ink; center hole stays transparent, so text sits on the page background rather than a computed fill
    .selectAll("tspan")
    .data(lines)
    .join("tspan")
      .attr("x", 0)
      .attr("dy", (t, i) => (i === 0 ? `${-0.6 * (lines.length - 1)}em` : "1.2em"))
      .text((t) => t);
}

function handleRayHoverExit() {
  g.selectAll(".cell")
    .attr("stroke", "none")
    .attr("stroke-width", 0)
    .attr("fill-opacity", (c) => (isRingVisible(c.ring.goal) ? scoreToOpacity(c.score, scoreMin, scoreMax) : 0));

  // restore each ring's fill (undoing the hover highlight/grey-fade) and its
  // current subset-state fill-opacity baseline (0.15 if visible in the
  // active view, 0 if hidden by a selected goal) rather than a hardcoded
  // value, so hover-then-unhover respects whatever click-to-subset state
  // is currently active. Stroke is never touched by hover (see
  // handleRayHover), so no reset needed here.
  g.selectAll(".ring")
    .attr("fill", (r) => CATEGORY_COLORS[r.serviceCategory])
    .attr("fill-opacity", (r) => r.target.opacity);

  // font-size was never changed by hover (see handleRayHover), only fill
  g.selectAll(".ring-label")
    .style("fill", "#ffffff");

  g.selectAll(".center-label").remove();
}

// --- click a ring: subset rays to that goal, expand the ring to full width ---

let selectedGoal = null; // null = full view

const tweenRingArc = d3.arc()
  .startAngle(sweepStart)
  .endAngle(sweepEnd)
  .innerRadius((d) => d.current.r0)
  .outerRadius((d) => d.current.r1);

// Each EV/ring cell datum's .current/.target track
// {angle0, angle1, r0, r1, opacity}.
function cellTarget(ev, ring, goal) {
  const ringGeom = goal !== null && ring.goal === goal
    ? { r0: ringRadii[0].r0, r1: maxRadius }
    : { r0: ring.r0, r1: ring.r1 };
  const visible = goal === null || ring.goal === goal;
  return {
    angle0: ev.angle0,
    angle1: ev.angle1,
    r0: ringGeom.r0,
    r1: ringGeom.r1,
    opacity: visible ? scoreToOpacity(ev.scores[ring.goal], scoreMin, scoreMax) : 0,
  };
}

const tweenCellArc = d3.arc()
  .startAngle((d) => angleScale(d.current.angle0))
  .endAngle((d) => angleScale(d.current.angle1))
  .innerRadius((d) => d.current.r0)
  .outerRadius((d) => d.current.r1);

function render() {
  const activeRows = selectedGoal === null
    ? partitioned
    : subsetByGoalScore(rows, selectedGoal, HIGHLIGHT_THRESHOLD);

  // capture each currently-rendered cell's .current BEFORE .data() rebinds
  // datums on persisting nodes, so the upcoming tween starts from where the
  // arc visually is right now rather than snapping.
  const previousCurrent = {};
  g.selectAll(".cell").each(function (d) {
    previousCurrent[`${d.paramName}__${d.ring.goal}`] = d.current;
  });

  const activeCells = [];
  activeRows.forEach((ev) => {
    ringRadii.forEach((ring) => {
      const key = `${ev.paramName}__${ring.goal}`;
      const target = cellTarget(ev, ring, selectedGoal);
      activeCells.push({
        paramName: ev.paramName,
        fullName: ev.fullName,
        goal: ev.goal,
        ring,
        score: ev.scores[ring.goal],
        serviceCategory: ring.serviceCategory,
        current: previousCurrent[key] || { ...target },
        target,
      });
    });
  });

  const t = svg.transition().duration(750);

  // --- rings ---
  const ringSel = g.selectAll(".ring")
    .data(ringRadii, (d) => d.goal)
    .join("path")
      .attr("class", "ring")
      .attr("fill", (d) => CATEGORY_COLORS[d.serviceCategory])
      .style("cursor", "pointer")
      .on("click", function (event, d) {
        selectedGoal = d.goal;
        render();
      })
      .attr("d", (d) => tweenRingArc(d)); // initial draw for brand-new nodes, before any transition runs

  ringSel.each((d) => {
    d.target = {
      r0: d.goal === selectedGoal ? ringRadii[0].r0 : d.r0,
      r1: d.goal === selectedGoal ? maxRadius : d.r1,
      opacity: selectedGoal === null || d.goal === selectedGoal ? 0.15 : 0,
    };
  });

  // The white separator stroke only makes sense between adjacent, visible
  // rings in the full multi-ring view. In subset view this must be off
  // for BOTH: (1) the one selected/expanded ring — no neighboring ring
  // left to separate from, a stroke there just frames the band — and
  // (2) every OTHER ring, hidden via fill-opacity: 0 — SVG stroke is a
  // separate paint operation from fill and ignores fill-opacity
  // entirely, so a hidden ring's original-radius white outline was still
  // being drawn at full strength the whole time, showing up as a stray
  // arc at its old (uncollapsed) radius. Only draw the stroke when no
  // goal is selected (full view) and the ring itself isn't the selected
  // one — the two conditions collapse to the same check here since a
  // ring can only ever equal `selectedGoal` when one is selected.
  ringSel
    .attr("stroke", (d) => (selectedGoal === null ? "#ffffff" : "none"))
    .attr("stroke-width", (d) => (selectedGoal === null ? 1 : 0));

  ringSel.transition(t)
    .attrTween("d", (d) => {
      const i = d3.interpolate(d.current, d.target);
      return (tt) => {
        d.current = i(tt);
        return tweenRingArc(d);
      };
    })
    .attr("fill-opacity", (d) => d.target.opacity);

  // Ring labels ride the exact same .current mutation the ring's own
  // tween above performs (both selections share the same ringRadii
  // datum objects), so this tween just re-reads d.current on every tick
  // rather than re-deriving its own interpolation — the label's x
  // position tracks the ring's animated radius in lockstep, staying
  // centered in the band as it grows/shrinks instead of jumping only
  // once the transition finishes. Opacity reuses d.target.opacity (the
  // same visibility signal driving the ring's own fill-opacity, set
  // above): when a goal is selected, every other ring's label fades out
  // along with its band, and pointer-events is disabled on those hidden
  // labels so they can't be clicked while invisible — otherwise a label
  // sitting under/near the expanded band would still intercept clicks
  // meant for the visible one, and clicking it would immediately
  // re-subset to an irrelevant goal.
  g.selectAll(".ring-label")
    .data(ringRadii, (d) => d.goal)
    .style("pointer-events", (d) => (d.target.opacity > 0 ? "auto" : "none"))
    .transition(t)
    .attrTween("transform", (d) => () => ringLabelTransform(d))
    .style("opacity", (d) => d.target.opacity / 0.15);

  // --- cells (EV x ring segments) ---
  // .current is already correctly resolved per-datum above (either carried
  // over from the previously-rendered node with the same key, or defaulted
  // to its own target for a brand-new cell), so enter/update need no extra
  // reconciliation here — only exit needs a callback (plain removal).
  const cellSel = g.selectAll(".cell")
    .data(activeCells, (d) => `${d.paramName}__${d.ring.goal}`)
    .join(
      (enter) => enter.append("path")
        .attr("class", "cell")
        .attr("fill", (d) => CATEGORY_COLORS[d.serviceCategory])
        .attr("stroke", "none")
        .attr("d", (d) => tweenCellArc(d))
        .attr("fill-opacity", (d) => d.target.opacity),
      (update) => update,
      (exit) => exit.remove()
    );

  cellSel.transition(t)
    .attrTween("d", (d) => {
      const i = d3.interpolate(d.current, d.target);
      return (tt) => {
        d.current = i(tt);
        return tweenCellArc(d);
      };
    })
    .attr("fill-opacity", (d) => d.target.opacity);

  // --- hover hit-targets ---
  g.selectAll(".hover-target")
    .data(activeRows, (d) => d.paramName)
    .join("path")
      .attr("class", "hover-target")
      .style("fill", "transparent")
      .style("pointer-events", "all")
      .on("mouseover", handleRayHover)
      .on("mouseout", handleRayHoverExit)
    .transition(t)
      .attr("d", hoverArc);

  // --- ray divider ticks ---
  // With ray tip labels removed, there's no other way to tell where one
  // EV's wedge ends and the next begins, or roughly how many there are.
  // One short radial tick per wedge boundary, just outside the outer
  // ring: N wedges share N-1 interior boundaries plus their own two
  // outer edges, so angle0 of every wedge plus the last wedge's angle1
  // gives exactly N+1 tick positions with no duplicates.
  const tickAngles = activeRows.map((d) => d.angle0);
  if (activeRows.length > 0) tickAngles.push(activeRows[activeRows.length - 1].angle1);
  const tickInner = maxRadius + 2;
  const tickOuter = maxRadius + 8;

  g.selectAll(".ray-tick")
    .data(tickAngles, (a, i) => i)
    .join("line")
      .attr("class", "ray-tick")
      .attr("stroke", "#8a8a8a")
      .attr("stroke-width", 1)
      .style("pointer-events", "none")
    .transition(t)
      .attr("x1", (a) => tickInner * Math.cos(angleScale(a) - Math.PI / 2))
      .attr("y1", (a) => tickInner * Math.sin(angleScale(a) - Math.PI / 2))
      .attr("x2", (a) => tickOuter * Math.cos(angleScale(a) - Math.PI / 2))
      .attr("y2", (a) => tickOuter * Math.sin(angleScale(a) - Math.PI / 2));

  centerReset.raise();
}

const centerReset = g.append("circle")
  .attr("class", "center-reset")
  .attr("r", ringRadii[0].r0)
  .attr("fill", "none")
  .attr("pointer-events", "all")
  .style("cursor", "pointer")
  .on("click", function () {
    selectedGoal = null;
    render();
  });
centerReset.raise(); // keep the reset target above ring/cell paths

render(); // initial draw + attaches click handlers
