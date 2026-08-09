svg.style("background-color", "transparent");
svg.attr("id", "svg-flowerplot");

//const totalWidth = 400;
//const labelsFontSize = "12px";

// flowerbox is div we put the flower plot inside
const flowerBox = document.querySelector(".flower-box");
const totalWidth = Math.min(flowerBox.clientWidth, flowerBox.clientHeight);

// font can be larger if screen is wider
// font size is taken from style.css flower-box class
const labelsFontSize = window.getComputedStyle(flowerBox).fontSize;
const fontSizeNumeric = parseFloat(labelsFontSize);

// constants for plot dimensions
const centerRadius = 0.05 * totalWidth;
const labelsRadius = 0.5 * totalWidth;
const flowerRadius = 0.33 * totalWidth;

// to leave space
// for an axis for score petals
const yaxisArc = 0.2;

// which level to view
// start with goals being plotted as petals
const viewDepth = 2 + options.addViewDepth;

// region and year to plot
const plotRegion = options.plotRegion;
const plotYear = options.plotYear;

// scales
// scale for the flowerplot score axis
const minScore = 0.1;
const maxScore = 115;
const flowerRadiusScale = d3.scaleLinear()
  .range([centerRadius, flowerRadius])
  .domain([minScore, maxScore]);

// scale for the labels bandwidth and placement
const labsRadiusScale = d3.scaleLinear()
  .domain([viewDepth - 2, viewDepth])
  .range([labelsRadius, flowerRadius]);

// scale for angles
const angleScale = d3.scaleLinear()
  .range([Math.PI + yaxisArc, 3 * Math.PI - yaxisArc])
  // once can reverse SVG path, can make y-axis on top
  //.range([yaxisArc, 2 * Math.PI - yaxisArc])
  .domain([0, 1]);


// configure the data using hierarchy and partition layouts

// data hierarchy and layout with partition
// const root = d3.hierarchy(testData)
const hierarchy = d3.hierarchy(data[plotRegion][plotYear])
  .sort((a, b) => b.data.score - a.data.score)
  // node value is just our configuration widths
  .eachBefore(node => {
    node.value = node.data.weight;
  });

const partition = d3.partition()
  .size([1, labelsRadius]);

const root = partition(hierarchy);
root.each(d => d.current = d);


// colors for plotting
// main categories colors
const mainColorScale = d3.scaleOrdinal()
  // will need to change these once join fullname/shortname labels!!
  .domain(["birds", "mammals", "fish", "pelagic_habitat","benthic_habitat"])
  .range(["#f6939b","#f6939b","#f6939b","#f6939b","#f6939b"]);

// helcom color gradient best to worst
// #638e7f, #b1c7bf, #f5abb1, #c2606a, #71160e

// functions to generate colors for petals based on scores
function generatePetalColors(mainColor, score) {
  const color1 = d3.rgb(mainColor);
  const color2 = d3.rgb("#9e0d00");
  const color3 = d3.rgb("#b1c7bf");
  const color4 = d3.rgb("#638e7f");
  const t = d3.scaleLinear()
    .domain([minScore, maxScore])
    .range([1,0]);
  if (score > 60) {
    const tAlt = d3.scaleLinear()
      .domain([60, maxScore])
      .range([0,1])(score);
    return d3.interpolateRgb(color3, color4)(tAlt)
  } else {
    return d3.interpolateRgb(color1, color2)(t(score));
  }
}
function colorScale(d) {
  if (d.depth === 0) return "#06406a"
  if (d.depth === 1) {
    return mainColorScale(d.data.name);
  } else if (d.depth >= 2) {
    let ancestor = d;
    while (ancestor.depth > 1) {
      ancestor = ancestor.parent;
    }
    const mainColor = mainColorScale(ancestor.data.name);
    return generatePetalColors(mainColor, d.data.score);
  }
  return "#06406a";
}

// svg container is already created by r2d3
// create a group element on top of the svg and center it in the svg
// remove g group first because shiny input changes will result in new plot on top
svg.selectAll("g").remove();
const g = svg.append("g")
  .attr("transform", `translate(${totalWidth / 2}, ${totalWidth / 2})`)
  .attr("width", totalWidth)
  .attr("height", totalWidth)
  .style("font-family", "Roboto");

// y axis for flowerplot scores
// grid lines and numbers
const gridlines = g.selectAll("gridlines")
  .data(d3.ticks(minScore, maxScore, 5))
  .join("circle")
    .attr("r", d => flowerRadiusScale(d))
    .attr("fill", "none")
    .attr("stroke", "black")
    .attr("stroke-width", 0.3);

const yaxis = g.selectAll("yaxis.text")
  .data(d3.ticks(minScore, maxScore, 5))
  .join("text")
  .attr("y", d => flowerRadiusScale(d))
  .attr("dy", "0.32em")
  // once can reverse SVG path, can make y-axis on top
  //.attr("y", d => -flowerRadiusScale(d))
  //.attr("dy", "-0.32em")
  .attr("text-anchor", "middle")
  .text(d => d.toFixed(0))
  .style("font-size", "9px");


