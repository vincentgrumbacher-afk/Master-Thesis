//open the image and the series beforehand
r_add = 200;  //the radius added to the biofilm radius in the RPA to account for potential irregularities in the mask

name = "1xGlu_1" //name of the series/tile
date = "2026_01_21" //date of the timelapse
outputDir = "output path" + date + "_timelapse/" + name + "/"; //define the output direction
baseName = date + "_BS_DR_timelapse_" + name;     // prefix used in filenames

// Ensure directory exists
File.makeDirectory(outputDir);

// Get currently open hyperstack
title = getTitle();
print("Title = " + title);

// Split hyperstack into channels
run("Split Channels"); 

//rename the channels
bfName  = "C1-" + title;
run("Enhance Contrast", "saturation=0.35"); //Threshold the image for added visibility
mChName = "C2-" + title;
run("Red");
yfpName = "C3-" + title;
run("Yellow");

selectImage(bfName);
getDimensions(w, h, channels, slices, frames);

 //Create stacks to collect movie frames
run("Select None");
newImage("BF_movie", "RGB black", w, h, frames);
newImage("mCh_movie", "RGB red", w, h, frames);

newImage("YFP_movie", "RGB yellow", w, h, frames);



newImage("Composite_movie", "RGB", w, h, frames);

//Make the ROI for background subtraction before starting with the analysis
bg_w = 50; bg_h = h;
if (bg_w > w) bg_w = w;
if (bg_h > h) bg_h = h;
bg_x = w - bg_w - 100; bg_y = 0;
bg_x2 = 100; bg_y2 = 0;
roiManager("Reset");

// ROI 1
makeRectangle(bg_x, bg_y, bg_w, bg_h);
roiManager("Add");

// ROI 2
makeRectangle(bg_x2, bg_y2, bg_w, bg_h);
roiManager("Add");

// Combine the rectangles into one area
roiManager("Combine");

// Function: detect largest circular object
function getLargestCircularObject() {

    // Duplicate the current slice of the selected image
    run("Duplicate...", "title=TMP");
    selectImage("TMP");

    run("8-bit");
    
    //Create a mask of the biofilm
    run("Gaussian Blur...", "sigma=4"); // introduce a gaussian blur before detecting the radius, was 4
    run("Auto Local Threshold", "method=Phansalkar radius=650 parameter_1=0.25 parameter_2=0 white"); //Brensen did work at the beginning but fails for later images
	
	//detect all masked objects, including the biofilm
    run("Set Measurements...", "area centroid center perimeter shape limit redirect=None decimal=3");
    run("Analyze Particles...", "size=1000000-Infinity circularity=0.0-1.00 show=Outlines clear summarize");

	//score all masked objects. The biofilm will have the highest score
    n = nResults;
    getDimensions(width, height, c, s, f);

    if (n == 0) {
        print("No object found. Using image center.");
        run("Clear Results");
        close("TMP"); // close TMP
        return newArray(width/2, height/2, PI*100*100);
    }

    getPixelSize(unit, pw, ph, vd);
    
    xc = width/2;
    yc = height/2;

    if (width < height)
        minDim = width;
    else
        minDim = height;

    bestIndex = -1;
    bestScore = -1;
    edge_margin = 400; //the biofilm does not have its centre close to the boundary of the image. Removes potential noise from the edge of the image

    for (i = 0; i < n; i++) {
        xm = getResult("XM", i);
        ym = getResult("YM", i);

        xm_pix = xm/pw;  
        ym_pix = ym/ph;

        if (xm_pix < edge_margin || xm_pix > width-edge_margin) continue;
        if (ym_pix < edge_margin || ym_pix > height-edge_margin) continue;

        area = getResult("Area", i);
        circ = getResult("Circ.", i);

        dx = xm - xc*pw;
        dy = ym - yc*ph;
        dist = sqrt(dx*dx + dy*dy); //distance from the centre of the image
        norm = dist / ((minDim*pw)/2.0);

        alpha = 20;
        center_weight = exp(-alpha*norm*norm); //we expect the biofilm close to the centre of the image

        score = area*circ*center_weight; //weighed by area of the object, the circularity, and by the distance from the centre. Large area, roundness, and closeness to the centre increases the score

        if (score > bestScore) {
            bestScore = score;
            bestIndex = i;
        }
    }

    if (bestIndex < 0) bestIndex = 0;

	// dimensions of the biofilm
    xm = getResult("XM", bestIndex);
    ym = getResult("YM", bestIndex);
    area = getResult("Area", bestIndex);

    run("Clear Results");
    close(); // TMP is closed here

    return newArray(xm, ym, area);
}

// Detect the centre of the biofilm on frame 1. This will be the centre for all subsequent analysis

