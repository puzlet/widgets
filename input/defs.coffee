#!vanilla
#!no-math-sugar

# Input component for any web page.

class Input
  
  constructor: (@spec) ->
    
    {@container, @init, @prompt, @unit, @align, change} = @spec
    
    @promptContainer = $ "<div>", class: "input-prompt-container"
    @container.append @promptContainer
    
    @inputPrompt = $ "<div>", class: "input-prompt"
    @promptContainer.append @inputPrompt
    @inputPrompt.append @prompt
    
    @inputContainer = $ "<div>", class: "blab-input"
    @container.append @inputContainer
    
    @textContainer = $ "<div>", class: "input-text-container"
    @container.append @textContainer
    
    @textDiv = $ "<div>", class: "input-text"
    @textContainer.append @textDiv
    
    @textDiv.html @unit if @unit
    
    @input = $ "<input>",
      type: "number"
      value: @init
      change: => change?()
    
    @input.css(textAlign: @align) if @align
    
    @inputContainer.append @input
    
    # Stop mouseup propagation (specific to Blabr?)
    @input.mouseup (e) -> e.stopPropagation()
    @inputContainer.mouseup (e) -> e.stopPropagation()
  
  change: (f) -> @input.change f
  
  val: -> @input.val()


Widget = $blab?.Widget
unless Widget
  window.$blab ?= {}
  $blab.Input = Input
  return


# Input widget for blabr.

class InputWidget extends Widget
  
  @handle: "input2"
  
  @source: true
  
  @initVal: 0
  
  @cssUrl: "/puzlet/widgets/input/style.css"
  
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
      
    @input = new Input
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


Widget.register [InputWidget]