// arc generators for labels,
// one for boxes, one for centering text
const arc = d3.arc()
  .startAngle(d => angleScale(d.x0))
  .endAngle(d => angleScale(d.x1))
  .cornerRadius(5)
  .innerRadius(d => labsRadiusScale(d.depth - 1))
  .outerRadius(d => labsRadiusScale(d.depth));

const textArc = d3.arc()
  .startAngle(d => angleScale(d.x0))
  .endAngle(d => angleScale(d.x1))
  .innerRadius(d => {
    const midRadius = (labsRadiusScale(d.depth - 1) + labsRadiusScale(d.depth)) / 2;
    return midRadius - (fontSizeNumeric / 2);
  })
  .outerRadius(d => {
    const midRadius = (labsRadiusScale(d.depth - 1) + labsRadiusScale(d.depth)) / 2;
    return midRadius - (fontSizeNumeric / 2);
  });

function removeInnerArc(path) {
  return path.replace(/(M.*A.*)(A.*Z)/, function(_, m1) {
    return m1 || path;
  });
}
// would need to figure out how to reverse the SVG textpaths
// in order for text not to be upside-down...
//function reverseSVGPath(path) {
//  return path.split(/(?=[MmLlHhVvCcSsQqTtAaZz])/)
//    .reverse()
//    .map(segment => {
//      const command = segment[0];
//      const coords = segment.slice(1).split(',').reverse().join(',');
//      return command + coords;
//    })
//    .join('')
//    .replace(/^Z/, '')
//    .concat('Z');
//}

// arcs visible for current view depth
// and one level higher
function arcVisible(d) {
  const visibleAngles = d.x1 <= 1 && d.x0 >= 0;
  const visibleDepths = d.depth <= viewDepth && d.depth >= viewDepth - 1;
  return visibleAngles && visibleDepths;
}
function labelVisible(d) {
  const arcWidth = (d.x1 - d.x0) > 0.05;
  const visibleAngles = d.x1 <= 1 && d.x0 >= 0;
  const visibleDepths = d.depth <= viewDepth && d.depth >= viewDepth - 1;
  return arcWidth && visibleAngles && visibleDepths;
}
function petalVisible(d) {
  const visibleAngles = d.x1 <= 1 && d.x0 >= 0;
  const visibleDepths = d.depth === viewDepth;
  return visibleAngles && visibleDepths;
}

// draw the arcs
const path = g.selectAll("path")
  .data(root.descendants())
  .join("path")
    .attr("class", "label")
    .attr("d", d => arc(d.current))
    .attr("stroke-width", 3)
    .attr("fill", d => colorScale(d))
    .attr("fill-opacity", d => arcVisible(d.current) ? 0.9 : 0)
    .attr("stroke", d => arcVisible(d.current) ? "#f1f1f1" : "transparent");

path.filter(d => d.children)
  .style("cursor", "pointer")
  .on("click", function(event, d) {
    clicked(event, d);
  });


// add labels text
// along paths generated with arcText
const textpaths = g.selectAll(".text-path")
  .data(root.descendants())
  .join("path")
    .attr("class", "text-path")
    .attr("id", (d, i) => `text-path-${i}`)
    .attr("d", d => removeInnerArc(textArc(d)))
    // once can reverse SVG path, can make y-axis on top
    //.attr("d", d => {
    //  const path = textArc(d);
    //  const checkAngle = d.x0 > 1/3 && d.x1 < 2/3;
    //  const processedPath = checkAngle ? reverseSVGPath(path) : path;
    //  return removeInnerArc(processedPath);
    //})
    .style("fill", "none");

const labeltext = g.selectAll(".curved-text")
  .data(root.descendants())
  .join("text")
    .attr("class", "curved-text")
    .append("textPath")
      .attr("xlink:href", (d, i) => `#text-path-${i}`)
      .attr("startOffset", "50%")
      .attr("text-anchor", "middle")
      .text(d => d.data.name)
      // where arc is too narrow, or not currently visible
      // make the text transparent
      .style("fill", d => labelVisible(d.current) ? "white" : "transparent");

// flower petals
// arc generator for flower petals
const petalArc = d3.arc()
  .startAngle(d => angleScale(d.x0))
  .endAngle(d => angleScale(d.x1))
  .innerRadius(d => centerRadius)
  .outerRadius(d => flowerRadiusScale(d.data.score));

const petalHoverArc = d3.arc()
  .startAngle(d => angleScale(d.x0))
  .endAngle(d => angleScale(d.x1))
  .innerRadius(d => centerRadius)
  .outerRadius(d => flowerRadius);

// draw the petals
function handlePetalHover(event, d) {
  g.selectAll(".popup-text").remove();
  g.append("text")
    .attr("class", "popup-text")
    .attr("text-anchor", "middle")
    .attr("dominant-baseline", "middle")
    .style("font-size", "18px")
    .style("fill", "black")
    .selectAll("tspan")
    .data([d.data.name, Math.round(d.data.score)])
    .join("tspan")
      .attr("x", 0)
      .attr("dy", (t, i) => i ? "1.2em" : "-0.6em")
      .text(t => t);
}
function handlePetalHoverExit() {
  g.selectAll(".popup-text").remove();
}

