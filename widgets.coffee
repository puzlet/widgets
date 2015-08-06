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
      widths: 100  #[100, 100]
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
    
    @colGroup = $ "<colgroup>"
    @table.append @colGroup
    @widths ?= 100
    @widths = [@widths] unless Array.isArray(@widths)
    @setColGroup()
      
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
    
    $(document).on "blabcompute", => @setFunctions()
    
    #(document.body).removeEventListener "copy"
    #(document.body).addEventListener "copy", (e) => console.log "doc copy"
    
    @setVal([[0]])
  
  
  mouseEvents: ->
    
    # TODO: doesn't work properly if move column and then back to diff row.
    
    #return
    
    # see http://stackoverflow.com/questions/9578162/highlighting-table-cells-on-mouse-drag
    
    #console.log "+++++++++++ mouse events", @flag
    
    down = false
    first = false
    column = null
    start = -1
    end = -1
    last = -1
    lastLeave = null
    selected = []
    vector = []
    
    #isEditable = false
    
    # need "selected" vector.
    
    tdSel = $("##{@domId()} td")
    
    # ZZZ other unbinds here, too.
    tdSel.unbind "mouseenter"
    tdSel.unbind "mouseleave"
    
    row = (e) -> $(e.target).parent().index()
    col = (e) -> $(e.target).index()
    
    highlight = (e) ->
      $(e.target).css background: "rgb(180, 213, 254)"
      
    highlightSelected: ->
      
    normal = (e) ->
      $(e.target).css background: ""  # ZZZ Need to revert to what it was?
    
    clearId = null
    
    clear = =>
      if selected.length
        normal(s) for s in selected
      down = false
      first = false
      column = null
      start = -1
      end = -1
      last = -1
      lastLeave = null
      selected = []
      vector = []
      #isEditable = false
      
    
    #$(document).on "blabmousedown", =>
    #  console.log "blabmd"
    
    #unless @bodyMouseDown
    # TODO: not best way to do this.
    #unless @flag
    $(document).on "blabmousedown", (e) =>
      #console.log "body mousedown"
      #return if down
      clear() unless down
          #clearId = setTimeout (-> clear()), 1000
      #  @bodyMouseDown = true
      #@flag = true
    
    tdSel.blur (e) => console.log "blur"
    
    tdSel.mousedown (e) =>
      #return
      
#      e.preventDefault() unless $(e.target).attr("class") is "editable-table-cell"
      #console.log "-----target", $(e.target).attr "class"
      
      #tdSel.focus()
      #return
      
      #clearTimeout(clearId) if clearId
      #clearId = null
      #e.preventDefault()
      #console.log "td mousedown", row(e), col(e)
      if selected.length
        normal(s) for s in selected
      selected = []
      down = true
      first = true
      column = col(e)
      #setTimeout (=> @table.click()), 100
      
      idx = row(e)
      
      #if down and first
      #highlight e
      start = idx
      end = idx
      #selected.push e
      
      #tdSel.select()
      window.getSelection().removeAllRanges()  # IE: document.selection.empty()
      #first = false
    
    # tdSel.mousemove (e) ->
    #   return unless down
    #   idx = row(e)
    #   console.log "idx/end", idx, start
    #   if idx isnt start
    #     window.getSelection().removeAllRanges()
    #     console.log "*******Prevent"
    #     e.preventDefault()
    #     e.stopPropagation()
      
    
    # tdSel.mousemove (e) ->
    #   e.preventDefault()
    #   if down and first
    #     highlight e
    #     idx = row(e)
    #     column = col(e)
    #     end = idx
    #     selected.push e
    #     first = false
      
    tdSel.mouseenter (e) =>
      return unless down
      return unless col(e) is column
      
      e.preventDefault()
      e.stopPropagation()
      
      window.getSelection().removeAllRanges() unless $(e.target).attr("class") is "editable-table-cell"
      #window.getSelection().removeAllRanges()
      
      
      first = false
      idx = row(e)
      #console.log "************* mouseenter" #, last, idx #, e.target
      
      if lastLeave and row(lastLeave)>idx
        selected.pop()
        normal lastLeave
      
      if idx>end
        highlight e
        selected.push e
      
      end = idx
        #$(lastLeave.target).css background: "white" #if down and idx>end
      #last = idx
    
    tdSel.mouseleave (e) =>
      return unless down
      return unless col(e) is column
      
