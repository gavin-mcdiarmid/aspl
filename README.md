```
λ :: make
zig build --prominent-compile-errors;
touch aspl
rm aspl
ln -s ./zig-out/bin/aspl ./aspl
aspl on  main [!?] via ↯ v0.15.1 

λ :: ./aspl 
proc main: [String] -> Void;
proc main(args) {
	type Pair<T> = struct {
		a: T,  
		b: T,
	}
	println("Hello World")
}

========================
         Tokens         
========================
[0]	.proc,    	sidx: 0,	len: 4,   	col: 1
[1]	.Name,    	sidx: 5,	len: 4,   	col: 6
[2]	.Colon,    	sidx: 9,	len: 1,   	col: 10
[3]	.BrackL,    	sidx: 11,	len: 1,   	col: 12
[4]	.Name,    	sidx: 12,	len: 6,   	col: 13
[5]	.BrackR,    	sidx: 18,	len: 1,   	col: 19
[6]	.Arrow,    	sidx: 20,	len: 2,   	col: 21
[7]	.Name,    	sidx: 23,	len: 4,   	col: 24
[8]	.Semicolon,    	sidx: 27,	len: 1,   	col: 28
[9]	.Eol,    	sidx: 28,	len: 1,   	col: 29
[10]	.proc,    	sidx: 29,	len: 4,   	col: 1
[11]	.Name,    	sidx: 34,	len: 4,   	col: 6
[12]	.ParenL,    	sidx: 38,	len: 1,   	col: 10
[13]	.Name,    	sidx: 39,	len: 4,   	col: 11
[14]	.ParenR,    	sidx: 43,	len: 1,   	col: 15
[15]	.BraceL,    	sidx: 45,	len: 1,   	col: 17
[16]	.Eol,    	sidx: 46,	len: 2,   	col: 18
[17]	.type,    	sidx: 48,	len: 4,   	col: 2
[18]	.Name,    	sidx: 53,	len: 4,   	col: 7
[19]	.Lt,    	sidx: 57,	len: 1,   	col: 11
[20]	.Name,    	sidx: 58,	len: 1,   	col: 12
[21]	.Gt,    	sidx: 59,	len: 1,   	col: 13
[22]	.Eq,    	sidx: 61,	len: 1,   	col: 15
[23]	.struct,    	sidx: 63,	len: 6,   	col: 17
[24]	.BraceL,    	sidx: 70,	len: 1,   	col: 24
[25]	.Eol,    	sidx: 71,	len: 3,   	col: 25
[26]	.Name,    	sidx: 74,	len: 1,   	col: 3
[27]	.Colon,    	sidx: 75,	len: 1,   	col: 4
[28]	.Name,    	sidx: 77,	len: 1,   	col: 6
[29]	.Comma,    	sidx: 78,	len: 1,   	col: 7
[30]	.Eol,    	sidx: 79,	len: 3,   	col: 8
[31]	.Name,    	sidx: 82,	len: 1,   	col: 3
[32]	.Colon,    	sidx: 83,	len: 1,   	col: 4
[33]	.Name,    	sidx: 85,	len: 1,   	col: 6
[34]	.Comma,    	sidx: 86,	len: 1,   	col: 7
[35]	.Eol,    	sidx: 87,	len: 2,   	col: 8
[36]	.BraceR,    	sidx: 89,	len: 1,   	col: 2
[37]	.Eol,    	sidx: 90,	len: 2,   	col: 3
[38]	.Name,    	sidx: 92,	len: 7,   	col: 2
[39]	.ParenL,    	sidx: 99,	len: 1,   	col: 9
[40]	.StrLit,    	sidx: 100,	len: 13,   	col: 10
[41]	.ParenR,    	sidx: 113,	len: 1,   	col: 23
[42]	.Eol,    	sidx: 114,	len: 1,   	col: 24
[43]	.BraceR,    	sidx: 115,	len: 1,   	col: 1
[44]	.Eol,    	sidx: 116,	len: 1,   	col: 2


========================
       Main Nodes       
========================
[1]	.Name,    	subnodes: (0, 0),	tidx: 4 	[1]
[2]	.Array,    	subnodes: (1, 1),	tidx: 3 	[2]
[3]	.Name,    	subnodes: (0, 0),	tidx: 7 	[3]
[4]	.ProcType,    	subnodes: (3, 3),	tidx: 0 	[4]
[5]	.Name,    	subnodes: (0, 0),	tidx: 13 	[5]
[6]	.Name,    	subnodes: (0, 0),	tidx: 18 	[6]
[7]	.Name,    	subnodes: (0, 0),	tidx: 20 	[7]
[8]	.Generics,    	subnodes: (7, 1),	tidx: 18 	[8]
[9]	.Type,    	subnodes: (8, 0),	tidx: 17 	[9]
[10]	.Name,    	subnodes: (0, 0),	tidx: 26 	[10]
[11]	.Name,    	subnodes: (0, 0),	tidx: 28 	[11]
[12]	.Colon,    	subnodes: (10, 11),	tidx: 26 	[12]
[13]	.Name,    	subnodes: (0, 0),	tidx: 31 	[13]
[14]	.Name,    	subnodes: (0, 0),	tidx: 33 	[14]
[15]	.Colon,    	subnodes: (13, 14),	tidx: 31 	[15]
[16]	.Struct,    	subnodes: (9, 2),	tidx: 37 	[16]
[17]	.Eq,    	subnodes: (9, 16),	tidx: 17 	[17]
[18]	.Name,    	subnodes: (0, 0),	tidx: 38 	[18]
[19]	.StrLit,    	subnodes: (0, 0),	tidx: 40 	[19]
[20]	.Call,    	subnodes: (12, 1),	tidx: 38 	[20]
[21]	.Block,    	subnodes: (14, 2),	tidx: 16 	[21]
[22]	.Proc,    	subnodes: (16, 0),	tidx: 10 	[22]
[23]	.Block,    	subnodes: (19, 2),	tidx: 0 	[23]

========================
       Extra Nodes       
========================
[1] -> 1,		[2] Delim,		[3] -> 2,		[4] Delim,
```
[5] -> 5,		[6] Delim,		[7] -> 7,		[8] Delim,		
[9] -> 12,		[10] -> 15,		[11] Delim,		[12] -> 19,		
[13] Delim,		[14] -> 17,		[15] -> 20,		[16] -> 11,		
[17] -> 5,		[18] -> 21,		[19] -> 4,		[20] -> 22,		

Errors:
