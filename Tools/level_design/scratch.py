from analyze import show, BASE, board_of
from engine import natural_shortest
W7 = BASE + ["SI"]
specs = [
 {"id":"7-2","allowed":W7,"grid":[
  "gggBggg",
  "gOgggOg",
  "gOBOgBg",
  "gBgOgOg",
  "^gggBgg",
  "OBOgOBg",
  "FggggRg"]},
 {"id":"7-3","allowed":W7,"grid":[
  "vBgggOg",
  "gBgOgBg",
  "gggOKgg",
  "OBgBOBg",
  "ggggUgF",
  "gOBgOBB",
  "gggggOg"]},
 {"id":"7-4","allowed":W7,"grid":[
  "gggOggF",
  "KBgBgOU",
  "gOgggBg",
  "gBOBgOg",
  "ggKBUBg",
  "OBgOgBg",
  ">ggOggg"]},
 {"id":"7-5","allowed":W7,"grid":[
  "ggBgggg",
  ">CgggOg",
  "BgOBCBg",
  "ggOgggg",
  "gBBgOBF",
  "ggOgBgg",
  "OggggBg"]},
]
for s in specs: show(s)
