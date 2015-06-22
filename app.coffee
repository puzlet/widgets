#!vanilla

# TODO:
# grunt
# show all layout code

# Hack to process only once - not needed?
return if $blab?.layoutProcessed
$blab.layoutProcessed = true

class Widgets
  
  @filename: "layout.coffee"  # should be layout.coffee
  
  @Registry: {}
  
  @register: (WidgetSet) ->
    @Registry[Widget.name] = Widget for Widget in WidgetSet
  
  @widgets: {}
  @count: 0
  
  @initialize: ->
    
    @Layout = Layout
    
    @widgetEditor ?= new WidgetEditor(@filename)
    
    $(document).on "preCompileCoffee", (evt, data) =>
      resource = data.resource
      url = resource.url
      console.log "preCompileCoffee", url 
      @count = 0  # ZZZ Bug?  only for foo.coffee or widgets.coffee
      return unless url is @filename
      @widgetEditor.init(resource)
      @Layout.render()
      @precode()
      @widgets = {}
    
    $(document).on "compiledCoffeeScript", (evt, data) =>
      return unless data.url is @filename
      widget?.initialize?() for key, widget in @widgets
      Computation.init()
      $.event.trigger "htmlOutputUpdated"
      
    @queueCompile 2000  # Hack to force compile for Gist source
      
  @append: (id, widget, element) ->
    @widgets[id] = widget
    @Layout.append element, widget
    
  @fetch: (Widget, id) ->
    idSpecified = id?
    unless idSpecified
      id = @count
      @count++
    w = @widgets[id]
    return w if w
    # Create new widget
    if idSpecified then @createFromId(Widget, id) else @createFromCounter(Widget, id)
    null  # Widget must set default val
    
  @createFromId: (Widget, id) ->
    resource = $blab.resources.find(@filename)
    name = Widget.handle
    spec = Widget.initSpec(id)
    s = spec.split("\n").join("\n  ")
    code = "#{name} \"#{id}\",\n  #{s}\n"
    # ZZZ TODO: this should be method of WidgetEditor.
    resource.containers.fileNodes[0].editor.set(resource.content + "\n" + code)
    @queueCompile()
  
  @createFromCounter: (Widget, id) ->
    spec = Widget.initSpec(id)
    make = -> new Widget id, eval(CoffeeScript.compile(spec, bare: true))
    setTimeout(make, 700)
  
  @queueCompile: (t=500) ->
    resource = $blab.resources.find(@filename)
    if @tCompile
      clearTimeout(@tCompile)
      @tCompile = null
    @tCompile = setTimeout (=> 
      resource.compile()
#  REINSTATE    @viewport()
    ), t
    
  @compute: -> Computation.compute()
  
  @precode: ->
    
    preamble = Layout.shortcuts + "\n"
    preamble += Widget.layoutPreamble+"\n" for n, Widget of @Registry
    
    precompile = {}
    precompile[@filename] =
      preamble: preamble
      postamble: ""
    
    $blab.precompile(precompile)


class WidgetEditor
  
  # TODO:
  # button to show whole layout file
  # move layout to eval area
  # layout fixed pos at bottom of browser window
  
  
  constructor: (@filename) ->
    
    @currentLine = null  # compute.coffee
    
    #$(document).on "preCompileCoffee", (evt, data) =>
    #  resource = data.resource
    #  @init(resource) if resource.url is @filename
    
    clickedOnWidget = false
    
    $(document).on "clickWidget", (evt, data) =>
      console.log "obs", data
      clickedOnWidget = true
      @setViewPort data.type + " " + "\"#{data.id}\""
      setTimeout (-> clickedOnWidget = false), 300
    
    $(document).on "computationCursorOnWidget", (evt, data) =>
      #console.log "comp cursor on widget", data
      clickedOnWidget = true
      @setViewPort data.match
      
    $(document.body).click (evt, data) =>
      console.log "click container", evt.target, evt, data
      setTimeout (=>
        unless clickedOnWidget or $(evt.target).attr("class") is "ace_content"
          console.log "NOT WIDGET"
          @setViewPort null
        clickedOnWidget = false
      ), 100
      
  init: (@resource) ->
    return if @editor
    @editor = @resource.containers?.fileNodes?[0].editor
    return unless @editor
    @aceEditor = @editor.editor
    #@initViewport()
    
    @setViewPort null
    
    # ZZZ init folding here?
    
    @editor.onChange =>
      
      console.log "edit #{@filename}"
      
      #ed.setViewPort()
      
  setViewPort: (txt) ->
    return unless @editor
    
    start = null
    
    spec = @editor.spec
    
    if txt
      code = @editor.code()
      lines = code.split "\n"
      for line, idx in lines
        if line.indexOf(txt) isnt -1
          start = idx
        if start? and line is ""
          end = idx
          break
    
    if start is null
      @editor.spec.viewPort = false
      @editor.setHeight()
      @editor.show false
      @editor.container.parent().hide()
      return
      start = 1
      end = 1
    
    @editor.container.parent().show()
    @editor.show true if start
    spec.viewPort = true
    spec.startLine = start+1
    spec.endLine = end+1
    @editor.setViewPort()
    @editor.editorContainer[0].onwheel = -> false
      
  folding: ->
    # ZZZ to do
    resource = $blab.resources.find(@filename)
    ed = resource.containers?.fileNodes?[0].editor
    return unless ed
    
    #ed.show false
    return
    
    editor = ed.editor
    editor.setShowFoldWidgets true
    session = editor.getSession()
    session.on "changeFold", ->
      console.log "fold"
      ed.setHeight session.getScreenLength()
    session.foldAll(1, 10000, 0)
    


