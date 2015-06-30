#!vanilla

# Hack to process only once - not needed?
return if $blab?.layoutProcessed
$blab.layoutProcessed = true

class Widget
  
  @layoutPreamble:
    "#{@handle} = (id, spec) -> new #{@api}(id, spec)"
    
  @computePreamble:
    "#{@handle} = (id) -> #{@api}.compute(id)"
    
  constructor: (@p1, @p2) ->
    
    @used = false
    
    if typeof @p1 is "string"
      @id = @p1
      @spec = @p2
      @spec.id = @id
    else
      @spec = @p1
      @id = @spec.id
      
  setUsed: (used=true) ->
    return if used is @used
    @mainContainer.css(opacity: (if used then 1 else 0.2))
    @used = used


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
    
  @fetch: (Widget, id, v...) ->
    idSpecified = id?
    unless idSpecified
      id = @count
      @count++
    w = @widgets[id]
    return w if w
    # Create new widget
    if idSpecified then @createFromId(Widget, id, v...) else @createFromCounter(Widget, id, v...)
    null  # Widget must set default val
    
  @createFromId: (Widget, id, v...) ->
    resource = $blab.resources.find(@filename)
    name = Widget.handle
    spec = Widget.initSpec(id, v)
    s = spec.split("\n").join("\n  ")
    code = "#{name} \"#{id}\",\n  #{s}\n"
    # ZZZ TODO: this should be method of WidgetEditor.
    resource.containers.fileNodes[0].editor.set(resource.content + "\n" + code)
    @queueCompile()
  
  @createFromCounter: (Widget, id, v...) ->
    spec = Widget.initSpec(id, v)
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
    
    @firstDisplay = true
    @currentLine = null  # compute.coffee
    @viewPortDisplayed = false
    
    @observers =
      setViewPort: []
      clickDelete: []
      
  init: (@resource) ->
    return if @editor
    @editor = @resource.containers?.fileNodes?[0].editor
    return unless @editor
    @aceEditor = @editor.editor
    @setViewPort null
    # ZZZ init folding here?
    @editor.onChange => 
      
  setViewPort: (txt) ->
    
    return unless @editor
    
    @viewPortDisplayed = txt isnt null # ZZZ temp: global
    @trigger "setViewPort"
    
    if @firstDisplay
      container = @editor.container
      container.removeClass "init-editor"
      container.css maxHeight: "10px"
      container.parent().show()
      @editor.show true
      setTimeout (=> @vp txt), 500
      @firstDisplay = false
    else
      @vp txt
  
  vp: (txt) ->
    
    @editor.container.css
      maxHeight: ""
      border: "3px solid #aaf"
    
    @start = null
    
    spec = @editor.spec
    
    if txt
      code = @editor.code()
      lines = code.split "\n"
      for line, idx in lines
        if line.indexOf(txt) isnt -1
          @start = idx
        if @start? and line is ""
          @end = idx
          break
    
    if @start is null
      @editor.spec.viewPort = false
      @editor.setHeight()
      @editor.show false
      @editor.container.parent().hide()
      return
      @start = 1
      @end = 1
    
    @editor.container.parent().show()
    @deleteButton()
    
    @editor.show true if @start
    spec.viewPort = true
    spec.startLine = @start+1
    spec.endLine = @end+1
    @editor.setViewPort()
    @editor.editorContainer[0].onwheel = -> false
    
  deleteButton: ->
    
    @del?.empty()
    
    return unless @currentId
    widget = Widgets.widgets[@currentId]  # ZZZ make method
    return if widget.used
    
    unless @del?.length
      @del = $ "<div>",
        css:
          position: "absolute"
          display: "inline-block"
          top: 5
          right: 15
      @editor.editorContainer.append @del
      
    @delButton = $ "<span>",
      text: "Delete"
      css: cursor: "pointer"
      click: =>
        selection = @aceEditor.selection
        return unless @start and @end
        selection.moveCursorTo(@start-1, 0)
        selection.selectTo(@end, 0)
        @aceEditor.removeLines()
        @editor.run()
        @editor.container.parent().hide()
        @trigger "clickDelete"
      
    @del.append @delButton
      
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
      ed.setHeight session.getScreenLength()
    session.foldAll(1, 10000, 0)
    
  on: (evt, observer) -> @observers[evt].push observer
  
  trigger: (evt, data) -> observer(data) for observer in @observers[evt]


