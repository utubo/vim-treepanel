vim9script

silent! packadd nerdfont.vim

# field {{{
const default = {
  rootmakers: ['.git', 'pacckage.json', '.svn', 'go.mod', 'Cargo.toml'],
  diricon: "\ue5fe",
  ellipsis: '︙',
  maxheight: 0,
  newfile: '[No Name]',
  newfileicon: "\uea7f",
}

var state = {
  width: 20,
  diricon: default.diricon,
}

var cache = {
  curdir: '',
  root: '',
  dirs: [],
  files: [],
}

def SetupState()
  const w = &tabpanelopt->matchstr('\(columns:\)\@<=\d\+')
  state.width = !w ? 20 : w->str2nr()
  state.diricon = Ini('diricon')
enddef
# }}}

# utility {{{
def AlignLeft(s: string): string
  const t = s->matchstr($'.*\%<{state.width + 1}v')
  return t ==# s ? t : $'{t}>'
enddef

def AlignRight(s: string): string
  if s->strdisplaywidth() <= state.width
    return s
  else
    const p = (s->strdisplaywidth() - state.width)
    return s->substitute($'.*\%{p}v', '<', '')
  endif
enddef

def Ini(key: string): any
  return get(g:, 'treepanel_' .. key, default[key])
enddef

def GetIcon(fname: string): string
  try
    return nerdfont#find(fname) ?? isdirectory(fname) ? state.diricon : ''
  catch
    # nop
  endtry
  return ''
enddef
# }}}

# main {{{
def GetDirInfo(): any
  const curdir = expand('%:p:h')
  if cache.curdir ==# curdir
    return cache
  endif

  # root
  cache.curdir = curdir
  var root = ''
  for m in Ini('rootmakers')
    root = finddir(m, curdir .. ';')
    if !!root
      root = root->fnamemodify(':h')
      break
    endif
  endfor
  if empty(root)
    root = curdir->substitute('\([/\\]\).*', '\1', '')
  endif
  cache.root = root

  # dirs
  const rel = curdir[len(root) :]
  const dlm = stridx(rel, '\') !=# -1 ? '\' : '/'
  cache.dirs = rel->split(dlm)

  # files
  cache.files = (globpath(curdir, '*', 1, 1) + globpath(curdir, '.*', 1, 1))
    ->map((_, f) => ({ name: f->fnamemodify(':t'), icon: '' }))
    ->filter((_, f) => f.name !=# '.' && f.name !=# '..')

  return cache
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
  const parent = lines[-1]
  var dircount = len(lines)

  # setup file list
  var viewfiles = d.files->copy()
  var curfile = expand('%')
  if !curfile
    curfile = Ini('newfile')
    viewfiles = [{ name: curfile, icon: Ini('newfileicon') }] + viewfiles
  endif
  const filecount = len(viewfiles)

  # ellipsis
  const maxheight = Ini('maxheight') ?? &lines
  const elp = Ini('ellipsis')

  if maxheight < dircount + filecount
    if filecount < dircount || maxheight - dircount < 3
      lines = [d.curdir->fnamemodify(':h')->AlignRight(), $'{indent}{elp}', parent]
      dircount = 3
    endif
  endif

  if maxheight < dircount + filecount
    var elpf = [{ name: '', icon: Ini('ellipsis') }]
    var maxfiles = maxheight - dircount - 1
    const idx = viewfiles->indexof((_, f) => f.name ==# curfile)
    if idx <= maxfiles
      viewfiles = viewfiles[: maxfiles - 1] + elpf
    elseif filecount - idx < maxfiles
      viewfiles = elpf + viewfiles[filecount - maxfiles :]
    else
      const a = idx - maxfiles / 2 + 1
      viewfiles = elpf + viewfiles[a : a + maxfiles - 2] + elpf
    endif
  endif

  if maxheight < dircount + len(viewfiles)
    lines = [d.curdir->fnamemodify(':h')->AlignRight(), $'{indent}{elp}', parent]
  endif

  # output files
  for f in viewfiles
    f.icon = f.icon ?? GetIcon(f.name)
    lines += [$'{indent}{f.icon}{f.name}'->AlignLeft()]
    if f.name ==# curfile
      lines[-1] = lines[-1]->substitute(indent, $'{indent}%#TabPanelSel#', '')
    endif
  endfor

  return lines->map((_, l) => $'%#TabPanel#{l}')->join('%@')
enddef

export def Tree(): string
  SetupState()
  return GetDirInfo()->CreateTree()
enddef

export def Refresh()
  cache.root = ''
  Tree()
enddef

def OnLoadPlugin()
  augroup vimrc_treepanel
    autocmd!
    autocmd WinEnter,BufEnter * Tree()
    autocmd BufFilePost * Refresh()
    autocmd OptionSet tabpanelopt Tree()
  augroup END
  Tree()
enddef

OnLoadPlugin()
# }}}

