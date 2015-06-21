#!vanilla

processHtml = ->
  #console.log "******** PROC HTML", $blab.resources
  for resource in $blab.resources.select("html")
    #console.log "**** HTML", resource, resource.content
    main = $ "#main-text"
    main.empty()
    main.append Wiky.toHtml(resource.content)
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
  
  @viewport: ->
  
  @initialize: ->
    
    @Layout = Layout
    
    testFolding = =>
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
    
    setViewPort = (txt) =>
      resource = $blab.resources.find(@filename)
      ed = resource.containers?.fileNodes?[0].editor
      return unless ed
      code = ed.code()
      #console.log "***code", code
      lines = code.split "\n"
      start = null
      #ed.show true
      if txt
        ed.show true
        for line, idx in lines
          if line.indexOf(txt) isnt -1
            start = idx
          if start? and line is ""
            end = idx
            break
      else
        ed.show false
        start = 1
        end = 1
      if start is null
        ed.show false
        start = 1
        end = 1
      console.log "start/end", start, end
      ed.spec.viewPort = true
      ed.spec.startLine = start+1
      ed.spec.endLine = end+1
      ed.setViewPort()
      editor = ed.editor
      #editor.setOption({minLines: 4, maxLines: 4})
      #editor.$blockScrolling = Infinity
      #editor.onwheel = preventDefault
      ed.editorContainer[0].onwheel = -> false
    
    
    currentLine = null
    
    dovp = =>
      
      #console.log "****** DO VIEWPORT"
      
      compute = $blab.resources.find("compute.coffee")
      comp = compute?.containers?.fileNodes?[0].editor
      return unless comp
      compEditor = comp.editor
      
      sel = compEditor.selection
      
      cursor = compEditor.selection.getCursor()
      if cursor.row isnt currentLine
        currentLine = cursor.row
        code = comp.code()
        lines = code.split "\n"
        line = lines[currentLine]  # ZZZ easier way?
        console.log "Current line", currentLine, line
        
        myregex = /(slider|table|plot|bar) "([^"]*)"/
        console.log "REGEX"
        matchArray = myregex.exec(line)
        if (matchArray isnt null)
            thematch = matchArray[1]
            console.log "**** thematch", matchArray, thematch
            setViewPort matchArray[0]
        else
          setViewPort()
      
    
    testViewPort = =>
      
      compute = $blab.resources.find("compute.coffee")
      comp = compute?.containers?.fileNodes?[0].editor
      if comp
        compEditor = comp.editor
        sel = compEditor.selection
        currentLine = null
        sel.on "changeCursor", -> dovp()
          
          # cursor = compEditor.selection.getCursor()
          # if cursor.row isnt currentLine
          #   currentLine = cursor.row
          #   code = comp.code()
          #   lines = code.split "\n"
          #   line = lines[currentLine]  # ZZZ easier way?
          #   console.log "Current line", currentLine, line
          #
          #   myregex = /(slider|table|plot|bar) "([^"]*)"/
          #   console.log "REGEX"
          #   matchArray = myregex.exec(line)
          #   if (matchArray isnt null)
          #       thematch = matchArray[1]
          #       console.log "**** thematch", matchArray, thematch
          #       setViewPort matchArray[0]
          #   else
          #     setViewPort()
          #   return
          #
          #
          #   found = line.indexOf "table-orbit-phobos"
          #   if found isnt -1
          #     #console.log "MATCH", found
          #     setViewPort "table \"table-orbit-phobos"
          #     return
          #   found = line.indexOf "radius"
          #   if found isnt -1
          #     #console.log "MATCH", found
          #     setViewPort "slider \"radius"
          #     return
          #   setViewPort()
      
      resource = $blab.resources.find(@filename)
      ed = resource.containers?.fileNodes?[0].editor
      return unless ed
      
      
      return 
      #ed.hide()
      
      #return
      
      code = ed.code()
      #console.log "***code", code
      lines = code.split "\n"
      start = null
      for line, idx in lines
        if line.indexOf("table \"table-orbit-phobos\"") isnt -1
          start = idx
        if start? and line is ""
          end = idx
          break
      ed.spec.viewPort = true
      ed.spec.startLine = 1 #start+1
      ed.spec.endLine = 4 #end+1
      ed.setViewPort()
      
    testEdit = =>
      resource = $blab.resources.find(@filename)
      ed = resource.containers?.fileNodes?[0].editor
      return unless ed
      editor = ed.editor
      ed.onChange =>
        console.log "CHANGE!!!!!!!!"
        #ed.setViewPort()
      
    @viewport = -> dovp()
    
    first = true
    
    $(document).on "preCompileCoffee", (evt, data) =>
      url = data.resource.url
      console.log "preCompileCoffee", url 
      @count = 0  # ZZZ Bug?  only for foo.coffee or widgets.coffee
      return unless url is @filename
      if first
        console.log "TEST FOLD/VIEW"
        testFolding()
        testEdit()
        testViewPort()
        #first = false
      @Layout.render()
      @precode()
      @widgets = {}
    
    $(document).on "compiledCoffeeScript", (evt, data) =>
      return unless data.url is @filename
      widget?.initialize?() for key, widget in @widgets
      Computation.init()
      $.event.trigger "htmlOutputUpdated"
      
    $(document).on "clickWidget", (evt, data) =>
      console.log "obs", data
      setViewPort data.type + " " + "\"#{data.id}\""
      
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
      @viewport()
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

Widgets.initialize()

# Export
$blab.Widgets = Widgets 