class Computation
  
  @filename: "compute.coffee"
  
  @init: ->
    p = @precode()
    @compute()
    
  @compute: ->
    resource = $blab.resources.find(@filename)
    resource?.compile()
    
  @precode: ->
    
    preamble = ""
    preamble += Widget.computePreamble+"\n" for WidgetName, Widget of Widgets.Registry
    
    preDefine = $blab.resources.find("predefine.coffee")
    preamble += preDefine?.content+"\n" if preDefine
    
    precompile = {}
    precompile[@filename] =
      preamble: preamble
      postamble: ""
    
    $blab.precompile(precompile)
    true
    


class ComputationEditor
  
  filename: "compute.coffee"
  
  code:
    slider: "x = slider \"x\""
    plot: "plot \"my-plot\", x, y"
    table: "table \"my-table\", x, y"
  
  constructor: ->
    
    @currentLine = null
    
    @observers =
      cursorOnWidget: []
    
    $(document).on "preCompileCoffee", (evt, data) =>
      resource = data.resource
      url = resource?.url
      @init(resource) if url is @filename
      
    $(document).on "compiledCoffeeScript", (evt, data) =>
      return unless data.url is @filename
      #@currentLine = null
      @setLine() if data.url is @filename
      
    # No longer used
    $(document).on "clickComputationButton", (evt, data) =>
      @aceEditor.focus()
      @aceEditor.insert @code[data.button]+"\n"
      
    $(document).on "runCode", (evt, data) =>
      return unless data.filename is @filename
      @currentLine = null
      @setLine()
      
  init: (@resource) ->
    
    return if @editor  # Return if already defined
    # ZZZ but what about current line - e.g., if widget view changed some other way.
    
    @editor = @resource?.containers?.fileNodes?[0].editor
    
    return unless @editor
    @aceEditor = @editor.editor
    
    @currentLine = null
    @selection = @aceEditor.selection
    
    @selection.on "changeCursor", => @setLine()
    
    @aceEditor.on "focus", =>
      @currentLine = null
      @setLine()
    
  setLine: =>
    cursor = @selection?.getCursor()
    if cursor?.row isnt @currentLine
      @currentLine = cursor.row
      @inspectLineForWidget()
  
  inspectLineForWidget: ->
    code = @editor.code()
    lines = code.split "\n"
    line = lines[@currentLine]  # ZZZ easier way?  pass current line - ace method?
    widgetRegex = /(slider|table|plot|bar) "([^"]*)"/
    matchArray = widgetRegex.exec(line)
    match = if matchArray is null then null else matchArray[0]
    @trigger "cursorOnWidget", {match}
    
  on: (evt, observer) -> @observers[evt].push observer
  
  trigger: (evt, data) -> observer(data) for observer in @observers[evt]
    


class ComputationButtons
  
  constructor: ->
    @container = $ "#computation-buttons"
    
    run = $ "<div>",
      css: {display: "inline-block", color: "#aaa", fontSize: "10pt"}
      text: "Click shift-enter to run"
    @container.append run
  
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
    @widgetsRendered = false
      
  setWidgetsRendered: ->
    @widgetsRendered = true
    @process() if Wiky?
  
  loadWiky: (callback) ->
    console.log "TextEditor::loadWiky"
    @resources.add {url: @wikyUrl}
    @resources.loadUnloaded -> callback?()
    
  init: ->
    console.log "TextEditor::init"
    @resource = @resources.find(@filename)
    @editor = @resource?.containers?.fileNodes?[0].editor
    return unless @editor
    @editor.container.removeClass "init-editor"
    @editor.onChange => @render()
    @editor.show false
    @process() if @widgetsRendered
    
  render: ->
    @renderId ?= null
    clearTimeout(@renderId) if @renderId
    @renderId = setTimeout (=>
      #@resource.content = 
      @process()
    ), 500
    
  process: ->
    console.log "TextEditor::process"
    unless Wiky?
      @loadWiky => @init()
      return
    #return unless Wiky?
    console.log "TextEditor::process/Wiky"
    @text.empty()
    html = Wiky.toHtml(@resource.content)
    return if html is ""
    @text.append html
    @setTitle()
    @positionText()
    $.event.trigger "htmlOutputUpdated"
    
  setTitle: ->
    headings = $ ":header"
    return unless headings.length
    $blab.title = headings[0].innerHTML
    document.title = $blab.title
    
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