// CENTER DETECTION ON YFP
//selectImage(bfName); //change it here to change betweeen bf and yfp
selectImage(yfpName);
setSlice(1); // important: set the correct slice
obj = getLargestCircularObject();
close("TMP"); //check that TMP is really closed
xm_0 = obj[0]; 
ym_0 = obj[1];
area_0 = obj[2];

getPixelSize(unit, pw, ph, vd);
radius_0_um = sqrt(area_0/PI);
radius_0_pix = radius_0_um/pw + r_add;

xm_0_pix = xm_0/pw;
ym_0_pix = ym_0/ph;
    
print("xm_0 = " + xm_0_pix);
print("ym_0 = " + ym_0_pix);
print("radius_0= " + radius_0_pix);

for (t = 1; t <= frames; t++) {  //for loop to go through all of the timepoints in the timelapse

    print("Processing timepoint " + t + " / " + frames);

    // CENTER DETECTION ON YFP
    //selectImage(bfName); //change it here to change betweeen bf and yfp
    selectImage(yfpName);
    setSlice(t); // important: set the correct slice
    obj = getLargestCircularObject();
    close("TMP"); //check that TMP is really closed

    xm = obj[0]; 
    ym = obj[1];
    area = obj[2];

    getPixelSize(unit, pw, ph, vd);
    radius_um = sqrt(area/PI);
    radius_pix = radius_um/pw + r_add;

    xm_pix = xm/pw;
    ym_pix = ym/ph;
    
    
    print("xm = " + xm_pix);
    print("ym = " + ym_pix);
    print("radius= " + radius_pix);
    
    //show the differnece between the centre points
    d_xm = xm_pix - xm_0_pix;
    d_ym = ym_pix - ym_0_pix;
    print("difference xm - xm_0 = " + d_xm);
    print("difference ym - ym_0 = " + d_ym);
    //we use the centre point from frame 1 for all frames
    
    
    
    //make duplicates of the channels
    selectImage(bfName);
    setSlice(t);
    run("Duplicate...", "title=TMP_bf_slice");
    run("8-bit");
    selectImage(bfName);
    run("Duplicate...", "title=TMP_bf_slice2");
    run("8-bit");
    
    selectImage(mChName);
    setSlice(t);
    run("Duplicate...", "title=TMP_mCh_slice");
    run("8-bit");
    selectImage(mChName);
    run("Duplicate...", "title=TMP_mCh_slice2");
    run("8-bit");
    run("Red");
    
    selectImage(yfpName);
    setSlice(t);
    run("Duplicate...", "title=TMP_yfp_slice");
    run("8-bit");
    selectImage(yfpName);
    run("Duplicate...", "title=TMP_yfp_slice2");
    run("8-bit");
    run("Yellow");
    selectImage(yfpName);
    run("Duplicate...", "title=TMP_yfp_slice3");
    run("8-bit");
    
    
    
    
    wait(50); //to prevent an error due to the duplication of the images taking longer than the next steps
    
    //RPA for all of the channels
    //RFP
    selectImage("TMP_mCh_slice");
    run("Radial Profile Angle",
         "x_center=" + xm_0_pix +
         " y_center=" + ym_0_pix +
         " radius=" + radius_pix +
         " starting_angle=0" +
         " integration_angle=180 ");
    wait(100); //allows the plot to open
    Plot.getValues(xpoints, ypoints); //radial profile plot
    
    //Background subtraction
	selectImage("TMP_mCh_slice");
	roiManager("Reset");

	// ROI 1
	makeRectangle(bg_x, bg_y, bg_w, bg_h);
	roiManager("Add");

	// ROI 2
	makeRectangle(bg_x2, bg_y2, bg_w, bg_h);
	roiManager("Add");

	// Combine the rectangles into one area
	roiManager("Combine");
	// Measure combined ROI
	run("Set Measurements...", "mean redirect=None decimal=6");
	roiManager("Measure");
	
    bg_mean = getResult("Mean", nResults - 1);
    print("mCherry background mean = " + bg_mean);
    run("Clear Results");
    


    for (j = 0; j < ypoints.length; j++) {
        ypoints[j] = ypoints[j] - bg_mean;
        if (ypoints[j] < 0) ypoints[j] = 0;
    }

    
    filename = outputDir + baseName + "_RadialProfile_Angle_mCherry_" + t + ".csv";
    file = File.open(filename);
    print(file, "Distance,Intensity");
    for (j = 0; j < xpoints.length; j++) {
        print(file, xpoints[j] + "," + ypoints[j]);
    }
    File.close(file);
    

        
   

     //YFP   
    selectImage("TMP_yfp_slice");
    run("Radial Profile Angle",
         "x_center=" + xm_0_pix +
         " y_center=" + ym_0_pix +
         " radius=" + radius_pix +
         " starting_angle=0" +
         " integration_angle=180 ");
    wait(50);
        //waitForUser;
    Plot.getValues(xpoints, ypoints);
    
    //Baqckground subtraction
    selectImage("TMP_yfp_slice");
    roiManager("Reset");

	// ROI 1
	makeRectangle(bg_x, bg_y, bg_w, bg_h);
	roiManager("Add");

	// ROI 2
	makeRectangle(bg_x2, bg_y2, bg_w, bg_h);
	roiManager("Add");

	// Combine the rectangles into one area
	roiManager("Combine");
    
    // Measure combined ROI
	run("Set Measurements...", "mean redirect=None decimal=6");
	roiManager("Measure");
    bg_mean = getResult("Mean", nResults - 1);
    print("yfp background mean = " + bg_mean);
    run("Clear Results");
    


    for (j = 0; j < ypoints.length; j++) {
        ypoints[j] = ypoints[j] - bg_mean;
        if (ypoints[j] < 0) ypoints[j] = 0;
    }

    
    
    filename = outputDir + baseName + "_RadialProfile_Angle_YFP_" + t + ".csv";
    file = File.open(filename);
    print(file, "Distance,Intensity");
    for (j = 0; j < xpoints.length; j++) {
        print(file, xpoints[j] + "," + ypoints[j]);
    }
    File.close(file);
    

    
    
    //RPA for the mask
    //selectImage("TMP_bf_slice");
    selectImage("TMP_yfp_slice3");
    run("Gaussian Blur...", "sigma=4"); //run gaussian blur to improve the thresholding
    
    run("Auto Local Threshold", "method=Phansalkar radius=650 parameter_1=0.25 parameter_2=0 white"); 
    //waitForUser;


    run("Radial Profile Angle",
         "x_center=" + xm_0_pix +
         " y_center=" + ym_0_pix +
         " radius=" + radius_pix +
         " starting_angle=0" +
         " integration_angle=180 ");
    wait(50);
    //waitForUser;
    Plot.getValues(xpoints, ypoints);
    filename = outputDir + baseName + "_RadialProfile_Angle_Threshold_" + t + ".csv";
    file = File.open(filename);
    print(file, "Distance,Intensity");
    for (j = 0; j < xpoints.length; j++) {
        print(file, xpoints[j] + "," + ypoints[j]);
    }
    File.close(file);
    close("TMP_yfp_slice3");

    
    
    
    
    // BF timelapse
	selectImage("TMP_bf_slice2"); 
	run("Enhance Contrast", "saturation=0.35");
	run("Scale Bar...", "width=5000 height=10 font=28 color=White background=None location=[Lower Right]");
	run("Copy");
	selectImage("BF_movie"); 
	setSlice(t); 
	run("Paste");

	// mCherry timelapse
	selectImage("TMP_mCh_slice2"); 
	run("Enhance Contrast", "saturation=0.1");
	run("Scale Bar...", "width=5000 height=10 font=28 color=White background=None location=[Lower Right]");
	run("Copy");
	
	selectImage("mCh_movie"); 
	setSlice(t); 
	run("Paste");

	// YFP timelapse
	selectImage("TMP_yfp_slice2"); 
	run("Enhance Contrast", "saturation=0.1");
	run("Scale Bar...", "width=5000 height=10 font=28 color=White background=None location=[Lower Right]");
	run("Copy");
	
	selectImage("YFP_movie"); 
	setSlice(t); 
	run("Paste");
	
	// Composite
	// merge grayscale channels into RGB composite correctly
	run("Merge Channels...", "c1=[TMP_mCh_slice2] c2=[TMP_yfp_slice2] create keep");
	selectImage("Composite"); 
	run("Make Composite");      // ensures it’s a composite
	run("RGB Color");  
	run("Copy");
	run("Scale Bar...", "width=5000 height=10 font=28 color=White background=None location=[Lower Right]");
	selectImage("Composite_movie"); 
	setSlice(t); 
	run("Paste");
	close("Composite");


    close("TMP_bf_slice");
    close("TMP_mCh_slice");
    close("TMP_yfp_slice");
    //close("TMP_cfp_slice");
    close("TMP_bf_slice2");
    close("TMP_mCh_slice2");
    close("TMP_yfp_slice2");
    //close("TMP_cfp_slice2");
    close("Composite (RGB)");
    
    
    
} 
//save the timelapses as movies
selectImage("BF_movie"); 

saveAs("AVI", outputDir + baseName + "_BF.avi");
selectImage("mCh_movie"); 
saveAs("AVI", outputDir + baseName + "_mCherry.avi");
selectImage("YFP_movie"); 
saveAs("AVI", outputDir + baseName + "_YFP.avi");

selectImage("Composite_movie"); 
saveAs("AVI", outputDir + baseName + "_Composite.avi");

print("All done.");
