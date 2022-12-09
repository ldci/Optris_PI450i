#!/usr/local/bin/red
Red [
	Title:   "Red and Optris Binary Files"
	Author:  "ldci"
	File: 	 %bbCry44.red
	Needs:	 View
]

;--Ffmpeg is  required  for large files
;--this version is for 16-bit unsigned integer (0..65535); only for new optris files 
;--this version is adaptated to long movies

OS: to-string system/platform

;--Adapt path to your system
home: select list-env "HOME"
if any [OS = "MSDOS" OS = "Windows"][home: select list-env "USERPROFILE"]
appDir: to-red-file rejoin [home "/Programmation/Red/BabyCry/code/"]

;appDir: system/options/path
tempDir: copy form  appDir
append tempDir "tmpffmpeg/"
dataDir: to-file tempDir
tempDir: copy form  appDir
append tempDir "results/"
resDir: to-file tempDir
if not exists? resDir [make-dir resDir]
change-dir appDir

;--we need a lot of librairies
#include %lib/optris/optrisriff.red
#include %lib/optris/optrisroutines.red
#include %lib/redCV/tools/rcvTools.red
#include %lib/redCV/core/rcvCore.red
#include %lib/redCV/matrix/rcvMatrix.red
#include %lib/redCV/imgproc/rcvImgProc.red
#include %lib/redCV/imgproc/rcvConvolutionImg.red
#include %lib/redCV/imgproc/rcvGaussian.red
#include %lib/redCV/imgproc/rcvImgEffect.red
#include %lib/redCV/imgproc/rcvColorSpace.red
#include %lib/redCV/math/rcvStats.red	

;--for test
knl: make vector! [
    	1.0 0.0 1.0 
    	0.0 1.0 0.0 
    	1.0 0.0 1.0
]

;--we can use predefined color maps 
palettes: [
	"Alarm_Red.png" 
	"Alarm_Green.png" 
	"Alarm_Blue.png" 
	"Blue_Hi.png" 
	"Gray_White_Cold.png" 
	"Gray_Black_Cold.png" 
	"Iron.png"
	"Iron_HI.png"
	"Rainbow_Medical.png" 
	"Rainbow.png"
	"Rainbow_HI.png" 
 ] 
 
 ;--anatomical points we process
 selectedPoints: [
 	36 
 	39
 	42 
 	45
 	29
 	30
 	31
 	32
 	34
 	35
 	48
 	54
 	58 
 	56
 ]
pointLabels: [ 
"CED"	;--Canthus externe droit 	[36]
"CID"	;--Canthus interne droit 	[39]
"CIG"	;--Canthus interne gauche 	[42]
"CEG"	;--Canthus externe gauche 	[45]
"NEH"	;--nez haut					[29]	
"NEP"	;--pointe nez 				[30]
"NED"	;--Nasal externe droit 		[31]
"NID"	;--Nasal interne droit 		[32]
"NIG"	;--Nasal interne gauche 	[34]
"NEG"	;--Nasal externe gauche 	[35]
"BED"	;--Bouche externe droit		[48]
"BEG"	;--Bouche externe gauche	[54]
"MID"	;--Menton interne droit 	[58]
"MIG"	;--Menton interne gauche 	[56]
]

 
 
fileList: copy []						;--for storing extracted images
imageSize: 382x289						;--default image size for PI-450i
imageSize2: 764x578
nbFrames: 0								;--number of frames								
optrisFile: none						;--optris ravi file
mapFile: "lib/maps/Iron.png"			;--default palette						
imgMap: load to-file mapFile			;--load default palette
colMap: []								;--color mapping block
matV: make vector!  [integer! 32 0]		;--for int16 matrix
matGS: make vector! [integer! 32 0]		;--low grayscale matrix
matRGB: make vector! [integer! 32 0]	;--colorimage matrix
minRange: -20							;--minimal optris range 
maxRange: 100							;--maximal optris range
minTemp: maxTemp: 0.0					;--minimal and maximal temperatures initialization
local: copy []							;--minimal and maximal values in raw data
fps: 1									;--frame by second
frate: to-time 1 / fps					;--frame rate	
currentImage: 1							;--first frame
isFile: false							;--binary file not yet loaded 
img1: make image! imageSize				;--we need a grayscale image
img0: make image! imageSize				;--we need a colored image
img2: make image! imageSize				;--we need a heat map image 
img3: make image! imageSize				;--for filters 
img4: make image! imageSize				;--for filters
img5: make image! imageSize				;--for filters
simg: make image! imageSize				;--source image for thresholding
dimg: make image! imageSize				;--destination image
mimg: make image! imageSize				;--mask image
rimg: make image! imageSize				;--final result image after thresholding
thresh: 1								;--for thresholding
fileName: ""							;--we need a string for ffmpeg
imageName1: ""							;--for python
acolor: green							;--default color
fLeft: 100								;--for dLib box
fTop: 50								;--for dLib box
fRight: 300								;--for dLib box
fBottom: 250							;--for dLib box
topLeft: 0x0							;--for draw
bottomRight: 300x250					;--for draw
dLib?: false							;--default value
resultFile:	%detectedPoints.txt			;--Landmarks values
skin?: false							;--for skin color detection
box?: false								;--for face rounding box
landmarks?: false						;--show landmarks
record?: false							;--record data ?
reading?: false							;--reading all the movie						
bin: #{}								;--optris binary values
tempData: copy []						;--store results
resultDataFile: %results.txt			;--in this file
radius: 2								;--landmarks
factor: 0.0								;--for Gaussian filter
kSize: 5x5								;--for Gaussian filter
coordinates: []							;--landmarks coordinates
tmpCoords: []							;--internal
ref: 0									;--temperature reference
clipSize: 30x30