class MarkdownEditor
  
  containerId: "#main-markdown"
  filename: "text.md"
  markedUrl: "/puzlet/puzlet/js/marked.min.js"
  posAttr: "data-pos"
  widgetsId: "#widgets"
  
  constructor: ->
    
    @text = $ @containerId
    return unless @text.length
    @text.css(cursor: "default")  # ZZZ do in CSS
    # ZZZ do below?
    @text.click => @trigger "clickText", {start: 0}
    
    @resources = $blab.resources
    @widgetsRendered = false
    @processDeferred = false
    
    @firstDisplay = true
    @viewPortDisplayed = false
    
    @observers =
      setViewPort: []
      clickText: []
    
  setWidgetsRendered: ->
    @widgetsRendered = true
    @process() if marked?
    
  loadMarked: (callback) ->
    console.log "MarkdownEditor::loadMarked"
    @resources.add {url: @markedUrl}
    @resources.loadUnloaded -> callback?()
  
  init: ->
    console.log "MarkdownEditor::init"
    
    marked.setOptions
      renderer: new marked.Renderer
      gfm: true
      tables: true
      breaks: false
      pedantic: false
      sanitize: true
      smartLists: true
      smartypants: false
    
    @resource = @resources.find(@filename)
    @editor = @resource?.containers?.fileNodes?[0].editor
    return unless @editor
    @editor.container.removeClass "init-editor"
    @editor.onChange => @render()
    @editor.show false
    
    @aceEditor = @editor.editor
    
    #@editor.container.css
    #  maxHeight: ""
    #  border: "3px solid #aaf"
      
    @setViewPort null
      
    #@editor.container.parent().hide()
    
    if @widgetsRendered
      @process()
    else
      @processDeferred = true
      
  setViewPort: (start) ->
    
    return unless @editor
    
    @viewPortDisplayed = start isnt null and start isnt false # ZZZ temp: global
    @trigger "setViewPort"
    
    if @firstDisplay
      container = @editor.container
      container.removeClass "init-editor"  # Done above?
      container.css maxHeight: "10px"
      container.parent().show()
      @editor.show true
      setTimeout (=> @vp start), 500
      @firstDisplay = false
    else
      @vp start
  
  vp: (start) ->
    
    console.log "START", start
    
    @editor.container.css
      maxHeight: ""
      border: "3px solid #aaf"
    
    @start = start
    
    spec = @editor.spec
    
    if @start is null or @start is false
      console.log "RESET VIEWPORT"
      @editor.spec.viewPort = true
      @editor.spec.startLine = 1
      @editor.spec.endLine = 15
      @editor.setViewPort()
      #@editor.setHeight(20)
      @editor.show false
      
      @editor.container.parent().hide()
      return
      #@start = 1
      #@end = 1
      
    #if @start is 0
    #  @start = 0
      #@end = 14
      #@end = 19
      
    if @start>0
      
      code = @editor.code()
      lines = code.split "\n"
      l = 0
      for line, idx in lines
        #console.log "L", line.length
        l += line.length + 1
        #console.log "l/s", l, start
        break if l>start
      #console.log "idx", idx
      @start = idx-1
        #if line.indexOf(txt) isnt -1
        #  @start = idx
        #if @start? and line is ""
        #  @end = idx
        #  break
      
      #@start = 15
      #@end = 14+14
      
    @end = @start+14
    
    @editor.container.parent().show()
    #@deleteButton()
    
    console.log "start/end", @start, @end
    if @start isnt null and @start isnt false
      @editor.show true
      spec.viewPort = true
      spec.startLine = @start+1
      spec.endLine = @end+1
      console.log "viewport", spec
      @editor.setViewPort()
      #@editor.setHeight(20)
      
