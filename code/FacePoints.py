import sys
import dlib

#python3 FacePoints.py fileName left top right down (integer)
predictor_path = "shape_predictor_68_face_landmarks.dat"
f = faces_folder_path = sys.argv[1]
left = sys.argv[2]
top = sys.argv[3]
right = sys.argv[4]
down = sys.argv[5]
#print("Processing file: {}".format(f))
pointsFile = open("detectedPoints.txt", "w")
detector = dlib.get_frontal_face_detector()
predictor = dlib.shape_predictor(predictor_path)
#load image
img = dlib.load_grayscale_image(f)
#upsample the image 1 time for a better detection
detected = detector(img, 1)
#Only one face (0) in image
if len(detected) == 1:
	for k, d in enumerate(detected):
		left = d.left()
		top = d.top()
		right = d.right()
		down = d.bottom()
		
if len(detected) == 0: 
	d = dlib.rectangle(int(left), int(top), int(right), int(down))

# Get the landmarks/parts for the face in box d.
shape = predictor(img, d)
# write box coordinates
pointsFile.write("{} {} {} {}\n" .format(left, top, right, down))
# now write 68 points in file
for i in range (shape.num_parts):
	pointsFile.write("{} {} {}\n" .format(i, shape.part(i).x, shape.part(i).y))
pointsFile.close()
#print("Done")


	
            