; for Unicode string with images
makeUnicodeString: func [s [string!] c [char!] return: [string!]][
	rejoin [s form c]
]

s1: makeUnicodeString "" #"^(23EE)"		;--First frame
s2: makeUnicodeString "" #"^(23EA)"		;--Next frame
s3: makeUnicodeString "" #"^(23E9)"		;--Previous frame
s4: makeUnicodeString "" #"^(23ED)"		;--Last frame
s5: makeUnicodeString "" #"^(23EF)"		;--Play/Stop movie


;--Drawing functions
;--manual temperature pixel reader
drawCross: 	compose [
	line-width 1 
	pen (acolor) line 0x10 6x10 
	pen off pen (acolor) line 14x10 20x10
	pen (acolor) line 10x0 10x6 
	pen off pen (acolor) line 10x14 10x20
	line-width 3 box 0x0 20x20
]

;--external functions
;--Dlib python script: python3 required!
calldLib: does [
	coordinates: copy[]
	;clear pointsList/data
	plot: []
	info/text: "Calculating landmarks..."
	do-events/no-wait
	if get-current-dir <> appDir [change-dir appDir]
	prog: rejoin ["python FacePoints.py " to-local-file imageName1 " "  fLeft " " fTop " " fRight " " fBottom]
	ret: call/wait/console prog 
	either ret = 0 [msg: "OK"][msg: "Error"]
	info/text: rejoin["Landmarks detection: " msg]
	if ret = 0 [
		f: read/lines resultFile			;--read returned values
		str: split f/1 " "					;--get box coordinates
		fLeft: to-integer str/1				;--left
		fTop: to-integer str/2				;--top
		fRight: to-integer str/3			;--right
		fBottom: to-integer str/4			;--down
		topLeft: as-pair fLeft fTop			;--box coordinates as pair
		bottomRight: as-pair fRight fBottom	;--box coordinates as pair
		getPixelTemp						;--get frontal reference 
		;--draw  either box
		if box? [
			plot: compose [
				line-width 2
				pen (acolor)
				box (topLeft) (bottomRight)
			]
		]
		;--or draw landmarks
		if landmarks? [
			plot: compose [
				line-width 2
				pen (acolor)
				fill-pen (acolor)
			]
		]	
		;--or both
		if all [box? landmarks?][
			plot: compose [
				line-width 2
				pen (acolor)
				box (topLeft) (bottomRight)
				pen (acolor)
				fill-pen (acolor)
			]
				
		]
		;unless reading? [pointsList/data: f]
		;--if dLib is used then draw landmarks
		if dLib? [
			pointsList/data: f					;--update list
			i: 1 
			while [i <= (length? pointsList/data)] [
				str: split f/:i " "
				point: as-pair to-integer str/2 to-integer str/3
				if find selectedPoints i [append coordinates point] ;--store landmarks coordinates
				if landmarks? [
					append plot 'circle 
					append plot (point)
					append plot (radius)
				]
				i: i + 1
			]
		]
		canvas2/image: draw img2 plot
	]
]