#      window.getSelection().removeAllRanges() unless $(e.target).attr("class") is "editable-table-cell"
      #window.getSelection().removeAllRanges()
      
      
      e.preventDefault()
      
      console.log "************* mouseleave"  #, last, idx #, e.target
      
      
      idx = row(e)
      
      if down and first
        highlight e
        selected.push e
        #end = idx
        #selected.push e
        first = false
      
      #$(e.target).css background: "white" if down and idx>end
      lastLeave = e
      #last = idx
    
    #vector = []
    
    tdSel.mouseup (e) =>
      e.preventDefault()
      e.stopPropagation()
      
#      window.getSelection().removeAllRanges() unless $(e.target).attr("class") is "editable-table-cell"
      
      #console.log "mouseup", e.target
      down = false
      #console.log "selected", selected
     #console.log "selected"
      
      if selected.length is 1
        normal start
      
      vector = []
      for s in selected
        vector.push $(s.target).text()
      #setTimeout (=> @table.focus()), 1000
        #$(s.target).select()
      #@table.click()
      #if selected.length
      #  selected[0].target.addEventListener "copy", (e) => console.log "COPY!"
      
    #tdSel.click (e) =>
    #  e.preventDefault()
    #  e.stopPropagation()
    
    $(document).on "blabcopy", (ev, data) =>
      console.log "COPY!", @id, vector
      return unless vector.length
      console.log "data", data
      e = data.original
      e.preventDefault()
      string = vector.join ", "
      e.clipboardData.setData('Text', string)
    
    
    $(document).on "blabpaste", (ev, data) =>
      console.log "PASTE!", @id
      return unless selected.length
      #return unless vector.length
      console.log "data", data
      e = data.original
      e.preventDefault()
      #string = vector.join " "
      t = e.clipboardData.getData('Text')
      tv = t.split " "
      console.log "text", tv
    
    
    #@table[0].removeEventListener "copy"
    # if false #tdSel.length is 0 #and not @listening
    #
    #   console.log "+++++++++++++ SETUP copy", @id
    #   @table[0].addEventListener "copy", (data) =>
    #     console.log "COPY", vector
    #     return unless vector.length
    #     e = data.e
    #     e.preventDefault()
    #     string = vector.join " "
    #     e.clipboardData.setData('text/plain', string)
        #setTimeout (-> console.log 'Clipboard', e.clipboardData.getData('Text'), e), 1000
  #      console.log 'Clipboard', e.clipboardData.getData('text/html'), e
        #return
      #@listening = true
          
      #if down
      
    #return
    
    #@table.unbind "mousedown"
    #@table.unbind "mouseup"
    
    
    #@table.mousedown (e) =>
    #  e.preventDefault()
    #  console.log "mousedown"#, #$(e.target).attr "class"
    #  down = true
      
    #@table.mousemove (e) =>
    #  e.preventDefault()
      #last = $(e.target).parent().index()
    #  console.log "mousemove", last
      #$(e.target).css background: "green" if down
    
    #console.log "set mouse move listener"
  
  
  setColGroup: (n) ->
    
    if n
      expand = n and @widths.length<n and not Array.isArray(@spec.widths)
      return unless expand
      @widths = (@spec.widths for i in [1..n])
    
    @colGroup.empty()
    for w, idx in @widths
      css = @colCss?[idx] ? {}
      css.width = w
      col = $ "<col>", css: css
      @colGroup.append col
  
  
  initialize: ->
  
  setVal: (v) ->
    
    @setUsed()
    
    unless v[0] instanceof Array
      # Doesn't yet handle multiple objects (rows)
      # Need to do similar check as one below?  [] and [->]
      @v0 = v[0]
      @first = null
      return @setValObject()
    
    # Currently, we don't support constant value columns mixed in with [] and [->].
    o = {}
    invalid = false
    for val, idx in v
      l = val.length
      if l is 0
        dynamic = true
        editable = true
        o[idx] = val  # Arg is []
      else if l is 1 and typeof val[0] is "function"
        dynamic = true
        o[idx] = val[0]
      else
        invalid = true
        break
    
    if dynamic
      if invalid
        console.log "Invalid table signature."  # Throw error?
        return null
      else unless editable
        console.log "Must have at least one editable column."
        return null
      else
        @v0 = o
        @first = null  # ZZZ dup code?
        return @setValObject()
    else
      @setValRegular(v)
  
  setValRegular: (v) ->
    
    @setColGroup(v.length)
    
    @tbody.empty()
    row = []
    for x, idx in v[0]
      tr = $ "<tr>"
      @tbody.append tr
      for i in [0...v.length]
        d = v[i][idx]
        val = if typeof d is "number" then @format(d) else d
        tr.append "<td class='table-cell'>"+val+"</td>"
    @value = v
    
    @mouseEvents()
    
    null
  
  setValObject: ->
    
    # TODO: define in constructor?
    @editableCells = {}
    @functionCells = {}
    @funcs = {}
    @isFunc = {}
    @editableCols = []  # Columns (editable)
    @t ?= {}  # Table object after evaluation
    @editNext ?= {}  # Needs to retain state from last computation.
    
    numCols = 0
    
    for name, val of @v0
      numCols++
      @first = name unless @first  # Bug if function first col?
      @isFunc[name] = typeof val is "function"
      if @isFunc[name]
        @functionCells[name] ?= []
        @funcs[name] = val
        @t[name] = (0 for v in @t[@first])  # initialize to zero for function calls. ZZZ should it be for current col?  
      else
        @firstEditableColName = name unless @firstEditableColName
        @editableCells[name] ?= []
        # ZZZ: val should be length zero if data? 
        if val.length is 0 then val = [null]
        @tableData[name] ?= val
        val = @tableData[name]
        @t[name] = (v for v in val)  # Must do copy here.
        @checkNull(name)
        @editableCols.push @t[name]
    
    @colNames = (name for name, cell of @editableCells)
    @colIdx = {}
    @colIdx[name] = idx for name, idx in @colNames
    
    @currentCol ?= @first  # Assumes editable?
    
    # Set table cells
    @setColGroup(numCols)
    @tbody.empty()
    for x, idx in @tableData[@firstEditableColName]
      tr = $ "<tr>"
      @tbody.append tr
      for name, v of @v0
        td = $ "<td>"  # class table-cell?
        tr.append td
        @setCell td, name, idx, v
    
    # !!!!!!!!!!! @mouseEvents()  # ZZZ !!!!! reinstate later.
    
    @checkForFocusCell()  # ZZZ move to clickNext?
    @clickNext(@currentCol)
    @value = v
    
    # Return value: x or [x, y, ...]
    if @editableCols.length is 1 then @editableCols[0] else @editableCols
  
  setCell: (td, name, idx, v) ->
    if @isFunc[name]
      @functionCells[name].push td
    else
      vs = @tableData[name]
      d = if vs then vs[idx] else @t[name][idx]  # ZZZ is this needed?
      cell = @createEditableCell td, name, idx, d
      @editableCells[name].push cell
  
  checkNull: (name) ->
    for v, idx in @t[name]
      @t[name][idx] = 0 if v is null
  
  createEditableCell: (container, name, idx, val) ->
    cell = new EditableCell
      container: container
      idx: idx
      val: val  # TODO: need to format for display?
      callback: @cellAction(name, idx)
      del: @cellDeleteAction(name, idx)
      insert: @cellInsertAction(name, idx)
      paste: @cellPasteAction(name, idx)
      clickCell: @focusAction(name, idx)  # Later: needs to set clickNext params.
    
  setFunctions: ->
    
    return unless @funcs
    
    for name, func of @funcs
      
      try
        val = func(@t)  # pass @t here, in case func needs it (no closure).
        @t[name] = (v for v in val)  # copy
      catch error
        console.log "====Blabr====", error
        return
        
      for cell, idx in @functionCells[name]
        d = val[idx]
        v = if typeof d is "number" then @format(d) else d
        cell.text v
    
  cellAction: (name, idx) ->
    # Returns set/edited function.
    (val, changed, dir, colDir) =>
      console.log "====colDir", colDir, name
      
      # Don't use focusCell if moving cell with key.
      if dir isnt 0 or colDir isnt 0
        @focusCell = null
      
      #if colDir is 1 then @currentCol = "a"  # TEMP
      # BUG: does not handle case where cell val changed before left/right
      if colDir is 1
        m = @colIdx[name] + 1
        if m<@colNames.length
          n = @colNames[m]
          console.log "name (right)", n
          @currentCol = n
          @editNext[n] = idx
          #@clickNext(n)
          #return
      else if colDir is -1
        m = @colIdx[name] - 1
        if m>=0
          n = @colNames[m]
          console.log "name (left)", n
          @currentCol = n
          @editNext[n] = idx
          #@clickNext(n)
          #return
      else
        n = name
        @setNext(idx, dir, n)
      
      if changed
        @tableData[name][idx] = val
        console.log "SET TABLE DATA", name, idx, val, @tableData
        @computeAll()
      else
        @clickNext(n)
        
  setNext: (idx, dir, name) ->
    console.log "%%%%%%%%% SET NEXT", name
    @currentCol = name
    if dir is 0
      @editNext[name] = false
    else
      @editNext[name] = idx + dir
      if @firstEditableColName and @editNext[name]>=@editableCells[name].length
        @appendCell(name) 
      else
        @editNext[name] = idx unless @nextOk(name)
    #console.log "setNext (idx, name, dir, editNext)", idx, name, dir, @editNext[name]
  
  clickNext: (name) ->
    console.log "clickNext", name, @editNext
    return unless @nextOk(name)
    @editableCells[name][@editNext[name]].click()
    #@editNext = false
  
  nextOk: (name) ->
    next = @editNext[name]
    next isnt false and next>=0 and next<@editableCells[name].length
  
  checkForFocusCell: ->
    # Handle clicking on another cell after changing previous cell (and thus recomputing)
    return unless @focusCell
    @currentCol = @focusCell.name
    @editNext[@currentCol] = @focusCell.idx
    @focusCell = null
  
  appendCell: (name) ->
    # ZZZ shouldn't need to pass name?
    console.log "append", @v0[@first], @tableData
    #@v0[@first].push 0
    
    # Append cell for *all* editable columns.
    for n, cell of @editableCells
      @tableData[n].push null
      @editableCells[n].push null
    
    console.log "editNext", @editNext[name]
    @computeAll()
    #cell = new EditableCell
    #  container: @editableCells[idx-1].container
    #  val: 0  # TODO: need to format for display?
    #  callback: @cellAction(name, idx)
    #@editableCells.push cell
  
  focusAction: (name, idx) ->
    =>
      console.log "********* FOCUS ACTION", name, idx
      @focusCell = {name, idx}
  
  cellInsertAction: (name, idx) ->
    =>
      console.log "INSERT", name, idx
      @currentCol = name
      for n, cell of @editableCells
        @tableData[n].splice(idx, 0, null)  # TODO: align other columns
        @editNext[n] = idx
      @computeAll()
      #if idx is @editableCells.length-1
      #  console.log "DELETE", idx, @tableData[name]
      #  @tableData[name].pop()
      #  @editableCells.pop()
      #  @editNext = idx - 1
      #  @computeAll()
        
  cellDeleteAction: (name, idx) ->
    =>
      #@tableData[name].pop()
      
      # TODO: Check other columns empty?
      
      @focusCell = null  # needed?
      
      @currentCol = name
      for n, cell of @editableCells
        @tableData[n].splice(idx, 1)
        #@editableCells.pop()
      
      @editNext[name] = if idx>1 then idx - 1 else idx=0
      @computeAll()
      #return
      # old
      # if idx is @editableCells[name].length-1
      #   console.log "DELETE", idx, @tableData[name]
      #   @tableData[name].pop()
      #   @editableCells[name].pop()
      #   @editNext[name] = idx - 1
      #   @computeAll()
        
  cellPasteAction: (name, idx) ->
    
    # NOT IMPLEMENTED for multiple columns?  Does it need to change?
    
    (idx, val) =>
      #e.preventDefault()
      #text = 'hello'
      #console.log "PASTE", name, idx, text, val.split(" ")
      vals = val.split(", ").join(" ").split(" ")
      for v, i in vals
        @tableData[name][idx+i] = parseFloat(v)
      @editNext[name] = idx
      @computeAll()
      #setTimeout (-> console.log(e.clipboardData.getData('Text'))), 1000 #, val 
   
  format: (x) ->
    if x is 0 or Number.isInteger?(x) and Math.abs(x)<1e10
      x
    else
      x.toPrecision(@precision ? 4) 