#    spec.viewPort = false
#    spec.viewPort = true
#    spec.startLine = @start+1
#    spec.endLine = @end+1
#    @editor.setViewPort()
#    @editor.setHeight(20)
    #@editor.editorContainer[0].onwheel = (evt) -> 
      #evt.preventDefault()
      #false
  
  render: ->
    @renderId ?= null
    clearTimeout(@renderId) if @renderId
    @renderId = setTimeout (=>
      #@resource.content = 
      @process()
    ), 500
  
  process: ->
    console.log "MarkdownEditor::process"
    unless marked?
      @loadMarked => @init()
      return
    #return unless marked?
    console.log "MarkdownEditor::process/marked"
    @text.empty()
    $(".rendered-markdown").remove()
    
    md = @snippets @resource.content
    
    # ZZZ needs to happen after widget rendering
    
    out = []
    for m in md
      if m.pos is 0
        @text.append m.html
        out.push m.html
      else
        c = $ "<div>",
          class: "rendered-markdown"
          css: cursor: "default"
          click: => @trigger "clickText", {start: parseInt(c.attr "data-start")}
        console.log "m", m
        c.attr("data-pos": m.pos, "data-order": m.order, "data-start": m.start)
        c.append m.html
        container = Layout.getContainer(m.pos, m.order)
        #console.log "*** container", container
        container.append c
    out.join "\n"
    @setTitle out
    $.event.trigger "htmlOutputUpdated"
    @trigger "setViewPort"
    #$.event.trigger "changeViewPort"  # ZZZ hack
  
  setTitle: ->
    headings = $ ":header"
    return unless headings.length
    $blab.title = headings[0].innerHTML
    document.title = $blab.title
  
  # Unused.
  toggle: ->
    return unless @editor
    @editorShown ?= false  # ZZZ get from editor show state?
    #@editor.show(not @editorShown)
    @editorShown = not @editorShown
    @setViewPort(@editorShown)
  
  snippets: (file) ->
    
    @RE ?= ///
      ^\s*`\s*                   # begin-line, space and quote
      (?:p|pos)\s*:\s*           # p: or pos:
      (\d+)\s*,?\s*              # digits and comma (optional)
      (?:                        # optional
          (?:o|ord|order)\s*:\s*   # o:, ord: or order:
          (\d+)\s*                 # digits
      )?                         # end optional
      .*`.*$                     # end quote, comment, end-line
    ///mg                      # multiline & global
    
    md = []
    
    # ZZZ method?
    snippet = (found) ->
      start  = found.start ? 0
      source = file[start..found.end]
      start: start
      pos: parseInt(found.pos ? 0)
      order: parseInt(found.order) ? 1
      source: source
      html: marked source
      
    # search file for "found" regex
    found = {}
    
    while (match = @RE.exec(file)) isnt null
      
      # snippet above match
      found.end = match.index-1
      md.push snippet(found)
    
      # snippet below match
      found =
        start: match.index+match[0].length+1
        pos: match[1]
        order: match[2]
          
    # complete snippet below last match
    found.end = -1
    md.push snippet(found)
    md
    
  on: (evt, observer) -> @observers[evt].push observer
  
  trigger: (evt, data) -> observer(data) for observer in @observers[evt]
    


class Layout
  
  @shortcuts: """
    layout = (spec) -> $blab.Widgets.Layout.set(spec)
    pos = (spec) -> $blab.Widgets.Layout.pos(spec)
    text = (spec) -> $blab.Widgets.Layout.text(spec)
  """
  
  @spec: {}
  @currentContainer: null
  
  @observers:
    renderedWidgets: []
  
  @set: (@spec) ->
  
  @pos: (@currentContainer) ->
    
  @render: ->
    return unless Object.keys(@spec).length
    n = 1
    widgets = $("#widgets")
    widgets.empty()
    for label, row of @spec
      r = $ "<div>", id: label
      widgets.append r
      for col in row
        c = $ "<div>", class: col
        c.addClass "layout-box"
        @appendNum c, n
        n++
        r.append c
        for d in [1..5]
          o = $ "<div>", class: "order-#{d}"
          c.append o
      r.append($ "<div>", class: "clear")
    @highlight() if WidgetEditor.viewPortDisplayed or MarkdownEditor.viewPortDisplayed  # ZZZ temp
    @trigger "renderedWidgets"
    #$.event.trigger "renderedWidgets"
  
  @appendNum: (c, n) ->
    num = $ "<div>",
      text: n
      class: "layout-box-number"
    c.append num
    num.hide()
    
  @highlight: (highlight=true) ->
    if highlight
      $(".layout-box").addClass "layout-highlight"
      $(".layout-box-number").show()
    else
      $(".layout-box").removeClass "layout-highlight"
      $(".layout-box-number").hide()
        
  @append: (element, widget) ->
    if widget?.spec.pos?
      container = @getContainer widget.spec.pos, widget.spec.order
    else
      container = $(@currentContainer)
    container.append element
    
  @getContainer: (pos, order) ->
    if Number.isInteger(pos)
      # ZZZ temporary
      row = Math.round(pos/2)
      col = if pos % 2 then "left" else "right"
      position = "#row#{row} .#{col}"
    else
      position = pos
    container = $(position)
    container = $(container).find(".order-"+order) if order?
    container
  
  @text: (t) -> @append t
  
  @on: (evt, observer) -> @observers[evt].push observer
  
  @trigger: (evt, data) -> observer(data) for observer in @observers[evt]
  