;--we use a face rounding box for dLib call
updateFaceRect: does [
	fLeft: 		fRect/offset/x - canvas1/offset/x
	fTop:  		fRect/offset/y - canvas1/offset/Y
	fRight: 	fLeft + fRect/size/x
	fBottom: 	fTop + fRect/size/y
	if fLeft < 0 [fLeft: 0]
	if fTop < 0  [fTop: 0]
	if fRight > imageSize/x [fRight: imageSize/x]
	if fBottom > imageSize/y [fBottom: imageSize/y]
	faceBox/text: rejoin [form fLeft " " form " " fTop  " " form fRight " " form fBottom]
]

;--split ravi file into 16-bit images (yuyv422 or any 16-bit format)
;--Ffmpeg does not recognize .bin suffix, so we use .raw 
;--but images are in binary format
splitRavi: does [
print "Splitting ravi File"
	_dataDir: to-local-file dataDir ;--a string
	;--original macOS version
	str: copy rejoin [
		"ffmpeg -y -i '"  fileName "'"
		" -c copy -pix_fmt yuyv422" " " _dataDir "img_%05d.raw"
	]
	
	if any [OS = "MSDOS" OS = "Windows"][
		str: copy rejoin [
			"ffmpeg -y -i "  fileName
			" -c copy -pix_fmt yuyv422" " " _dataDir "img_%05d.raw"
		]
 	]
 	str
]

;--suppress temporary 16-bit images when we quit or for a new file
cleanDir: does [
	clear fileList
	d: read dataDir
	foreach v d [
		fn: rejoin [copy dataDir v]	
		if exists? fn [delete fn]
	]
	fn: none
]

;--get 16-bit images from the ravi file
getImages: does [
	cleanDir							;suppress previous images
	call/wait/console splitRavi 		;ffmpeg needs the console (CLI Mode)
	fileList: sort read dataDir			;read the result in order
]



;--read each extracted image as a 16-bit frame
readImage: func [idx [integer!]] [
	if isFile [
		bin: read/binary to-file rejoin [form dataDir fileList/(idx)]
		;--get synchro
		header: copy/part bin 126 ;--after values are 0
		lo: header/125
		hi: header/126
		synchro: 256 * hi + lo ;--16-bit
		bin: skip bin imgSize/x * 2							;--now skip first row
		minVi: 0 maxVi: 0								    ;--min max	
		getMinMax bin tblk: [minVi maxVi]					;--find min max values in image
		minVi: tblk/1										;--get min integer value 
		maxVi: tblk/2										;--get max integer value 
		tmpIntMin/text: form minVi							;--update face
		tmpIntMax/text: form maxVi							;--update face
		getTempInt16Values bin matV	 						;--store 16-bit values in matrix
		getGrayScale bin matGS tblk/1 tblk/2;minVi maxVi 	;--store low byte values in normalized matrix
		minTemp: to float! minVi
		maxTemp: to float! maxVi
		getHeatMap matV colMap img2 minTemp maxTemp			;--make heat map image
		img1/rgb: to-binary to-block matGS					;--make grayscale image
    	;rcvIR2RGB img2 img0 knl 1							;--test
		;rcvGS2RGB img1 img0								;--test					
		canvas1/image: img1									;--show GS image
		canvas2/image: img2									;--show heat map
		f2/text: form currentImage: idx						;--current image
		tmpCoords: []
	]
]
;--to show grayscale image
saveImages: does [
	imageName1: rejoin [form dataDir "gs.png"]
	save to-file imageName1 canvas1/image
]

clearData: does [
	clear tempData
	append tempData form minTemp
	append tempData form maxTemp
	str: rejoin ["image synchro ref "]
	foreach point pointLabels [append append str point " "]
	append tempData str
]

