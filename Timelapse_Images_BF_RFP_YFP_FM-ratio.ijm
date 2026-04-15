
name = "2xGlu_1_3610_DR" //name of the time-lapse series
date = "2026_02_26" //date of the time-lapse
outputDir = "path" + name + "/"; //define the folder the data is supposed to be saved in
baseName = date + "_BS_DR_timelapse_" + name;     // prefix used in filenames

// Ensure directory exists
File.makeDirectory(outputDir);

// Get currently open hyperstack
title = getTitle();
print("Title = " + title);

// Split hyperstack into channels
run("Split Channels"); 
// produced: title + " (c1)", " (c2)", " (c3)"

bfName  = "C1-" + title;
//run("Enhance Contrast", "saturation=0.35");
mChName = "C2-" + title;
run("Red");
yfpName = "C3-" + title;
run("Yellow");

selectImage(bfName);
getDimensions(w, h, channels, slices, frames);

 //Create stacks to collect movie frames
run("Select None");
newImage("BF_movie", "8-bit", w, h, frames);
newImage("mCh_movie", "RGB red", w, h, frames);

newImage("YFP_movie", "RGB yellow", w, h, frames);

newImage("Composite_movie", "RGB", w, h, frames);

newImage("Ratio_movie", "8-bit", w, h, frames);

//Make the ROI before starting with the analysis, the issue might be the detection of the width and height. Now it works if I define the width and hight of the roi in advance
//THIS WILL ONLY WORK IF THE IMAGES DO NOT CHANGE DIMENSIONS
//getDimensions(width, height, channels, slices);
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


for (t = 1; t <= frames; t++) {  //changed the frame to have all the data

    print("Processing timepoint " + t + " / " + frames);
    
    //make duplicates of the specific slice I am currently looking at
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
    selectImage(mChName);
    run("Duplicate...", "title=TMP_mCh_slice3");
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
    wait(50);
    
   
    
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
	
    bg_r_mean = getResult("Mean", nResults - 1);
    print("mCherry mean = " + bg_r_mean);
    run("Clear Results");
    
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
    bg_y_mean = getResult("Mean", nResults - 1);
    print("yfp mean = " + bg_y_mean);
    run("Clear Results");
   
        // BF timelapse
	selectImage("TMP_bf_slice2"); 
	run("Enhance Contrast", "saturation=0.1 normalize");
	run("Multiply...", "value=1");
	run("Scale Bar...", "width=5000 height=30 color=White background=None location=[Lower Right] hide");
	run("Copy");
	selectImage("BF_movie"); 
	setSlice(t); 
	run("Paste");

	// mCherry timelapse
	selectImage("TMP_mCh_slice2"); 
	run("Subtract...","value=" + 1 * bg_r_mean);
	run("Enhance Contrast", "saturation=0.1 normalize");
	run("Scale Bar...", "width=5000 height=30 color=White background=None location=[Lower Right] hide");
	run("Copy");
	//run("Scale Bar...", "width=5000 height=10 font=28 color=White background=None location=[Lower Right]");
	selectImage("mCh_movie"); 
	setSlice(t); 
	run("Paste");

	// YFP timelapse
	selectImage("TMP_yfp_slice2"); 
	run("Subtract...","value=" + 1 * bg_y_mean);
	run("Enhance Contrast", "saturation=0.1 normalize");
	run("Scale Bar...", "width=5000 height=30 color=White background=None location=[Lower Right] hide");
	run("Copy");
	//run("Scale Bar...", "width=5000 height=10 font=28 color=White background=None location=[Lower Right]");
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
	run("Scale Bar...", "width=5000 height=30 color=White background=None location=[Lower Right] hide");
	selectImage("Composite_movie"); 
	setSlice(t); 
	run("Paste");
	close("Composite");
	
	
	selectImage("TMP_yfp_slice3");
    run("Duplicate...", "title=" + "TMP_yfp_slice3_copy2");
    run("Subtract...","value=" + 1.5 * bg_y_mean);
    selectImage("TMP_yfp_slice3_copy2");
    run("8-bit");
	run("Add...", "value=1");
        //run("Enhance Contrast", "saturation=0.50");
    selectImage("TMP_mCh_slice3");
    run("Duplicate...", "title=" + "TMP_mCh_slice3_copy2");
    run("Subtract...","value=" + 1.5 * bg_r_mean);
    selectImage("TMP_mCh_slice3_copy2");
	run("8-bit");
	run("Add...", "value=1");
        //run("Enhance Contrast", "saturation=0.50");
    imageCalculator("Divide create 32-bit", "TMP_yfp_slice3_copy2","TMP_mCh_slice3_copy2");
    run("Green");
    run("8-bit");
    //run("Enhance Contrast", "saturation=0.50 normalize");
    run("Multiply...", "value=1");
    run("Scale Bar...", "width=5000 height=30 color=White background=None location=[Lower Right] hide");
    run("Copy");
	//run("Scale Bar...", "width=5000 height=10 font=28 color=White background=None location=[Lower Right]");
	selectImage("Ratio_movie"); 
	setSlice(t); 
	run("Paste");
        
	if (t == 1 || t == 47  || t == 57  || t == 67 || t == 90 || t == 108 || t == 144) {
		selectImage("TMP_bf_slice2"); 
		saveAs("JPEG", outputDir + baseName + "_BF_" + t + ".jpg");
		selectImage("TMP_yfp_slice2");
		saveAs("JPEG", outputDir + baseName + "_YFP_" + t + ".jpg");
		selectImage("TMP_mCh_slice2"); 
		saveAs("JPEG", outputDir + baseName + "_RFP_" + t + ".jpg");
		selectImage("Result of TMP_yfp_slice3_copy2"); 
		saveAs("JPEG", outputDir + baseName + "_Ratio_" + t + ".jpg");
		
	}


    close("TMP_bf_slice");
    close("TMP_mCh_slice");
    close("TMP_yfp_slice");
    close("TMP_bf_slice2");
    close("TMP_mCh_slice2");
    close("TMP_yfp_slice2");
    close("Composite (RGB)");
    close("TMP_mCh_slice3");
    close("TMP_yfp_slice3");    
    close("TMP_mCh_slice3_copy2");
    close("TMP_yfp_slice3_copy2");  
    close("Result of TMP_yfp_slice3_copy2");
    
    
} 
selectImage("BF_movie"); 
saveAs("AVI", outputDir + baseName + "_BF.avi");
selectImage("mCh_movie"); 
saveAs("AVI", outputDir + baseName + "_mCherry.avi");
selectImage("YFP_movie"); 
saveAs("AVI", outputDir + baseName + "_YFP.avi");
selectImage("Composite_movie"); 
saveAs("AVI", outputDir + baseName + "_Composite.avi");
selectImage("Ratio_movie"); 
saveAs("AVI", outputDir + baseName + "_Ratio.avi");

selectImage("BF_movie"); 
saveAs("TIF", outputDir + baseName + "_BF.tif");
selectImage("mCh_movie"); 
saveAs("TIF", outputDir + baseName + "_mCherry.tif");
selectImage("YFP_movie"); 
saveAs("TIF", outputDir + baseName + "_YFP.tif");
selectImage("Composite_movie"); 
saveAs("TIF", outputDir + baseName + "_Composite.tif");
selectImage("Ratio_movie"); 
saveAs("TIF", outputDir + baseName + "_Ratio.tif");

print("All done.");
