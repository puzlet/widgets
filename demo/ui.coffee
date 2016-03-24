components = $blab.components

input = new components.Slider
  container: $("#input")
  prompt: "Frequency"
  unit: "Hz"
  init: 10
  min: 0
  max: 40

plot = new components.Plot
  container: $("#plot")
  title: "TEST PLOT, $f(x)$"
  width: 500, height: 300
  xlabel: "x", ylabel: "y"
  # xaxis: {min: 0, max: 1}
  # yaxis: {min: 0, max: 1}
  series: {lines: lineWidth: 2}
  colors: ["red", "blue"]
  grid: {backgroundColor: "white"}

compute = $blab.resources.find "compute.coffee"
input.change -> compute.compile()  # Does not compile if code unchanged

$blab.ui =
  input: -> parseFloat(input.getVal())
  result: (f) -> $("#result").html("Frequency " + f + " Hz")
  plot: (x, y) -> plot.setVal([x, y])
 