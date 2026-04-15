dir = getDirectory("Choose a folder containing .czi files");
list = getFileList(dir);
year = "2025"; //IMPORTANT: change the year the image was taken at
month = "12"; //IMPORTANT: change the month the image was taken at
day = "08"; // IMPORTANT: change the day the image was taken at
folder_date = "2025_12_03"; //date the images were taken at
r_add = 200; //this is added to account for potential
outputName = year + "_" + month + "_" + day;
prefix = year + month + day + "_BS_DR_"; // sometimes it is "_DR_", sometimes "_BS_DR_"
suffix = ".czi"; //Zeiss microscope file format

outputDir = "output_path" + folder_date + "/" + outputName + "/"; //change the output path
File.makeDirectory(outputDir);

fileList = getFileList(dir);

for (i = 0; i < fileList.length; i++) {
    filename = fileList[i];
    if (startsWith(filename, prefix) && endsWith(filename, suffix)) {

        fullInputPath = dir + filename;

        // Open file
        run("Bio-Formats Importer",
            "open=[" + fullInputPath + "] color_mode=Default view=Hyperstack stack_order=XYCZT autoscale");

        baseName = replace(filename, ".czi", "");
        run("Stack to Images");

        // Select channels and apply colour
        selectImage(baseName + "-0002");
        run("Red");
        selectImage(baseName + "-0003");
        run("Yellow");

        // RED CHANNEL
        selectImage(baseName + "-0002");
        getDimensions(width, height, channels, slices, frames);
        bg_w = 50; bg_h = height;
        if (bg_w > width) bg_w = width;
        if (bg_h > height) bg_h = height;
        bg_x = width - bg_w - 100; bg_y = 0;
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

		// Measure combined ROI
		run("Set Measurements...", "mean redirect=None decimal=6");
		roiManager("Measure");
        bg_r_mean = getResult("Mean", nResults - 1);
        print("mCherry mean = " + bg_r_mean);
        run("Clear Results");

        // YELLOW CHANNEL
        selectImage(baseName + "-0003");
        getDimensions(width, height, channels, slices, frames);
        bg_w = 50; bg_h = height;
        if (bg_w > width) bg_w = width;
        if (bg_h > height) bg_h = height;
        bg_x = width - bg_w - 100; bg_y = 0;
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

		// Measure combined ROI
		run("Set Measurements...", "mean redirect=None decimal=6");
		roiManager("Measure");
        bg_y_mean = getResult("Mean", nResults - 1);
        print("YFP Mean = " + bg_y_mean);
        run("Clear Results");


        // save Images
        //run("Set Scale...", "distance=5000 known=5 unit=mm");
        selectImage(baseName + "-0003");
        run("Duplicate...", baseName + "-0003_copy");
        run("Subtract...","value=" + 1 * bg_y_mean);
        run("Enhance Contrast", "saturation=0.1 normalize");
		run("Multiply...", "value=1");
		run("Scale Bar...", "width=5000 height=30 color=White background=None location=[Lower Right] hide");
        saveAs("Jpeg", outputDir + baseName + "-YFP.jpg");
        
        selectImage(baseName + "-0002");
        run("Duplicate...", baseName + "-0002_copy");
        run("Subtract...","value=" + 1 * bg_r_mean);
        run("Enhance Contrast", "saturation=0.1 normalize");
		run("Scale Bar...", "width=5000 height=30 color=White background=None location=[Lower Right] hide");
        saveAs("Jpeg", outputDir + baseName + "-mCherry.jpg");

        selectImage(baseName + "-0001");
        run("Duplicate...", baseName + "-0001_copy");
        run("8-bit");
        run("Enhance Contrast", "saturation=0.1 normalize");
		run("Multiply...", "value=1");
		run("Scale Bar...", "width=5000 height=30 color=White background=None location=[Lower Right] hide");
        saveAs("Jpeg", outputDir + baseName + "-brightfield.jpg");
        
        
        selectImage(baseName + "-0003");
        run("Duplicate...", "title=" + baseName + "-0003_copy2");
        run("Subtract...","value=" + 1.5 * bg_y_mean);
        selectImage(baseName + "-0003_copy2");
		run("8-bit");
		run("Add...", "value=1");
        //run("Enhance Contrast", "saturation=0.50");
        selectImage(baseName + "-0002");
        run("Duplicate...", "title=" + baseName + "-0002_copy2");
        run("Subtract...","value=" + 1.5 * bg_r_mean);
        selectImage(baseName + "-0002_copy2");
		run("8-bit");
		run("Add...", "value=1");
        //run("Enhance Contrast", "saturation=0.50");
        imageCalculator("Divide create 32-bit", baseName + "-0003_copy2", baseName + "-0002_copy2");
        run("Green");
        run("8-bit");
        //run("Enhance Contrast", "saturation=0.50");
        run("Multiply...", "value=1");
        run("Scale Bar...", "width=5000 height=30 color=White background=None location=[Lower Right] hide");
        saveAs("Jpeg", outputDir + baseName + "-Ratio.jpg");
        

    
        
        run("Merge Channels...", "c1=" + baseName + "-0002 c2=" + baseName + "-0003 create");
        run("Scale Bar...", "width=5000 height=30 color=White background=None location=[Lower Right] hide");
        saveAs("Jpeg", outputDir + baseName + "-Composite.jpg");

        // Close all images
        run("Close All");
    }
}
