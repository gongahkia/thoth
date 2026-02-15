[![](https://img.shields.io/badge/thoth_1.0.0-passing-%23004D00)](https://github.com/gongahkia/thoth/releases/tag/1.0.0) 
[![](https://img.shields.io/badge/thoth_2.0.0-passing-%23228B22)](https://github.com/gongahkia/thoth/releases/tag/2.0.0) 
[![](https://img.shields.io/badge/thoth_3.0.0-passing-%2332CD32)](https://github.com/gongahkia/thoth/releases/tag/3.0.0) 

<h1 align='center'><code>thoth</code></h1>
<div align='center'>
<p>
  <i>Functional lua pocket knife.</i>
</p>
<img src='https://github.com/gongahkia/thoth/assets/117062305/276628d5-aefa-442c-ad3e-5df51b4357b3' width=50% height=50%></img>
</div>

## installation

```console
$ git clone https://github.com/gongahkia/thoth
$ cd thoth
$ make clean
```

## usage

```lua
-- eg usage
local s = require("src.stringify")
print(s.Lstrip("###watermelon", "#"))
```