class Computation
  
  @filename: "compute.coffee"
  
  @init: ->
    p = @precode()
    #console.log "@@@@@@@@@PRECODE", p
    @compute() #if @precode()
    
  @compute: ->
    resource = $blab.resources.find(@filename)
    resource?.compile()
    
  @precode: ->
    
    preamble = ""
    preamble += Widget.computePreamble+"\n" for WidgetName, Widget of Widgets.Registry
    
    preDefine = $blab.resources.find("predefine.coffee")
    #console.log "******* predefine", preDefine
    #return null unless preDefine
    #console.log "predef", preDefine?.content
    preamble += preDefine?.content+"\n" if preDefine
    #console.log "********* preamble", preamble
    
    precompile = {}
    precompile[@filename] =
      preamble: preamble
      postamble: ""
    
    $blab.precompile(precompile)
    true

$(document).on "preCompileCoffee", (evt, data) =>
  resource = data.resource
  url = resource.url
  #console.log "@@@@@@@ PRECOMPILE", url
  if url is "compute.coffee"
    Computation.precode()


class ComputationEditor
  
  filename: "compute.coffee"
  
  code:
    slider: "x = slider \"x\""
    plot: "plot \"my-plot\", x, y"
    table: "table \"my-table\", x, y"
  
  constructor: ->
    
    @currentLine = null
    
    $(document).on "preCompileCoffee", (evt, data) =>
      resource = data.resource
      url = resource?.url
      @init(resource) if url is @filename
      
    $(document).on "compiledCoffeeScript", (evt, data) =>
      #return unless data.url is @filename
      @currentLine = null
      @setLine() if data.url is @filename
      
    $(document).on "clickComputationButton", (evt, data) =>
      #console.log "button", data, @selection.getCursor()
      @aceEditor.focus()
      @aceEditor.insert @code[data.button]+"\n"
      
  init: (@resource) ->
    
    return if @editor  # Return if already defined
    # ZZZ but what about current line - e.g., if widget view changed some other way.
    
    @editor = @resource?.containers?.fileNodes?[0].editor
    
    return unless @editor
    @aceEditor = @editor.editor
    
    @currentLine = null
    @selection = @aceEditor.selection
    
    @selection.on "changeCursor", => @setLine()
      #cursor = @selection.getCursor()
      #line = cursor.row
      #if line isnt @currentLine
      #  @setLine(line)
    #  cursor = selection.getCursor()
    #  if cursor.row isnt @currentLine
    #    @currentLine = cursor.row
    #    @inspectLineForWidget()
        
    #@setLine()
    #@inspectLineForWidget()
    
  setLine: =>
    cursor = @selection.getCursor()
    if cursor.row isnt @currentLine
      @currentLine = cursor.row
      @inspectLineForWidget()
  
  inspectLineForWidget: ->
    code = @editor.code()
    lines = code.split "\n"
    line = lines[@currentLine]  # ZZZ easier way?  pass current line - ace method?
    widgetRegex = /(slider|table|plot|bar) "([^"]*)"/
    matchArray = widgetRegex.exec(line)
    match = if matchArray is null then null else matchArray[0]
    $.event.trigger "computationCursorOnWidget", {match}
    