codeSections = ->
  title = "Show/hide code"
  comp = $ "#computation-code-section"
  layout = $ "#layout-code-section"
  predef = $ ".predefined-code"
  
  predef.hide()
  
  $("#computation-code-heading")
    .click -> comp.toggle(500)
  
  $("#layout-code-heading")
    .click -> layout.toggle(500)
  
  ps = true
  toggleHeading = ->
    ps = not ps
    $("#predefined-code-heading").html (if ps then "[Hide" else "[Show")+" predefined code]"
  toggleHeading()
  
  removeInit = ->
    resource = $blab.resources.find("predefine.coffee")
    editor = resource?.containers?.fileNodes?[0].editor
    editor?.container.removeClass "init-editor"
    ev = resource?.containers?.evalNodes?[0].editor
    ev?.container.removeClass "init-editor"
  
  $("#predefined-code-heading")
    .click ->
      removeInit()
      predef.toggle(500)
      toggleHeading()


class App
  
  constructor: ->
    
    codeSections()
    
    # ZZZ should be method in Widgets?
    $(document).on "preCompileCoffee", (evt, data) =>
      resource = data.resource
      url = resource.url
      if url is "compute.coffee"
        Computation.precode()
        w.setUsed false for id, w of Widgets.widgets
    
    Widgets.initialize()
    
    widgetEditor = Widgets.widgetEditor
    
    computationEditor = new ComputationEditor
    
    # ZZZ not used
    new ComputationButtons
    
    textEditor = new TextEditor  # ZZZ to deprecate
    markdownEditor = new MarkdownEditor
    
    $pz.renderHtml = ->
      textEditor?.process()
      markdownEditor.process()
    
    @clickedOnComponent = false
    
    computationEditor.on "cursorOnWidget", (data) =>
      @clickedOnComponent = true
      widgetEditor.currentId = null
      widgetEditor.setViewPort data.match
      markdownEditor.setViewPort null
    
    $(document).on "clickWidget", (evt, data) =>
      @clickedOnComponent = true
      widgetEditor.currentId = data.id
      widgetEditor.setViewPort data.type + " " + "\"#{data.id}\""
      markdownEditor.setViewPort null
      setTimeout (=> @clickedOnComponent = false), 300
    
    markdownEditor.on "clickText", (data) =>
      @clickedOnComponent = true
      widgetEditor.setViewPort null
      markdownEditor.setViewPort data.start
    
    $(document.body).click (evt, data) =>
      setTimeout (=>
        unless @clickedOnComponent or $(evt.target).attr("class") is "ace_content"
          widgetEditor.setViewPort null
          markdownEditor.setViewPort null
        @clickedOnComponent = false
      ), 100
    
    widgetEditor.on "clickDelete", => @clickedOnComponent = true
    
    highlightLayout = ->
      Layout.highlight(widgetEditor.viewPortDisplayed or markdownEditor.viewPortDisplayed)
    
    widgetEditor.on "setViewPort", => highlightLayout()
    markdownEditor.on "setViewPort", => highlightLayout()
    
    Layout.on "renderedWidgets", =>
      console.log "App::renderedWidgets"
      textEditor.setWidgetsRendered()
      markdownEditor.setWidgetsRendered()
      
    $(document).on "aceFilesLoaded", =>
      textEditor.process()
      markdownEditor.process()
    

new App


# Export
$blab.Widget = Widget
$blab.Widgets = Widgets 

