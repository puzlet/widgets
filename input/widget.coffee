#!vanilla
#!no-math-sugar

# Input widget for blabr.

Widget = $blab.Widget

class Input2 extends Widget
  
  @handle: "input2"
  
  @source: true
  
  @initVal: 0
  
  @initSpec: (id) -> """
    init: #{@initVal}
    prompt: "#{id}:"
    unit: ""
    align: "left"
    pos: 1, order: 1
  """

  create: (@spec) ->
  
    {@init, @prompt, @unit, @align} = @spec
  
    @outer = $ "<div>", class: "input-container"
    
    @input = new $blab.components.puzlet.Input
      container: @outer
      init: @init
      prompt: @prompt
      unit: @unit
      align: @align
      change: =>
        @setVal(parseFloat(@input.val()))
        @computeAll()
    
    @appendToCanvas @outer
    
    @setVal @init

# TODO: need a way to stop this if compiling widget.coffee.
# e.g., temporarily redefine Widget.register to accumulate string?
Widget.register [Input2]