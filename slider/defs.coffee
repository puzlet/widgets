#!vanilla
#!no-math-sugar

# Slider component for any web page.

class Slider
  
  constructor: (@spec) ->
  
    {@container, @min, @max, @step, @init, @prompt, @text, @val, @unit, change} = @spec
    # @text is to be deprecated (use @val instead)
  
    @sliding = false
    
    @sliderPromptContainer = $ "<div>", class: "slider-prompt-container"
    @container.append @sliderPromptContainer
    
    @sliderPrompt = $ "<div>", class: "slider-prompt"
    @sliderPromptContainer.append @sliderPrompt
    
    @sliderPrompt.append @prompt
    
    @sliderContainer = $ "<div>", class: "puzlet-slider"
    @container.append @sliderContainer
    
    @textContainer = $ "<div>", class: "slider-text-container"
    @container.append @textContainer
    
    @textDiv = $ "<div>", class: "slider-text-1"
    @textContainer.append @textDiv
    
    @textDiv2 = $ "<div>", class: "slider-text-2"
    @textContainer.append @textDiv2
    
    @textDiv2.html @unit if @unit
    
    @fast = @spec.fast ? true
    
    @changeFcn = if change then (-> change()) else (->)
    
    @slider = @sliderContainer.slider
      #orientation: "vertical"
      range: "min"
      min: @min
      max: @max
      step: @step
      value: @init
      mouseup: (e) ->
      slide: (e, ui) =>
        @sliding = true
        @set(ui.value)
        @changeFcn() if @fast
      change: (e, ui) =>
        @set(ui.value)
        @changeFcn() unless @fast
        setTimeout (=> @sliding = false), 100 # Unused because responds to slide method
        
    # Stop mouseup propagation (specific to Blabr?)
    @slider.mouseup (e) -> e.stopPropagation()
    # @sliderContainer.mouseup (e) -> e.stopPropagation()
    
    @set @init
    
  destroy: ->
    @sliderContainer.slider?("destroy")
    @container.empty()  # Unsafe?
    
  change: (f) -> @changeFcn = -> f?()
  
  mouseup: (f) -> @slider.mouseup f
  
  set: (v) ->
    @textDiv.html(if @val then @val(v) else if @text then @text(v) else v)
    @value = v
    
  getVal: -> @value
  

Widget = $blab?.Widget
unless Widget
  window.$blab ?= {}
  $blab.Slider = Slider
  return


# Slider widget for blabr.

class SliderWidget extends Widget
  
  @handle: "slider2"
  
  @source: true
  
  @initVal: 5
  
  @cssUrl: "/puzlet/widgets/slider/style.css"
  
  @initSpec: (id) -> """
    min: 0, max: 10, step: 0.1, init: #{SliderWidget.initVal}
    prompt: "#{id}:"
    unit: ""
    pos: 1, order: 1
  """
  
  create: (@spec) ->
    
    {@min, @max, @step, @init, @prompt, @text, @val, @unit, @fast} = @spec
    
    @outer = $ "<div>", class: "slider-container"
    
    @slider = new Slider
      container: @outer
      # orientation: "vertical"  # Not working yet.
      range: "min"
      min: @min
      max: @max
      step: @step
      init: @init
      prompt: @prompt
      val: @val
      unit: @unit
      fast: @fast
      change: => @computeAll()
    
    @appendToCanvas @outer
    
    # Override default mouseup behavior.
    # Not needed if stop propagation for slider mouseup?
    # @outer.unbind "mouseup"
    # @outer.mouseup (evt) =>
    #   return if $(evt.target).hasClass("ui-slider-handle")
    #   @select() unless @slider.sliding
    #   @slider.sliding = false
    
    # For popup editor manager.  Needed?
    # @slider.sliderContainer.mousedown (e) => $.event.trigger "clickInputWidget"
    
  initialize: -> @setVal @init
  
  destroy: -> @slider.destroy()
  
  setVal: (v) -> @slider.set v
  
  getVal: -> @slider.getVal()


Widget.register [SliderWidget]
