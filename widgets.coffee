#!vanilla

Widgets = $blab.Widgets

class Slider
  
  @handle: "slider"
  @api: "$blab.Widgets.Registry.Slider"
  
  @initVal: 5
  
  # id: "#{id}"
  
  @initSpec: (id) -> """
    min: 0, max: 10, step: 0.1, init: #{Slider.initVal}
    prompt: "#{id}:"
    text: (v) -> v
  """
  
  # ZZZ can be determined in Widgets?
  @layoutPreamble:
    "#{@handle} = (id, spec) -> new #{@api}(id, spec)"
    
  @computePreamble:
    "#{@handle} = (id) -> #{@api}.compute(id)"
  
  @compute: (id) ->
    Widgets.fetch(Slider, id)?.getVal() ? Slider.initVal
  
  constructor: (@p1, @p2) ->
    
    if typeof @p1 is "string"
      @id = @p1
      console.log "P1/P2", @p1, @p2
      @spec = @p2
      @spec.id = @id
    else
      @spec = @p1
      @id = @spec.id
      
    {@min, @max, @step, @init, @prompt, @text} = @spec
    
    @sliderContainer = $("#"+@id)
    if @sliderContainer.length
      @sliderContainer.slider?("destroy")
      @outer = @sliderContainer.parent()
      @outer?.remove()
    
    @outer = $ "<div>", class: "slider-container"
    @sliderPrompt = $ "<div>", class: "slider-prompt"
    @sliderPrompt.append @prompt
    @outer.append @sliderPrompt
    @sliderContainer = $ "<div>", class: "mvc-slider", id: @id
    @outer.append @sliderContainer
    @textDiv = $ "<div>", class: "slider-text"
    @outer.append(" ").append @textDiv
    
    Widgets.append @id, this, @outer  # not now: Superclass method
    
    @slider = @sliderContainer.slider
      #orientation: "vertical"
      range: "min"
      min: @min
      max: @max
      step: @step
      value: @init
      slide: (e, ui) =>
        @setVal(ui.value)
        Widgets.compute()  # Superclass method
      change: (e, ui) =>  # Unused because responds to slide method
      
    @setVal @init
    
  initialize: -> @setVal @init
    
  setVal: (v) ->
    @textDiv.html @text(v)
    @value = v
  
  getVal: -> @value


class Table
  
  @handle: "table"
  @api: "$blab.Widgets.Registry.Table"
  
  @initSpec: (id) -> """
    id: "#{id}"
    headings: ["Column 1", "Column 2"]
    widths: [100, 100]
    css: {margin: "0 auto"}
  """
  
  @layoutPreamble: "#{@handle} = (spec) -> new #{@api}(spec)"
  
  @computePreamble: "#{@handle} = (id, v...) ->\n  #{@api}.compute(id, v)\n  null"
  
  @compute: (id, v) ->
    Widgets.fetch(Table, id, v...)?.setVal(v)
  
  constructor: (@spec) ->
    
    {@id, @headings, @widths, @colCss, @css} = @spec
    
    @table = $("#"+@id)
    @table.remove() if @table.length
    @table = $ "<table>",
      id: @id
      class: "widget"
    
    if @css
      @table.css @css
    
    Widgets.append @id, this, @table
    
  initialize: -> #@setVal @init
    
  setVal: (v) ->
    @table.empty()
    
    colGroup = $ "<colgroup>"
    @table.append colGroup
    for w, idx in @widths
      css = @colCss?[idx] ? {}
      css.width = w
      col = $ "<col>", css: css # {width: w}
      colGroup.append col
    
    if @headings
      tr = $ "<tr>"
      @table.append tr
      for h, idx in @headings
        #w = @widths[idx]
        tr.append "<th>#{h}</th>"
#        tr.append "<th width='#{w}'>#{h}</th>"
    
    row = []
    for x, idx in v[0]
      tr = $ "<tr>"
      @table.append tr
      for i in [0...v.length]
        #w = @widths[i]
        d = v[i][idx]
        val = if typeof d is "number" then @format(d) else d
        tr.append "<td>"+val+"</td>"
#        tr.append "<td width='#{w}'>"+val+"</td>"
    @value = v
    
  format: (x) ->
    Math.round(x*10000)/10000