class ComputationButtons
  
  constructor: ->
    console.log "***** Buttons"
    @container = $ "#computation-buttons"
    @create "slider"
    @create "table"
    @create "plot"
    
    run = $ "<div>",
      css: {display: "inline-block", marginLeft: "10px", color: "#aaa", fontSize: "10pt"}
      text: "Click shift-return to run"
    @container.append run
    #b = $ "<button>", text: "button"
    #@container.append b
    #b.click -> console.log "click!"
    #b.button().click(-> console.log "click")
    
    #<button>A button element</button>
  
  create: (txt) ->
    b = $ "<button>", text: txt
    @container.append b
    b.click ->
      $.event.trigger "clickComputationButton", {button: txt}
    


class TextEditor
  
  containerId: "#main-text"
  filename: "text.html"
  wikyUrl: "/puzlet/puzlet/js/wiky.js"
  posAttr: "data-pos"
  widgetsId: "#widgets"
  
  constructor: ->
    
    @text = $ @containerId
    return unless @text.length
    @text.css(cursor: "default")  # ZZZ do in CSS
    @text.click => @toggle()
    
    @resources = $blab.resources
    
    onEvt = (evt, f) -> $(document).on(evt, -> f())
    
    onEvt "aceFilesLoaded", =>
      if Wiky? then @process() else @loadWiky => @init()
    
    onEvt "renderedWidgets", => @process()
    
  loadWiky: (callback) ->
    @resources.add {url: @wikyUrl}
    @resources.loadUnloaded -> callback?()
    
  init: ->
    @resource = @resources.find(@filename)
    @editor = @resource?.containers?.fileNodes?[0].editor
    return unless @editor
    @editor.onChange => @render()
    @editor.show false
    
  render: ->
    @renderId ?= null
    clearTimeout(@renderId) if @renderId
    @renderId = setTimeout (=>
      #@resource.content = 
      @process()
    ), 500
    
  process: ->
    return unless Wiky?
    #console.log "html content", @resource.content
    @text.empty()
    @text.append Wiky.toHtml(@resource.content)
    @positionText()
    $.event.trigger "htmlOutputUpdated"
    
  positionText: ->
    
    sel = "div[#{@posAttr}]"
    widgets = $(@widgetsId)
    current = widgets.find sel
    current.remove()
    
    divs = @text.find sel
    return unless divs.length
    
    append = => $($(p).attr @posAttr).append($(p)) for p in divs
    
    if widgets.length  # Alt: if $("#row1").length
      append()
    else
      # ZZZ needs to trigger after widget rendering
      setTimeout (-> append()), 1000
      
  toggle: ->
    return unless @editor
    @editorShown ?= false  # ZZZ get from editor show state?
    @editor.show(not @editorShown)
    @editorShown = not @editorShown


class Layout
  
  @shortcuts: """
    layout = (spec) -> $blab.Widgets.Layout.set(spec)
    pos = (spec) -> $blab.Widgets.Layout.pos(spec)
    text = (spec) -> $blab.Widgets.Layout.text(spec)
  """
  
  @spec: {}
  @currentContainer: null
  
  @set: (@spec) ->
  
  @pos: (@currentContainer) ->
    
  @render: ->
    widgets = $("#widgets")
    widgets.empty()
    for label, row of @spec
      r = $ "<div>", id: label
      widgets.append r
      for col in row
        c = $ "<div>", class: col
        r.append c
        for d in [1..5]
          o = $ "<div>", class: "order-#{d}"
          c.append o
      r.append($ "<div>", class: "clear")
    $.event.trigger "renderedWidgets"
        
  @append: (element, widget) ->
    if widget?.spec.pos?
      container = $(widget.spec.pos)
      order = widget.spec.order
      container = $(container).find(".order-"+order) if order?
    else
      container = $(@currentContainer)
    container.append element
  
  @text: (t) -> @append t


codeSections = ->
  title = "Show/hide code"
  comp = $ "#computation-code-section"
  layout = $ "#layout-code-section"
  predef = $ ".predefined-code"
  predef.hide()
  
  $("#computation-code-heading")
    #.attr(title: title)
    .click -> comp.toggle(500)
  
  $("#layout-code-heading")
    #.attr(title: title)
    .click -> layout.toggle(500)
  
  ps = true
  toggleHeading = ->
    ps = not ps
    $("#predefined-code-heading").html (if ps then "[Hide" else "[Show")+" predefined code]"
  toggleHeading()
  
  $("#predefined-code-heading")
    .click ->
      predef.toggle(500)
      toggleHeading()
      
      
  #comp.hide()
  #layout.hide()

codeSections()

Widgets.initialize()

new ComputationEditor
new ComputationButtons

textEditor = new TextEditor
$pz.renderHtml = -> textEditor.process()

# Export
$blab.Widgets = Widgets 