class EditableCell
  
  constructor: (@spec) ->
    
    {@container, @idx, @val, @callback, @del, @insert, @paste, @clickCell} = @spec
    
    @disp = if @val is null then "" else @val
    #console.log "CELL", @val, @disp
    
    @div = $ "<div>",
      class: "editable-table-cell"
      text: @disp
      contenteditable: true
      
      focus: (e) =>
        @clickCell()
        #e.preventDefault()
        setTimeout (=> @selectElementContents @div[0]), 0
      
      click: (e) =>
        #console.log "CLICK CELL", @idx
        @click() #e.stopPropagation()
      keydown: (e) => @keyDown(e)
      change: (e) => @change(e)
      blur: (e) => setTimeout (=> @change(e)), 100 #@reset()  # Not quite right - needs to select new cell that click on.
      
      #click: (e) =>
        #e.stopPropagation()
        #@click()
        
    @div.on "paste", (e) =>
      console.log "cell paste"
      @div.css color: "white"
      setTimeout (=>
        @paste(@idx, @div.text())
        #@input.show()
      ), 0
        
    @input = @div
        
    @container.append @div
    
  selectElementContents: (el) ->
    range = document.createRange()
    range.selectNodeContents(el)
    sel = window.getSelection()
    sel.removeAllRanges()
    sel.addRange(range)
  
  click: ->
    #console.log "**** CLICK", @idx
    @div.focus()
    #@selectElementContents @div[0]
    #@div.select()
    #return
    #@div.empty()
    #@createInput()
    #@div.append @input
    #@input.focus()
    #@input.select()
    
  reset: ->
    @div.empty()
    @div.text(if @val is null then "" else @val)
    
  # createInput: ->
  #   @input = $ "<input>",
  #     class: "editable-table-input-field"
  #     value: @disp
  #     click: (e) -> e.stopPropagation()
  #     keydown: (e) => @keyDown(e)
  #     change: (e) => @change(e)
  #     blur: => @reset()
  #
  #   @input.on "paste", (e) =>
  #     console.log "cell paste"
  #     @input.css color: "white"
  #     setTimeout (=>
  #       @paste(@idx, @input.val())
  #       #@input.show()
  #     ), 0
        
  keyDown: (e) ->
    
    key = e.keyCode
    console.log "key", key, e.shiftKey
    
    ret = 13
    backspace = 8
    left = 37
    up = 38
    right = 39
    down = 40
    
    if key is ret
      # Handle case where user presses return without changing value.
      e.preventDefault()
      if e.shiftKey
        @insert(@idx)
      else
        @noChange = true
        @done(1)
      return
      
    if key is backspace
      console.log "backspace", @idx
      if @div.text() is ""
