# luanti_mod_text_note_interaction

A luanti mod to make notes on blocks.

You can make luanti(minetest) as a TODO list or memo pad in 3D by this mod.


---
usage:

right click on node, default supports: [	"default:stone" ,
	"default:dirt" ,
	"default:cobble" ,
	"default:goldblock" ]
	
* write your text note.
* the first line will be shown as a floating text on the node.
* the node cannot be dug as long as it has note.
* you can add other kind of block by editing `init.lua`
* don't add note to nodes like `torch`, it will be tricky when it falls.