;--load optris file as binary and split images
loadBin: does [
	sb/text: ""
	clear pointsList/data
	clear coordinates
	clearData
	pg/data: 0%
	tmpf: request-file 
	unless none? tmpf[
		print "Load ravi File"
		canvas1/image: canvas2/image: none
		do-events/no-wait
		;--result file
		filePath: first split-path tmpf
		fName: second split-path tmpf
		n: length? fName
		nn: n - 4
		sName: to-string copy/part fName nn
		append sName "txt"
		resultDataFile: to-file rejoin [resDir sname]
		
		tmpPix/text: "_._"
		tmpPixMin/text:  tmpPixMax/text: tmpIntMin/text: tmpIntMax/text: "0.0"
		optrisFile: read/binary tmpf
		either assertRIFFFile optrisFile [
			print "Be patient! Reading ravi information..."
			sb/text: "Be patient! Reading ravi information..."
			do-events/no-wait
			getFileInfo optrisFile					;--INFOMETA tag in xml
			getFileHeader optrisFile				;--File Header
			getStreamHeader optrisFile				;--Stream header
			fps: getFrameRate optrisFile			;--get FPS
			nbFrames: aviMainHeader/dwTotalFrames	;--Frames number
			blk: getTempRange optrisFile			;--for temp range
			f1/text: rejoin [form nbFrames " frames"]
			f11/text: form imgSize: as-pair bitMapInfoHeader/biWidth bitMapInfoHeader/biHeight
			f111/text: rejoin  [form fps "  FPS"]	;--FPS
			frate: to-time 1 / fps					;--Frequency
			f112/text: form frate					;--Timer
			tmpPixMin/text: form minTemp: blk/3		;--minimal temperature value
			tmpPixMax/text: form maxTemp: blk/4		;--maximal temperature value
			img1: make image! imgSize				;--GS image
			img0: make image! imgSize				;--Colored image
			img2: make image! imgSize				;--Heat map image
			img3: make image! imgSize				;--Color image
			img4: make image! imgSize				;--Color image
			tempData: copy []						;--store results
			append tempData form minTemp
			append tempData form maxTemp
			str: rejoin ["image synchro ref "]
			foreach point pointLabels [append append str point " "]
			append tempData str
			;--create dataDir where images are
			tempDir: copy form  first split-path tmpf
			append tempDir "tmpffmpeg/"
			dataDir: to-file tempDir
			if not exists? dataDir [make-dir dataDir]
			fileName: form to-local-file tmpf			;--required for ffmpeg commands
			print "Be patient! Extracting frames..."
			sb/text: "Be patient! Extracting frames..."
			do-events/no-wait
			getImages
			isFile: true
			currentImage: 1
			processImage
			updateFaceRect
		] [alert "Non ravi file"]
	]
	if get-current-dir <> appDir [change-dir appDir]
]

;--read and show images, get temperatures and landmarks
processImage: does [
	if isFile [
		sb/text: rejoin ["Processing frame " form currentImage "/" form nbFrames]
		pg/data: to-percent currentImage / nbFrames
		do-events/no-wait
		readImage currentImage
		filterImage
		if factor > 1.0 [gaussianFilter]
		getPixelTemp
		meanStim/text: form synchro
		saveImages
		if dLib? [calldLib]
		if record? [
			str: rejoin [form currentImage " "  form synchro " " ref " "]
			foreach point coordinates [
				append append str form getPointTemp point " "
			]
			append tempData str
		]
	]
	sl/data: to-percent (currentImage / nbFrames)
]

;--apply filtering for a better face segmentation
;--do not modify source image and matrices values
;--just for visual control

filterImage: does [
	if isFile [
		simg: img1 ;canvas1/image ;
		rcvRChannel simg dimg 4					 ;--keep red channel
		rcvThreshold/binary dimg mimg thresh 255 ;--mask 0 or 255 according to thresh value
		rcvAnd simg mimg rimg					 ;--And source  and mask 
		canvas1/image: rimg						 ;--result
	]
]

;--Distribution of Gaussian Filter can be added to the previous filter
gaussianFilter: does [
	if isFile [
		img3: canvas1/image	; img1
		rcvDoGFilter img3 img4 kSize 1.0 2.0 factor
		rcvAnd img3 img4 img5
		canvas1/image: img5
	]
]



;--color mapping
makeColorMap: does [
	colMap: copy []
	n: imgMap/size/y - 1
	i: 0
	while [i < n][
		append colMap map/image/(i * imgMap/size/x + 1)
		i: i + 1
	]
]

;--Manual Pixel temperature reader for frontal zones
getPixelTemp: does [
	posct: p2/offset - canvas2/offset + 11
	if all [posct/x >= 0 posct/y >= 0 posct/x <= imageSize/x posct/y <= imageSize/y][
		idx: posct/y * imageSize/x + posct/x
		ref: form matV/:idx
		tmpPix/text: ref
	]
]

;landmarks temperature reader: returns raw value associated to the coordinate
getPointTemp: func [
	coord	[pair!]
][
	idx: coord/y * imageSize/x + coord/x
	matV/:idx	
]



