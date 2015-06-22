#!vanilla

# TODO:
# grunt

# Hack to process only once - not needed?
return if $blab?.layoutProcessed
$blab.layoutProcessed = true
console.log "============ LAYOUT"

processHtml = ->
  #console.log "******** PROC HTML", $blab.resources
  for resource in $blab.resources.select("html")
    #console.log "**** HTML", resource, resource.content
    
    old = $("#widgets").find "div[data-pos]"
    old.remove()
    
    main = $ "#main-text"
    main.empty()
    main.append Wiky.toHtml(resource.content)
    
    pos = main.find "div[data-pos]"
    
    #console.log "ROW", $("#row3")
    console.log "POS", pos
    if pos.length
      if $("#row1").length
        for p in pos
          $($(p).attr "data-pos").append $(p)
      else
        setTimeout (->  # ZZZ needs to trigger after widget rendering
          #console.log "pos", $(pos[0]), pos.html()
          for p in pos
            $($(p).attr "data-pos").append $(p)
        ), 1000
      #.appendTo 
    
    
    $.event.trigger "htmlOutputUpdated"
    #console.log Wiky

    #@render html.content for html in @resources.select("html")  # TODO: callback for HTMLResource?

$pz.renderHtml = ->
  console.log "$$$$$$$$ RENDER HTML"
  #@page.rerender()
  processHtml()


$(document).on "aceFilesLoaded", ->
  if Wiky?
    processHtml()
  else
    resources = $blab.resources
    resources.add {url: "/puzlet/puzlet/js/wiky.js"}
    resources.loadUnloaded =>
      console.log "***WIKY loaded", Wiky
      #setTimeout (-> console.log "******** wiky loaded", Wiky), 2000
      
      processHtml()
      
      renderId = null
      
      resource = $blab.resources.select("html")
      ed = resource[0].containers.fileNodes[0].editor
      ed.onChange =>
        console.log "CHANGE"
        clearTimeout(renderId) if renderId
        renderId = setTimeout (-> processHtml()), 500
      
      ed.show false
      
      shown = false
      $("#main-text").css cursor: "default"
      
      $("#main-text").click ->
        console.log "click text"
        resource[0].containers.fileNodes[0].editor.show(not shown)
        shown = not shown

#$blab?.resources?.on "ready", -> processHtml()

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
      
    $(document).on "clickWidget", (evt, data) =>
      console.log "obs", data
      @setViewPort data.type + " " + "\"#{data.id}\""
      
    $(document).on "computationCursorOnWidget", (evt, data) =>
      console.log "comp cursor on widget", data
      @setViewPort data.match
      
    $(document.body).click (evt, data) =>
      console.log "click container", evt.target, evt, data
      
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
    code = @editor.code()
    lines = code.split "\n"
    start = null
    
    spec = @editor.spec
    
    if txt
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
    @precode()
    @compute()
    
  @compute: ->
    resource = $blab.resources.find(@filename)
    resource?.compile()
    
  @precode: ->
    
    preamble = ""
    preamble += Widget.computePreamble+"\n" for WidgetName, Widget of Widgets.Registry
    
    precompile = {}
    precompile[@filename] =
      preamble: preamble
      postamble: ""
    
    $blab.precompile(precompile)


class ComputationEditor
  
  @filename: "compute.coffee"
  
  constructor: ->
    
    @currentLine = null
    
    $(document).on "preCompileCoffee", (evt, data) =>
      @init(data.resource) if data.url is @filename
      
  init: (@resource) ->
    
    return if @editor  # Return if already defined
    # ZZZ but what about current line - e.g., if widget view changed some other way.
    
    @editor = @resource?.containers?.fileNodes?[0].editor
    
    return unless @editor
    @aceEditor = @editor.editor
    
    @currentLine = null
    
    selection = @aceEditor.selection
    selection.on "changeCursor", =>
      cursor = selection.getCursor()
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
  
  $("#computation-code-heading")
    #.attr(title: title)
    .click -> comp.toggle(500)
  
  $("#layout-code-heading")
    #.attr(title: title)
    .click -> layout.toggle(500)
      
  #comp.hide()
  #layout.hide()

codeSections()

console.log "@@@@@@@@@ widgets init"
Widgets.initialize()
new ComputationEditor

# Export
$blab.Widgets = Widgets 

