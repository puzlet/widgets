#!vanilla

Widget = $blab.Widget

class Input extends Widget
  
  @handle: "input"
  
  @initVal: 0
  
  @initSpec: (id) -> """
    init: #{Input.initVal}
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
      
    clickEvent = => @select()
    
    @outer = $ "<div>", class: "input-container"
      
    @promptContainer = $ "<div>", class: "input-prompt-container"
    @outer.append @promptContainer
    
    @inputPrompt = $ "<div>", class: "input-prompt"
    @promptContainer.append @inputPrompt
    
    @inputPrompt.append @prompt
    
    @inputContainer = $ "<div>",
      class: "blab-input"
      id: @domId()
      click: => clickEvent()
    @outer.append @inputContainer
    
    @outer.click -> clickEvent()
    
    @textContainer = $ "<div>", class: "input-text-container"
    @outer.append @textContainer
    
    @textDiv = $ "<div>", class: "input-text"
    @textContainer.append @textDiv
    
    @textDiv.html @unit if @unit
    
    @appendToCanvas @outer
    
    @input = $ "<input>",
      type: "number"
      value: @init
      click: (e) -> e.stopPropagation()
      change: =>
        @setVal(parseFloat(@input.val()))
        @computeAll()
        
    @input.css(textAlign: @align) if @align
    
    @inputContainer.append @input
    
    @setVal @init
    
  initialize: -> @setVal @init
  
  setVal: (v) ->
    @value = v
  
  getVal: ->
    @setUsed()
    @value


class Slider extends Widget
  
  @handle: "slider"
  
  @initVal: 5
  
  @initSpec: (id) -> """
    min: 0, max: 10, step: 0.1, init: #{Slider.initVal}
    prompt: "#{id}:"
    unit: ""
    pos: 1, order: 1
  """
  
  @compute: (id, v...) ->
    @getVal(id, v...) ? @initVal
  
  create: (@spec) ->
    
    {@min, @max, @step, @init, @prompt, @text, @val, @unit} = @spec
    # @text is to be deprecated (use @val instead)
    
    @sliderContainer = $("#"+@domId())
    if @sliderContainer.length
      @sliderContainer.slider?("destroy")
      @outer = @sliderContainer.parent()
      @outer?.remove()
    
    sliding = false
    
    clickEvent = =>
      @select() unless sliding
      sliding = false
    
    @outer = $ "<div>", class: "slider-container"
      
    @sliderPromptContainer = $ "<div>", class: "slider-prompt-container"
    @outer.append @sliderPromptContainer
    
    @sliderPrompt = $ "<div>", class: "slider-prompt"
    @sliderPromptContainer.append @sliderPrompt
    
    @sliderPrompt.append @prompt
    
    @sliderContainer = $ "<div>",
      class: "puzlet-slider"
      id: @domId()
      #click: => clickEvent()
    @outer.append @sliderContainer
        
    @outer.click -> clickEvent()
    
    @textContainer = $ "<div>", class: "slider-text-container"
    @outer.append @textContainer
    
    @textDiv = $ "<div>", class: "slider-text-1"
    @textContainer.append @textDiv
    
    @textDiv2 = $ "<div>", class: "slider-text-2"
    @textContainer.append @textDiv2
    
    @textDiv2.html @unit if @unit
    
    @appendToCanvas @outer
    
    @fast = @spec.fast ? true
    
    @slider = @sliderContainer.slider
      #orientation: "vertical"
      range: "min"
      min: @min
      max: @max
      step: @step
      value: @init
      slide: (e, ui) =>
        sliding = true
        @setVal(ui.value)
        @computeAll() if @fast  # Superclass method
      change: (e, ui) =>
        #@setVal(ui.value)
        @computeAll() unless @fast
        setTimeout (-> sliding = false), 100 # Unused because responds to slide method
    
    @setVal @init
    
  initialize: -> @setVal @init
  
  setVal: (v) ->
    @textDiv.html(if @val then @val(v) else if @text then @text(v) else v)
    @value = v
  
  getVal: ->
    @setUsed()
    @value


class Table extends Widget
  
  @handle: "table"
  
  @initSpec: (id, v) ->
    """
      headings: []  # ["Column 1", "Column 2"]
      widths: [100]  #[100, 100]
      pos: 1, order: 1
    """
  
  @compute: (id, v...) ->
    return unless v.length
    unless v[0] instanceof Object
      for x, idx in v
        v[idx] = [x] unless Array.isArray(x)
    @setValAndGet(id, v...)
  
  create: (@spec) ->
    
    {@headings, @widths, @colCss, @css, @precision} = @spec
    
    @table = $ "#"+@domId()
    @table.remove() if @table.length
    @table = $ "<table>",
      id: @domId()
      class: "widget"
      click: => @select()
    
    @table.css(@css) if @css
    
    colGroup = $ "<colgroup>"
    @table.append colGroup
    @widths ?= [100]
    @widths = [@widths] unless Array.isArray(@widths)
    for w, idx in @widths
      css = @colCss?[idx] ? {}
      css.width = w
      col = $ "<col>", css: css
      colGroup.append col
      
    if @headings
      tr = $ "<tr>"
      @table.append tr
      for h, idx in @headings
        tr.append "<th>#{h}</th>"
      
    @tbody = $ "<tbody>"
    @table.append @tbody
    
    @appendToCanvas @table
    
    $blab.tableData ?= {}
    $blab.tableData[@id] ?= {}
    @tableData = $blab.tableData[@id]
    
    @setVal([[0]])
    
  initialize: ->
  
  setVal: (v) ->
    @setUsed()
    
    unless v[0] instanceof Array
      # Doesn't yet handle multiple objects (rows)
      @v0 = v[0]
      @first = null
      return @setValObject()
    
    @tbody.empty()
    row = []
    for x, idx in v[0]
      tr = $ "<tr>"
      @tbody.append tr
      for i in [0...v.length]
        d = v[i][idx]
        val = if typeof d is "number" then @format(d) else d
        tr.append "<td>"+val+"</td>"
    @value = v
    null
    
  setValObject: ->
    
    # Doesn't yet handle multiple objects (rows)
    
    console.log "Table object mode", @v0
    
    # TODO: define in constructor?
    @t ?= {}  # Table object after evaluation
    @t.set = (p) =>
      for name, val of p
        @v0[name] = val
      @setValObject()
      null
    
    # Initial pass to set known values
#TEMP    @t[name] = val for name, val of @v0
    
    # TODO: need a way to handle function sequence
  
    # Note: it does not work in dataflow fashion.
    # Column functions must be defined in order.
    # Otherwise, can use post-set mathods.
    cols = []  # Columns
    for name, val of @v0
      @first = name unless @first
      if typeof val is "function"
        val = val(@t)  # defer
      else
        @tableData[name] ?= val
        val = @tableData[name]
      @t[name] = val
      val = [val] unless Array.isArray(val)  # ZZZ not needed?
      cols.push val  # not needed?
      
    @setVal2() # cols
    
    @t
  
  setVal2: ->
    
    # TODO:
    # specify empty col as [null, null, null] - to set length - have helper function to gen.
    # this will render as " ", but vals will be zero.
    # what about text values in cells - currently assumes numeric.
    
    @tbody.empty()
    row = []
    
    @editableCells = []
    
    for x, idx in @v0[@first] #v[0]
      tr = $ "<tr>"
      @tbody.append tr
      
      for name, v of @v0
        
        vs = @tableData[name]
        d = if vs then vs[idx] else @t[name][idx]
        
        td = $ "<td>"
        tr.append td
        
        if typeof v is "function"
          val = if typeof d is "number" then @format(d) else d
          td.append val
        else
          cell = new EditableCell
            container: td
            edited: @set(name, idx)
            val: d  # TODO: need to format for display?
          @editableCells.push cell
          
    @clickNext()
    @value = v
    
  set: (name, idx) ->
    # Returns set/edited function.
    (val, changed, dir) =>
      @setNext(idx, dir)
      if changed
        @tableData[name][idx] = val
        @computeAll()
      else
        @clickNext()
  
  setNext: (idx, dir) ->
    if dir is 0
      @editNext = false
    else
      @editNext = idx + dir
      @editNext = idx unless @nextOk()
  
  clickNext: ->
    return unless @nextOk()
    @editableCells[@editNext].click()
    @editNext = false
    
  nextOk: ->
    @editNext isnt false and @editNext>=0 and @editNext<@editableCells.length
   
  format: (x) ->
    if x is 0 or Number.isInteger?(x) and Math.abs(x)<1e10
      x
    else
      x.toPrecision(@precision ? 4) 


class EditableCell
  
  constructor: (@spec) ->
    
    {@container, @val, @edited} = @spec
    
    @div = $ "<div>",
      class: "editable-table-cell"
      text: @val
      click: (e) =>
        e.stopPropagation()
        @click()
        
    @container.append @div
  
  click: ->
    @div.empty()
    @createInput()
    @div.append @input
    @input.focus()
    @input.select()
    
  reset: ->
    @div.empty()
    @div.text @val
    
  createInput: ->
    @input = $ "<input>",
      class: "editable-table-input-field"
      value:  @val
      click: (e) -> e.stopPropagation()
      keydown: (e) => @keyDown(e)
      change: (e) => @change(e)
      blur: => @reset()
        
  keyDown: (e) ->
    
    key = e.keyCode
    
    ret = 13
    up = 38
    down = 40
    
    if key is ret
      # Handle case where user presses return without changing value.
      @noChange = true
      @done(1)
      return
    
    return unless key in [up, down]
    e.preventDefault()
    dir = if key is down then 1 else -1
    @done(dir)
    
  change: (e) ->
    @done() unless @noChange
  
  done: (dir=0) ->
    val = parseFloat(@input.val())
    changed = val isnt @val
    @val = val if changed
    @edited val, changed, dir


class Plot extends Widget
  
  @handle: "plot"
  
  @initSpec: (id) -> """
    width: 300, height: 200
    xlabel: "x", ylabel: "y"
    # xaxis: {min: 0, max: 1}
    # yaxis: {min: 0, max: 1}
    series: {lines: lineWidth: 1}
    colors: ["red", "blue"]
    grid: {backgroundColor: "white"}
    pos: 1, order: 1
  """
  
  @compute: (id, v...) ->
    @setVal(id, v...)
  
  create: (@spec) ->
    
    {@width, @height, @xlabel, @ylabel, @css} = @spec
    
    @plot = $("#"+@domId())
    @plot.remove() if @plot.length
    @plot = $ "<div>",
      id: @domId()
      class: "puzlet-plot"
      css:
        width: @width ? 400
        height: @height ? 200
      click: => @select()
    
    @plot.css(@css) if @css
    
    @appendToCanvas @plot
    
    @setVal([[0], [0]])
    
  initialize: ->
  
  setVal: (v) ->
    
    @setUsed()
    @value = v
    
    params = @spec
    params.series.shadowSize ?= 0
    params.series ?= {color: "#55f"}
    @setAxes params
    
    lol = (u) -> # list of lists
      if u[0].length?
        z = u
      else
        z = []
        z.push u
      z
      
    X = lol v[0]
    Y = lol v[1]
    
    maxRows =  Math.max(X.length, Y.length)
    d = []
    for k in [0...maxRows]
      xRow = Math.min(k,X.length-1)
      yRow = Math.min(k,Y.length-1)
      l = numeric.transpose([X[xRow], Y[yRow]])
      d.push l
    
    @flot = $.plot @plot, d, params
    
    # Center plot in parent container
    o = @flot.getPlotOffset()
    m = (@plot.parent().width() - @plot.width() - o.left + o.right)/2
    @plot.css marginLeft: m
    
  setAxes: (params) ->
    
    params.xaxis ?= {}
    params.yaxis ?= {}
    
    params.xaxis?.axisLabel = params.xlabel if params.xlabel
    params.yaxis?.axisLabel = params.ylabel if params.ylabel
    params.xaxis?.axisLabelUseCanvas ?= true
    params.yaxis?.axisLabelUseCanvas ?= true
    params.xaxis?.axisLabelPadding ?= 10
    params.yaxis?.axisLabelPadding ?= 10
    
    #xaxis: {min: 0, max: 1, axisLabel: "Orbit time (minutes)", axisLabelUseCanvas: true, axisLabelPadding: 10}
    #yaxis: {min: 9100, max: 9500, axisLabel: "Orbit radius (km)", axisLabelUseCanvas: true, axisLabelPadding: 10}
    
    #@axesLabels = new AxesLabels @plot, params
    #@axesLabels.position()
    
    #$.plot @plot, [numeric.transpose([x, y])], params
    #@axesLabels = new AxesLabels @plot, params
    #@axesLabels.position()
    


# Unused - replaced by flot plugin
class AxesLabels
  
  constructor: (@container, @params) ->
    @xaxisLabel = @appendLabel @params.xlabel, "xaxisLabel" if @params.xlabel
    @yaxisLabel = @appendLabel @params.ylabel, "yaxisLabel" if @params.ylabel
      
  appendLabel: (txt, className) ->
    label = $ "<div>", text: txt
    label.addClass "axisLabel"
    label.addClass className
    @container.append label
    label
  
  position: ->
    @xaxisLabel?.css
      marginLeft: (-@xaxisLabel.width() / 2 + 10) + "px"  # width of ylabels?
      marginBottom: "-20px"
      
    @yaxisLabel?.css
      marginLeft: "-27px"
      marginTop: (@yaxisLabel.width() / 2 - 10) + "px"


Widget.register [Input, Slider, Table, Plot]