#      if @input.val() is ""
        e.preventDefault()
        @del(@idx) 
      return
    
    return unless key in [left, up, right, down]
    e.preventDefault() if key in [up, down]
    
    # NOT YET WORKING - need to make work with edit mode.  click on selected text to edit.
    #if key in [left, right]
    #  r = window.getSelection().getRangeAt(0)
    #  console.log "+++++ SEL", r.startContainer, r.startOffset, r.endOffset
    #  return unless r.startOffset?
    #  return unless (key is left and r.startOffset is 0) or (key is right and r.startOffset is r.startContainer.length)
      #return
      #setTimeout (-> console.log "SEL", r.startContainer, r.startOffset, r.endOffset), 100
      #return
    
    dir = if key is down then 1 else if key is up then -1 else 0
    colDir = if key is right then 1 else if key is left then -1 else 0
    @done(dir, colDir)
    
  change: (e) ->
    @done() unless @noChange
  
  done: (dir=0, colDir=0) ->
    v = @input.text()  # @div?
    if v is ""
      changed = v isnt @disp
      val = null
      @val = val
      @callback val, changed, dir, colDir
    else
      val = if v then parseFloat(v) else null # TODO: what if text cell?
      changed = val isnt @val
      @val = val if changed
      @disp = @val
      @callback val, changed, dir, colDir


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

