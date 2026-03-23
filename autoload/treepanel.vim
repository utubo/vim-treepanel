vim9script

export var tree = ''

const CURSOR_TOP = 0
const CURSOR_CURFILE = -1

# helper
export def Tree(): string
  return tree
enddef

silent! packadd nerdfont.vim

# field {{{
const default = {
  rootmakers: ['.git', 'package.json', '.svn', 'go.mod', 'Cargo.toml'],
  diricon: "\ue5fe",
  ellipsis: '︙',
  maxheight: 0,
  newfile: '[No Name]',
  newfileicon: "\uea7f",
  key_blur: ['q'],
  key_open: ["\<CR>", 'l'],
  key_vsplit: ['v'],
  key_split: ['s'],
  key_parent: ["\<BS>", 'h'],
  key_search: ['/'],
  key_blursearch: ['/', "\<Tab>"],
  key_bottom: ['G'],
  key_top: ['g'],
}

var state = {
  width: 20,
  diricon: default.diricon,
  dir: '',
  cursor: -1,
  focused: false,
  search_focused: false,
  search: '',
  stpl_back: -1,
  popup: 0,
  timer: 0,
}

def SetupState()
  const w = &tabpanelopt->matchstr('\(columns:\)\@<=\d\+')
  state.width = !w ? 20 : w->str2nr()
  state.diricon = Ini('diricon')
  state.curfile = expand('%:p')
  state.curdir = expand('%:p:h') ?? getcwd()
enddef

var cache = {
  dir: '',
  root: '',
  dirs: [],
  files: [],
  maxidx: 0,
}
# }}}

# utility {{{
def AlignLeft(s: string, pad: number = 0): string
  const w = state.width - pad
  const d = strdisplaywidth(s)
  if d <= w
    return $'{s}{repeat(' ', w - strdisplaywidth(s))}'
  else
    return s->matchstr($'.*\%<{w + 1}v') .. '>'
  endif
enddef

def AlignRight(s: string, pad: number = 0): string
  const w = state.width - pad
  if s->strdisplaywidth() <= w
    return s
  else
    const p = (s->strdisplaywidth() - w)
    return s->substitute($'.*\%{p}v', '<', '')
  endif
enddef

def Ini(key: string): any
  return get(g:, 'treepanel', {})->get(key, default[key])
enddef

def AnyOf(v: any, key: string): bool
  return Ini(key)->index(v) !=# -1
enddef

def GetIcon(fname: string): string
  try
    return isdirectory(cache.dir .. '/' .. fname) ? state.diricon : nerdfont#find(fname) ?? ''
  catch
    # nop
  endtry
  return ''
enddef

def NewItem(prop: any): any
  return {
    path: '',
    name: '',
    icon: '',
    index: -99,
    bufnr: -1,
  }->extend(prop)
enddef
# }}}