const flower = g.selectAll(".petal")
  .data(root.descendants(), d => d.data.name)
  .join("path")
      .attr("class", "petal")
      .attr("d", d => petalArc(d.current))
      .attr("stroke-width", 0.5)
      .attr("fill", d => colorScale(d))
      .attr("fill-opacity", d => petalVisible(d.current) ? 0.9 : 0)
      .attr("stroke", d => petalVisible(d.current) ? "black" : "transparent");

const flowerHover = g.selectAll(".petalhover")
  .data(root.descendants(), d => d.data.name)
  .join("path")
      .attr("class", "petalhover")
      .attr("d", d => petalHoverArc(d.current))
      .style("opacity", 0)
      .style("pointer-events", d => petalVisible(d.current) ? "auto" : "none")
      .selection()
      .on("mouseover", handlePetalHover)
      .on("mouseout", handlePetalHoverExit);


// adding subsetting on click of outer labels
// clicking center will reset view to see all goals
const resetView = g.append("circle")
  .datum(root)
  .attr("r", centerRadius)
  .attr("fill", "none")
  .attr("pointer-events", "all")
  .style("cursor", "pointer")
  .on("click", function(event, d) {
    clicked(event, d);
  });


// subsetting petals based on clicked label
function clicked(event, p) {
  resetView.datum(p.parent || root);
  const t = svg.transition().duration(1000);

  root.each(function(d) {
    d.target = {
      x0: Math.max(0, Math.min(1, (d.x0 - p.x0) / (p.x1 - p.x0))),
      x1: Math.max(0, Math.min(1, (d.x1 - p.x0) / (p.x1 - p.x0))),
      depth: (d.depth - p.depth) + (viewDepth - 1),
      score: d.data.score
    };
    //console.log(`
    //  "New coords", ${d.data.name}, ${d.target.x0}, ${d.target.x1},
    //  "New depths", ${d.target.depth - 1}, ${d.target.depth},
    //  "Viewdepth:", ${viewDepth}
    //`);
  });

  // tween/transition arcs
  path.transition(t)
    .tween("data", d => {
      const i = d3.interpolate(d.current, d.target);
      return t => d.current = i(t);
    })
    .filter(function(d) {
      return +this.getAttribute("fill-opacity") || arcVisible(d.target);
    })
    .attr("fill-opacity", d => arcVisible(d.target) ? 0.9 : 0)
    .attr("stroke", d => arcVisible(d.target) ? "#f1f1f1" : "transparent")
    .attr("pointer-events", d => arcVisible(d.target) ? "auto" : "none")
    .attrTween("d", d => () => arc(d.current));

  // tween/transition text labels
  textpaths.transition(t)
    .attrTween("d", d => () => removeInnerArc(textArc(d.current)));

  labeltext.transition(t)
    .delay(100)
    .style("fill", d => labelVisible(d.target) ? "white" : "transparent");

  // tween/transition flower petals
  flower.transition(t)
    .attrTween("d", function(d) {
      const interpolate = d3.interpolate(d.current, d.target);
      return function(t) {
        const current = interpolate(t);
        current.data = { ...d.data }; // Preserve the original data
        return petalArc(current);
      };
    })
    .attr("fill-opacity", d => petalVisible(d.target) ? 0.9 : 0)
    .attr("stroke", d => petalVisible(d.target) ? "black" : "transparent");

  flowerHover.transition(t)
    .attrTween("d", function(d) {
      const interpolate = d3.interpolate(d.current, d.target);
      return function(t) {
        d.current = interpolate(t);
        return petalHoverArc(d.current);
      };
    })
    .style("pointer-events", d => petalVisible(d.target) ? "auto" : "none");

  // determine visible groups for shiny leaflet map
  const selectedLayers = p.descendants()
    .filter(d => petalVisible(d.target))
    .flatMap(d =>
      hierarchy.descendants()
        .filter(h => h.data === d.data)
        .flatMap(h => h.leaves())
    )
    .map(d => d.data.name);
  //console.log(selectedLayers);

  // send to shiny
  Shiny.setInputValue("d3_selected", selectedLayers, {priority: "event"});
}


// handle download of flowerplot as svg
d3.select("#downloadFlower").on("click", function() {
  const hostElement = document.querySelector("#d3_flower");
  const svgElements = hostElement.shadowRoot.querySelector("#svg-flowerplot");

  const serializer = new XMLSerializer();
  const svgContent = serializer.serializeToString(svgElements);
  const svgBlob = new Blob([svgContent], { type: "image/svg+xml;charset=utf-8" });
  const svgUrl = URL.createObjectURL(svgBlob);

  const flowerFilename = `flowerplot-${plotRegion}-${viewDepth}.svg`;

  d3.select(this)
    .attr("href", svgUrl)
    .attr("download", flowerFilename);
});

