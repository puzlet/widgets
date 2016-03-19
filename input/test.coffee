container = $ "#input"

input = new $blab.Input
  container: container
  prompt: "Input"
  unit: "Hz"
  init: 2

display = -> $("#result").html("Input value = " + input.val())

display()
input.change -> display()
  