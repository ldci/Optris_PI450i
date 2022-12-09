Red [
	Title:   "Red and Optris Binary Files"
	Author:  "ldci"
	File: 	 %optrisroutines.red
	Needs:	 View
]

;--some routines for a faster processing
;--this version is 16-bit only for new optris files



;--Min Max  with just one pass by image
getMinMax: routine [
"Get the minimal and maximal values in image  as an integer"
	bin 		[binary!] 
	blk	 	 	[block!]
	/local
	mini		[integer!]
	maxi 		[integer!]
	head tail 	[byte-ptr!] 
	lo hi int16 [integer!]	
	int
][
	mini: 65535 maxi: 0
	block/rs-clear blk				;--clear values
	head: binary/rs-head bin		;--byte pointer
	tail: binary/rs-tail bin		;--byte pointer
	while [head < tail][
		lo: as integer! head/value	;--low byte
		head: head + 1
		hi: as integer! head/value	;--high byte
		head: head + 1
		int16: lo or (hi << 8)		;--16-bit integer value
		if int16 > maxi [maxi: int16]
		if int16 < mini [mini: int16]
	]
	int: integer/box mini
	block/rs-append blk as red-value! int
	int: integer/box maxi
	block/rs-append blk as red-value! int  
]


getAllMinMax: routine [
"Get the minimal and maximal values in raw data as an integer"
	bin 		[binary!] 
	blk	 	 	[block!]
	mini		[integer!]
	maxi 		[integer!]
	/local
	head tail 	[byte-ptr!] 
	lo hi 		[byte!]
	int16 		[integer!]	
	int			[red-integer!]
][
	block/rs-clear blk				;--clear values
	head: binary/rs-head bin		;--byte pointer
	tail: binary/rs-tail bin		;--byte pointer
	while [head < tail][
		lo: head/value				;--low byte
		head: head + 1
		hi: head/value				;--high byte
		head: head + 1
		int16: 256 * hi + lo		;--correct for byte
		if int16 > maxi [maxi: int16]
		if int16 < mini [mini: int16]
	]
	int: integer/box mini
	block/rs-append blk as red-value! int
	int: integer/box maxi
	block/rs-append blk as red-value! int  
]

;-- for tests
swapNibbles: routine [
	x 			[integer!]
	return:  	[integer!]	
][
    ((x and 0Fh) << 4) OR ((x and F0h) >> 4)
]

swap16: routine [
	x 			[integer!]
	return:  	[integer!]	
][
	((x AND 00FFh) << 8) OR ((x AND 00FFh) >> 8)
]

getSensor: function [
	bin		[binary!]
	isize	[integer!] ; 1, 2 or 4 for 8, 16 OR 32-bit values
][
	n: (length? bin) / isize
	i: 1
	while [i <= n][
		int: to-integer reverse copy/part bin isize
		print int
		bin: skip bin isize
		i: i + 1
	]
]
;--end tests

getTempInt16Values: routine [
"Convert binary data as 16-bit integer values"
	bin 			[binary!] 
	mat				[vector!]
	/local
	head tail 		[byte-ptr!] 
	lo hi			[byte!] 
	int16 			[integer!]
][
	vector/rs-clear mat
	head: binary/rs-head bin		;--byte pointer
	tail: binary/rs-tail bin		;--byte pointer
	while [head < tail][
		lo: head/value				;--low byte (OK)
		head: head + 1
		hi: head/value				;--high byte (OK)
		head: head + 1
		;int16: lo or (hi << 8)		;--16-bit integer value (OK for integer)
		int16: 256 * hi + lo		;--correct for byte
		vector/rs-append-int mat int16
	]
]

getGrayScale: routine [
"Get low byte value"
	bin 			[binary!]
	mat				[vector!]
	minV			[integer!]
	maxV			[integer!]
	/local
	head tail 		[byte-ptr!] 
	lo hi int16 	[integer!]
	int8			[integer!]
	f scale			[float!] 
][
	scale: as float! (maxV - minV)
	vector/rs-clear mat
	head: binary/rs-head bin				;--byte pointer
	tail: binary/rs-tail bin				;--byte pointer
	while [head < tail][
		lo: as integer! head/value			;--low byte (OK)
		head: head + 1
		hi: as integer! head/value			;--high byte (OK)
		head: head + 1
		int16: lo or (hi << 8)				;--16-bit integer value (OK)
		;--optris does not use all 16-bit range : we normalize
		f: as float! (int16  - minV)
		int8: as integer! (f / scale * 255.0);--normalize  0..255 range 
		loop 3 [vector/rs-append-int mat int8]	;--for a grayscale matrix
	]
]