# main {{{
def GetDirInfo(dir: string): any
  if cache.dir ==# dir && !len(cache.dirs)
    return cache
  endif

  # root
  cache.dir = dir
  var root = ''
  for m in Ini('rootmakers')
    root = finddir(m, dir .. ';')
    if !!root
      root = root->fnamemodify(':h')
      break
    endif
  endfor
  if empty(root)
    root = dir->substitute('\([/\\]\).*', '\1', '')
  endif
  cache.root = root

  # dirs
  const rel = dir[len(root) :]
  const dlm = stridx(rel, '\') !=# -1 ? '\' : '/'
  cache.dirs = rel->split(dlm)

  # files
  cache.files = (globpath(dir, '*', 1, 1) + globpath(dir, '.*', 1, 1))
    ->map((i, p) => NewItem({ path: p, name: p->fnamemodify(':t') }))
    ->filter((_, f) => f.name !=# '.' && f.name !=# '..')
  cache.files->foreach((i, f) => {
    f.index = i
  })

  # current buffer
  if !state.curfile && dir ==# state.curdir
    cache.files += [NewItem({
      name: Ini('newfile'),
      icon: Ini('newfileicon'),
      index: len(cache.files),
      bufnr: bufnr()
    })]
  endif
  cache.maxidx = cache.files->len() - 1

  return cache
enddef

def SetCursor()
enddef

def CreateTree(d: any): string
  # output root
  var lines = [d.root->AlignRight()]

  # output dirs
  var indent = ' '
  for dirname in d.dirs
    lines += [$'{indent}{state.diricon}{dirname}'->AlignLeft()]
    indent ..= ' '
  endfor
  var dircount = len(lines)

  # setup file list
  var viewfiles = d.files->copy()
  const filecount = len(viewfiles)

  # scroll
  const maxheight = Ini('maxheight') ?? &lines
  const elp = Ini('ellipsis')

  if maxheight < dircount + filecount && 3 < dircount
    indent = ' '
    lines = [d.dir->fnamemodify(':h')->AlignRight(), elp]
    lines += [$'{indent}{state.diricon}{d.dirs[-1]}'->AlignLeft()]
    dircount = 3
    indent ..= ' '
  endif

  const curbuf = bufnr()
  if state.cursor ==# CURSOR_CURFILE
    if !state.curfile && cache.dir ==# state.curdir
      state.cursor = viewfiles->indexof((_, f) => f.bufnr ==# curbuf)
    elseif cache.dir ==# state.curdir
      state.cursor = viewfiles->indexof((_, f) => f.path ==# state.curfile)
    endif
  endif

  const viewcount = maxheight - dircount - (state.search_focused ? 1 : 0)
  var scrollbar = {
    visible: viewcount < filecount,
    pos: -1,
    width: 0,
  }
  if scrollbar.visible
    scrollbar.width = 1
    const half = viewcount / 2
    const top = sort([0, filecount - viewcount, state.cursor - half], 'n')[1]
    viewfiles = viewfiles[top : top + viewcount - 1]
    scrollbar.pos = viewcount * (top + half) / filecount
  endif

  # output files
  var i = 0
  for f in viewfiles
    f.icon = f.icon ?? GetIcon(f.name)
    lines += [$'{indent}{f.icon}{f.name}'->AlignLeft(scrollbar.width)->substitute('%', '%%', 'g')]
    if f.name ==# '.git'
      g:a = viewfiles
      g:b = state.cursor
    endif
    if state.cursor ==# f.index
      if state.focused && !state.search_focused
        lines[-1] = '%#Cursor#' .. lines[-1]
      else
        lines[-1] = lines[-1]->substitute(indent, $'{indent}%#TabPanelSel#', '')
      endif
    endif
    if scrollbar.pos ==# i
      lines[-1] ..= '┃'
    elseif scrollbar.visible
      lines[-1] ..= '│'
    endif
    i += 1
  endfor

  # search
  if state.search_focused
    lines += [$'%#StatusLine#/{AlignRight(state.search, 2)}%#Cursor# %#TabPanel#']
  endif

  return lines->map((_, l) => $'%#TabPanel#{l}')->join('%@')
enddef

def Update()
  SetupState()
  tree = GetDirInfo(state.dir)->CreateTree()
  redrawtabpanel
enddef

def OpenCurrentFile(refresh: bool = false)
  state.dir = expand('%:p:h')
  state.cursor = CURSOR_CURFILE
  state.search_focused = false
  state.search = ''
  if refresh
    Refresh()
  else
    Update()
  endif
enddef

def OpenDir(dir: string)
  state.dir = dir
  state.cursor = CURSOR_TOP
  state.search = ''
  Update()
enddef

export def Refresh()
  cache.dir = ''
  Update()
enddef
# }}}

# focus {{{
def KeyHook(w: number, key: string): bool
  if key ==# "\<CursorHold>" || key ==# "\<Cmd>" || key ==# "\<ScriptCmd>"
    return false
  elseif state.search_focused && KeyHookSearch(key)
    return true
  elseif key ==# "\<ESC>" || key->AnyOf('key_blur')
    Blur()
  elseif key ==# 'k'
    if 0 < state.cursor
      state.cursor -= 1
      Update()
    endif
    return true
  elseif key ==# 'j'
    if state.cursor < cache.maxidx
      state.cursor += 1
      Update()
    endif
  elseif key->AnyOf('key_top')
    state.cursor = CURSOR_TOP
    Update()
  elseif key->AnyOf('key_bottom')
    state.cursor = cache.maxidx
    Update()
  elseif key->AnyOf('key_open')
    OpenSelected('edit')
  elseif key->AnyOf('key_vsplit')
    OpenSelected('vsplit')
  elseif key->AnyOf('key_split')
    OpenSelected('split')
  elseif key->AnyOf('key_parent')
    OpenParent()
  elseif key->AnyOf('key_search')
    state.search_focused = true
    Refresh()
  endif
  return true
enddef

def KeyHookSearch(key: string): bool
  if key->AnyOf('key_blursearch')
    state.search_focused = false
    Refresh()
    return true
  elseif key ==# "\<BS>"
    if !state.search
      state.search_focused = false
      Refresh()
      return true
    else
      state.search = state.search->substitute('.$', '', '')
    endif
  elseif key =~# '\p'
    state.search ..= key
  else
    return false
  endif
  if !!state.search
    const m = matchfuzzy(cache.files, state.search, { text_cb: (v) => v.name })->get(0, false)
    if !!m
      state.cursor = cache.files->indexof((_, v) => v ==# m)
    endif
  endif
  Update()
  return true
enddef

export def Focus()
  if state.stpl_back ==# -1
    state.stpl_back = &stpl
  endif
  set stpl=2
  state.focused = true
  state.popup = popup_create(' ', { opacity: 0, filter: KeyHook, mapping: false })
  state.cursor = CURSOR_CURFILE
  state.search = ''
  state.search_focused = false
  state.timer = timer_start(500, OnTimer, { repeat: -1 })
  Refresh()
enddef

def OnTimer(_: number)
  if !state.focused
    return
  endif
  if !popup_getpos(state.popup)->has_key('col')
    Blur()
  endif
enddef

def Blur()
  state.focused = false
  if !!state.timer
    timer_stop(state.timer)
    state.timer = 0
  endif
  if state.stpl_back !=# -1
    &stpl = state.stpl_back
    state.stpl_back = -1
  endif
  if !!state.popup
    popup_close(state.popup)
    state.popup = 0
  endif
  OpenCurrentFile()
enddef

def OpenSelected(cmd: string)
  const p = cache.files[state.cursor].path
  if isdirectory(p)
    OpenDir(p)
  else
    execute cmd p
    Blur()
  endif
enddef

def OpenParent()
  OpenDir(fnamemodify(cache.dir, ':h'))
enddef
# }}}

# setup {{{
def OnLoadPlugin()
  augroup vimrc_treepanel
    autocmd!
    autocmd WinEnter,BufEnter * OpenCurrentFile()
    autocmd BufFilePost * OpenDirFurrentFile(true)
    autocmd OptionSet tabpanelopt Update()
  augroup END
  Refresh()
enddef

OnLoadPlugin()
# }}}

