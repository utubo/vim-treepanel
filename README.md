## vim-treepanel

<img width="608" height="406" alt="image" src="https://github.com/user-attachments/assets/4b06d0b9-667f-41f9-a9f1-fec0d0511a37" />

## Requirements
Vim 9.2.0083 +tabpanel

## Usage
```vim
packadd vim-treepanel
set stpl=2
set tpl=%{%treepanel#tree%}
```

## Settings

Default is

```vim
const g:treepanel = {
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
```

## Functions

- treepanel#Focus() ... Focus to treepanel.
- treepanel#Tree() ... return `treepanel#tree`.