;--Application main window
mainwin: layout [
	Title "ANR BabyCry [Optris PI-450i]"
	style rect: base 255.255.255.192 clipSize loose draw []
	space 5x5
	button "Load" [loadBin]
	f1:  field 150x25 left		;--Number of frames
	f11: field	90x25 center	;--Image size
	f111: field 60x25 center	;--FPS
	f112: field 100x25 center
	base 100x25 white "Palette"
	pad 5x0
	dp: drop-down 155 data palettes
	select 7
	on-change [
		if get-current-dir <> appDir [change-dir appDir]
		mapFile: rejoin ["lib/maps/" pick face/data face/selected]
		imgMap: load to-file mapFile
		map/image: imgMap
		makeColorMap
		processImage
	]
	
	pad 80x0 button "Quit" [
		sb/text: "Be patient! Cleaning data dir"
		do-events/no-wait
		if exists? datadir [cleanDir delete dataDir] quit
	]
	return
	text "Segmentation" 100 bold
	slt: slider 220 		[thresh: 1 + to-integer (face/data *  254)  
							tValue/text: form round/to to-float face/data 0.01
							processImage
							]
	tValue: field 50 "0.0"
	
	text "Gaussian filter" 100 bold slg: slider 220 [
		factor: round 1.0 + (face/data * 255.0)
		gValue/text: form factor 
		processImage
	] 
	gValue: field 50 "1.0"
	button "Points" [
		if isFile [
			dLib?: landmarks?: box?: true 
			processImage 
			append/only tmpCoords coordinates 
			dLib?: landmarks?: box?landmarks?: box?: false
			;--calculate mean coordinates
			nl: length? tmpCoords
			nc: length? coordinates
			repeat j nc [
				sigma: 0x0
				repeat i nl [sigma: sigma + tmpCoords/:i/:j]
				coordinates/:j: sigma / nl	
			]
		]
	]
	button "Clear" [clear coordinates clear tmpCoords] 
	return
	text 60 "Signal" bold 
	meanStim: field 80
	check "Call dLib library" 130 bold false [dLib?: face/data]
	check "Landmarks" false [
		landmarks?: face/data 
		unless landmarks? [clear info/text clear pointsList/data]
	]
	check "Box" 60 false [box?: face/data]
	pad 5x0
	
	check "Record Data" bold false [record?: face/data]
	button 65 "Clear" [clearData]
	button 65  "Save" [write/lines resultDataFile tempData info/text: "Data Saved"]
	return
	canvas1: base imageSize black 
	on-time [
		currentImage: currentImage + 1
		either currentImage <= nbFrames [processImage] [face/rate: none]
	]
	canvas2: base imageSize black
	map: base 25x289 imgMap
	pointsList: text-list 100x289
	return
	space 0x0
	text 30x30 font-size 20 s1 [currentImage: 1 processImage] 
	text 30x30 font-size 20 s2 [if currentImage > 1 [currentImage: currentImage - 1 processImage]]
	text 30x30 font-size 20 s3 [if currentImage < nbFrames [currentImage: currentImage + 1 processImage]]
	text 30x30 font-size 20 s4 [currentImage: nbFrames processImage]
	sl: slider 175  [
		currentImage: 1 + to-integer face/data * (nbFrames - 1)
		f2/text: form currentImage
		processImage
	]
	
	f2: field
	space 5x0
	text 30x30 font-size 20 s5 [
		if currentImage = 1 [currentImage: 0]
		either canvas1/rate <> none [canvas1/rate: none] [canvas1/rate: frate]
		either canvas1/rate = none [reading?: false][reading?: true]
	]

	;--Status bar
	sb: field 380 pg: progress 100
	return
	text 100 "Coordinates" faceBox: field 275 info: field 415
	
	;--int temperatures
	at canvas2/offset - 0x0   tmpIntMax: h4 black "0.0" center font-color acolor
	at canvas2/offset + 0x255 tmpIntMin: h4 black "0.0" center font-color acolor
	
	;--float temperatures
	at canvas2/offset + imageSize - 80x35 tmpPixMin: h4 black "0.0" center font-color acolor
	at as-pair canvas2/offset/x + 302  canvas2/offset/y  tmpPixMax: h4 black  "0.0" center font-color acolor
	at as-pair canvas2/offset/x + 152  canvas2/offset/y  tmpPix: h4 black "_._" center font-color acolor
	
	;--Temperature  reader
	at canvas2/offset + 10x30 p2: base 0.0.0.254 22x22 loose draw drawCross
	on-drag [getPixelTemp]
	
	;--Face box
	at canvas1/offset + 100x50
	fRect: base 200x200 255.0.0.192 loose on-drag [
		c/offset: fRect/offset + fRect/size
		updateFaceRect
	] 
	at (fRect/offset + fRect/size) 
	c: base 8x8 red loose on-drag [
		fRect/size: (c/offset - fRect/offset)
		updateFaceRect
	]
	
	do [makeColorMap canvas1/rate: none]
]
view mainWin