getCelsius: routine [
"Int16 values to ° as float"
	mat		[vector!]
	minV	[integer!]	;--min integer value in ravi file
	maxV	[integer!]	;--max integer value in ravi file
	minT	[float!]	;--min ° temperature in ravi file
	maxT	[float!]	;--max ° temperature in ravi file 
	return:	[vector!]
	/local
	head 			[int-ptr!]
	int16  n i 		[integer!]
	f scalef ratio	[float!]
	celsius scale	[float!]	
 	s 				[series!]
 	x*				[red-vector!] 
 	px* 			[float-ptr!]
][
	n: vector/rs-length? mat
	scale: maxT - minT								;--integer scale
	scaleF: as float! (maxV - minV)					;--temperature scale as float
	head: as int-ptr! vector/rs-head mat			;--int16 matrix head
	x*: vector/make-at stack/push* n TYPE_FLOAT 8	;--create matrix as vector
	px*: as float-ptr! vector/rs-head x*			;--we use float values
	i: 1
	while [i <= n] [
		int16: vector/get-value-int head 4			;--get int16 value
		f: as float! (int16 - minV)					;--x - x1					
		ratio: f / scaleF * scale					;--/(x2-x1) *(y2-y1)
		celsius: minT + ratio						;--y: y1 + ((x-x1)/(x2-x1)*(y2-y1))
		px*/i: celsius
		head: head + 1
		i: i + 1
	]
	s: GET_BUFFER(x*)
	s/tail: as cell! (as float-ptr! s/offset) + n
	as red-vector! stack/set-last as cell! x* 	
]

makeColor: routine [
"Map temperature and  color scale"
	mat 				[vector!]	;--Float matrix
	map					[block!]
	img					[image!]
	minT				[float!]
	maxT				[float!]
	/local
	pixel				[subroutine!]
	h idx				[integer!]
	handle a r g b		[integer!] 
	f n scale rt n2		[float!]						
	head tail			[byte-ptr!]
	bHead ptr			[red-value!]
	t					[red-tuple!]
	pix					[int-ptr!]
][
	handle: 0
    pix: image/acquire-buffer img :handle
    h: block/rs-length? map 
	n: as float! vector/rs-length? mat
	n2: as float! h
	head: vector/rs-head mat
	tail: vector/rs-tail mat
	bhead: block/rs-head map
	scale: maxT - minT
	ptr: bhead
	pixel: [(a << 24) OR (r << 16 ) OR (g  << 8) OR b]
	while [head < tail] [
		f: vector/get-value-float head 8
		rt: maxT - f / scale
		idx: as integer! (n2 * rt)
		if idx = 0 [idx: 1]
		ptr: bhead + idx
		t: as red-tuple! ptr
		a: 0
		r: t/array1 and FFh 
		g: t/array1 and FF00h >> 8
		b: t/array1 and FF0000h >> 16 
		pix/value: FF000000h or pixel
		head: head + 8
		pix: pix + 1
	]
	image/release-buffer img handle yes
]

getHeatMap: routine [
"Map temperature and  color scale"
	mat 				[vector!]	;--integer matrix
	map					[block!]
	img					[image!]
	minT				[float!]
	maxT				[float!]
	/local
	pixel				[subroutine!]
	h idx				[integer!]
	handle  a r g b		[integer!] 
	int16				[integer!] 
	f n scale rt n2		[float!]						
	head tail			[byte-ptr!]
	bHead ptr			[red-value!]
	t					[red-tuple!]
	pix					[int-ptr!]
][
	handle: 0
    pix: image/acquire-buffer img :handle
    h: block/rs-length? map 
	n: as float! vector/rs-length? mat
	n2: as float! h
	head: vector/rs-head mat
	tail: vector/rs-tail mat
	bhead: block/rs-head map
	scale: maxT - minT
	ptr: bhead
	pixel: [(a << 24) OR (r << 16 ) OR (g  << 8) OR b]
	while [head < tail] [
		int16: vector/get-value-int as int-ptr! head 4
		f: as float! int16
		rt: maxT - f / scale
		idx: as integer! (n2 * rt)
		if idx = 0 [idx: 1]
		ptr: bhead + idx
		t: as red-tuple! ptr
		a: 0
		r: t/array1 and FFh 
		g: t/array1 and FF00h >> 8
		b: t/array1 and FF0000h >> 16 
		pix/value: FF000000h or pixel
		head: head + 4
		pix: pix + 1
	]
	image/release-buffer img handle yes
]





;--ATTENTION: These routines are zero-based

getBinAddress: routine [
"Address of binary data first value"
	bin		[binary!]
	return:	[integer!]
][
	as integer! binary/rs-head bin
]




;--if  we do not know the address of the first value
_getBinaryValue: routine [
	bin				[binary!]
	dataAddress 	[integer!] 
	dataSize 		[integer!] 
	return: 		[binary!]
	/local
	head			[byte-ptr!]
][
	head: binary/rs-head bin
	head: head + dataAddress
	as red-binary! stack/set-last as red-value! binary/load head dataSize
]

;--if we know the binary data address
getBinaryValue: routine [
	dataAddress 	[integer!] 
	dataSize 		[integer!] 
	return: 		[binary!]
][
	as red-binary! stack/set-last as red-value! binary/load as byte-ptr! dataAddress dataSize
]


