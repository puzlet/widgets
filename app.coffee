#!vanilla

# Hack to process only once - not needed?
return if $blab?.layoutProcessed
$blab.layoutProcessed = true

viewPortDisplayed = false

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
    
    @clickedOnWidget = false
    
    $(document).on "clickWidget", (evt, data) =>
      @clickedOnWidget = true
      @currentId = data.id
      @setViewPort data.type + " " + "\"#{data.id}\""
      setTimeout (=> @clickedOnWidget = false), 300
    
    $(document).on "computationCursorOnWidget", (evt, data) =>
      @currentId = null
      @clickedOnWidget = true
      @setViewPort data.match
      
    $(document.body).click (evt, data) =>
      setTimeout (=>
        unless @clickedOnWidget or $(evt.target).attr("class") is "ace_content"
          @setViewPort null
        @clickedOnWidget = false
      ), 100
      
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
    
    viewPortDisplayed = txt isnt null # ZZZ temp: global
    Layout.highlight(viewPortDisplayed)
    
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
        @clickedOnWidget = true
      
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
    
    $(document).on "preCompileCoffee", (evt, data) =>
      resource = data.resource
      url = resource?.url
      @init(resource) if url is @filename
      
    $(document).on "compiledCoffeeScript", (evt, data) =>
      return unless data.url is @filename
      #@currentLine = null
      @setLine() if data.url is @filename
      
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
    $.event.trigger "computationCursorOnWidget", {match}
    


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
    
    onEvt = (evt, f) -> $(document).on(evt, -> f())
    
    onEvt "aceFilesLoaded", =>
      console.log "TextEditor::aceFileLoaded"
      if Wiky? then @process() else @loadWiky => @init()
    
    onEvt "renderedWidgets", =>
      console.log "TextEditor::renderedWidgets"
      @widgetsRendered = true
      @process()
    
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
    return unless Wiky?
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
    @text.click => @toggle()
    
    @resources = $blab.resources
    @widgetsRendered = false
    
    onEvt = (evt, f) -> $(document).on(evt, -> f())
    
    onEvt "aceFilesLoaded", =>
      console.log "MarkdownEditor::aceFileLoaded"
      if marked? then @process() else @loadMarked => @init()
      #if Wiky? then @process() else @loadWiky => @init()
    
    onEvt "renderedWidgets", =>
      console.log "MarkdownEditor::renderedWidgets"
      @widgetsRendered = true
      #@process()
  
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
    @process() if @widgetsRendered
  
  render: ->
    @renderId ?= null
    clearTimeout(@renderId) if @renderId
    @renderId = setTimeout (=>
      #@resource.content = 
      @process()
    ), 500
  
  process: ->
    console.log "MarkdownEditor::process"
    return unless marked?
    console.log "MarkdownEditor::process/marked"
    @text.empty()
    @html = marked(@resource.content)
    @text.append @html
    @setTitle()
#    @positionText()
    @sections @resource.content
    $.event.trigger "htmlOutputUpdated"
    
  setTitle: ->
    headings = $ ":header"
    return unless headings.length
    $blab.title = headings[0].innerHTML
    document.title = $blab.title
    
  toggle: ->
    return unless @editor
    @editorShown ?= false  # ZZZ get from editor show state?
    @editor.show(not @editorShown)
    @editorShown = not @editorShown
  
  sections: (file) ->
    
    console.log "=======file", file
    
    RE = ///
      ^\s*`\s*                   # begin-line, space and quote
      (?:p|pos)\s*:\s*           # p: or pos:
      (\d+)\s*,?\s*              # digits and comma (optional)
      (?:                        # optional
          (?:o|ord|order)\s*:\s*   # o:, ord: or order:
          (\d+)\s*                 # digits
      )?                         # end optional
      .*`.*$                     # end quote, comment, end-line
    ///mg                      # multiline & globl
    
    md = []
    
    snippet = (found) ->
      start  = found.start ? 0
      source = file[start..found.end]
      start: start
      pos: found.pos ? 0 
      order: found.order ? 1
      source: source
      html: marked source
        
    # search file for "found" regex
    found = {}
    
    while (match = RE.exec(file)) is not null
      
      console.log "==========MATCH"
    
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
    
    # check stuff
    console.log "*************** md", md
    #container = $("#app")
    #for m in md 
    #    container.append("<p>pos:#{m.pos}, order:#{m.order}</p>")
    #    container.append(m.html)
    #    container.append("<hr>")
  
  

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
    @highlight() if viewPortDisplayed  # ZZZ temp: global
    $.event.trigger "renderedWidgets"
  
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
      pos = widget.spec.pos
      if Number.isInteger(pos)
        # ZZZ temporary
        row = Math.round(pos/2)
        col = if pos % 2 then "left" else "right"
        pos = "#row#{row} .#{col}"
        console.log "POS", pos
      container = $(pos)
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

codeSections()

$(document).on "preCompileCoffee", (evt, data) =>
  resource = data.resource
  url = resource.url
  if url is "compute.coffee"
    Computation.precode()
    w.setUsed false for id, w of Widgets.widgets


Widgets.initialize()

new ComputationEditor
new ComputationButtons
textEditor = new TextEditor
markdownEditor = new MarkdownEditor
$pz.renderHtml = -> textEditor.process()

# Export
$blab.Widget = Widget
$blab.Widgets = Widgets 