class Plot
  
  @handle: "plot"
  @api: "$blab.Widgets.Registry.Plot"
  
  @initSpec: (id) -> """
    id: "#{id}"
    width: 300, height: 200
    xlabel: "x", ylabel: "y"
    # xaxis: {min: 0, max: 1}
    # yaxis: {min: 0, max: 1}
    series: {lines: lineWidth: 1}
    colors: ["red", "blue"]
    grid: {backgroundColor: "white"}
  """
  
  @layoutPreamble: "#{@handle} = (spec) -> new #{@api}(spec)"
  
  @computePreamble: "#{@handle} = (id, v...) ->\n  #{@api}.compute(id, v)\n  null"
  
  @compute: (id, v) ->
    Widgets.fetch(Plot, id, v...)?.setVal(v)
  
  constructor: (@spec) ->
    
    {@id, @width, @height, @xlabel, @ylabel} = @spec
    
    @plot = $("#"+@id)
    @plot.remove() if @plot.length
    @plot = $ "<div>",
      id: @id
      css:
        width: @width ? 400
        height: @height ? 200
        
    Widgets.append @id, this, @plot
    
  initialize: -> #@setVal @init
    
  setVal: (v) ->
    @plot.empty()
    @value = v
    #@plot.text v
    
    params = @spec
    params.series.shadowSize ?= 0
    params.series ?= {color: "#55f"}
    
    params.xaxis ?= {}
    params.yaxis ?= {}
    
    params.xaxis?.axisLabel = params.xlabel if params.xlabel
    params.yaxis?.axisLabel = params.ylabel if params.ylabel
    params.xaxis?.axisLabelUseCanvas ?= true
    params.yaxis?.axisLabelUseCanvas ?= true
    params.xaxis?.axisLabelPadding ?= 10
    params.yaxis?.axisLabelPadding ?= 10
    
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
    
    $.plot @plot, d, params
    
    #xaxis: {min: 0, max: 1, axisLabel: "Orbit time (minutes)", axisLabelUseCanvas: true, axisLabelPadding: 10}
    #yaxis: {min: 9100, max: 9500, axisLabel: "Orbit radius (km)", axisLabelUseCanvas: true, axisLabelPadding: 10}
    
    #@axesLabels = new AxesLabels @plot, params
    #@axesLabels.position()
    
    #$.plot @plot, [numeric.transpose([x, y])], params
    #@axesLabels = new AxesLabels @plot, params
    #@axesLabels.position()

class Bar
  
  @handle: "bar"
  @api: "$blab.Widgets.Registry.Bar"
  
  @initSpec: (id) -> """
    id: "#{id}"
    width: 300, height: 200
    xlabel: "x", ylabel: "y"
    xaxis: {minTickSize: 1}
    # xaxis: {min: 0, max: 1}
    # yaxis: {min: 0, max: 1}
    series: {bars: {show: true}, stack:true}
    # colors: ["red", "blue"]
    grid: {backgroundColor: "white"}
  """
  
  @layoutPreamble: "#{@handle} = (spec) -> new #{@api}(spec)"
  
  @computePreamble: "#{@handle} = (id, v...) ->\n  #{@api}.compute(id, v)\n  null"
  
  @compute: (id, v) ->
    Widgets.fetch(Bar, id, v...)?.setVal(v)
  
  constructor: (@spec) ->
    
    {@id, @width, @height, @xlabel, @ylabel} = @spec
    
    @plot = $("#"+@id)
    @plot.remove() if @plot.length
    @plot = $ "<div>",
      id: @id
      css:
        width: @width ? 400
        height: @height ? 200
        
    Widgets.append @id, this, @plot
    
  initialize: -> #@setVal @init
    
  setVal: (v) ->
    @plot.empty()
    @value = v
    #@plot.text v
    
    params = @spec
    params.series.shadowSize ?= 0
    params.series ?= {color: "#55f"}
    
    params.xaxis ?= {}
    params.yaxis ?= {}
    
    params.xaxis?.axisLabel = params.xlabel if params.xlabel
    params.yaxis?.axisLabel = params.ylabel if params.ylabel
    params.xaxis?.axisLabelUseCanvas ?= true
    params.yaxis?.axisLabelUseCanvas ?= true
    params.xaxis?.axisLabelPadding ?= 10
    params.yaxis?.axisLabelPadding ?= 10
    
    lol = (u) -> # list of lists
        if u[0].length?
            z = u
        else
            z = []
            z.push u
        z

    X = lol v[0]
    Y = lol v[1]
    L = lol v[2]

    maxRows =  Math.max(X.length, Y.length)
    d = []
    for k in [0...maxRows]
        xRow = Math.min(k,X.length-1)
        yRow = Math.min(k,Y.length-1)
        lRow = Math.min(k,L.length-1)
        l = numeric.transpose([X[xRow], Y[yRow]])
        d.push {"data": l, "label":L[lRow]}

    $.plot @plot, d, params
    
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


Widgets.register [Slider, Table, Plot, Bar]

