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
  
  change: (f) -> @input.change f
  
  mouseup: (f) -> @input.mouseup f

  val: -> @input.val()


Widget = $blab?.Widget

unless Widget
  window.Input = Input
  # TODO: improve export approach.
  return


# Input widget for blabr.

class InputWidget extends Widget
  
  @handle: "input2"
  
  @cssUrl: "/puzlet/widgets/input2/style.css"
  
  @initVal: 0
  
  @initSpec: (id) -> """
    init: #{InputWidget.initVal}
    prompt: "#{id}:"
    unit: ""
    align: "left"
    pos: 1, order: 1
  """
  
  @compute: (id, v...) ->
    @getVal(id, v...) ? @initVal
  
  create: (@spec) ->
    
    {@init, @prompt, @unit, @align} = @spec
    
    @inputContainer = $("#"+@domId())
    if @inputContainer.length
      # TODO: Need to destroy input?
      @outer = @inputContainer.parent()
      @outer?.remove()
    
    @outer = $ "<div>",
      class: "input-container"
      mouseup: => @select()
      
    @input = new Input
      container: @outer
      init: @init
      prompt: @prompt
      unit: @unit
      align: @align
      change: =>
        @setVal(parseFloat(@input.val()))
        @computeAll()
      
    @input.mouseup (e) -> e.stopPropagation()
    
    @inputContainer = @input.inputContainer
    @inputContainer.attr id: @domId()
    @inputContainer.mouseup (e) => e.stopPropagation()
    
    @appendToCanvas @outer
    
    @setVal @init
  
  initialize: -> @setVal @init
  
  setVal: (v) ->
    @value = v
  
  getVal: ->
    @setUsed()
    @value


Widget.register [InputWidget]
