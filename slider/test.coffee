container = $ "#slider"

slider = new $blab.Slider
  container: container
  prompt: "x"
  unit: "Hz"
  init: 10

display = -> $("#result").html("Slider value = " + slider.getVal())

display()
slider.change -> display()

