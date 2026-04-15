dir = getDirectory("Choose a folder containing .czi files"); //select the folder containing the .czi files. Check that parameters in the macro that select the files match the file names in the folder
list = getFileList(dir);
year = "2025";  //IMPORTANT: change the year the image was taken at
month = "12"; //IMPORTANT: change the month the image was taken at
day = "08"; // IMPORTANT: change the day the image was taken at
folder_date = "2025_12_03";
r_add = 200; //this is added to account for potential
outputName = year + "_" + month + "_" + day;
prefix = year + month + day + "_DR_"; // sometimes it is "_DR_", sometimes "_BS_DR_"
suffix = ".czi";

outputDir = "output path" + folder_date + "/" + outputName + "/"; //define an output path
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

        // Function to get the largest circular object in the image, ie the biofilm
        function getLargestCircularObject(imageName) {
            selectImage(imageName);
            run("Duplicate...", "title=Duplicate");
            selectImage("Duplicate");
            run("8-bit");

            // Local threshold for uneven background
            run("Gaussian Blur...", "sigma=4"); // introduce a gaussian blur before detecting the radius
   			run("Auto Local Threshold", "method=Phansalkar radius=650 parameter_1=0.25 parameter_2=0 white");
            
            
            

            //Analyse particles ->selects all regions that have been masked
            run("Set Measurements...", "area centroid center perimeter shape limit redirect=None decimal=3");
            run("Analyze Particles...", "size=1000000-Infinity circularity=0.0-1.00 show=Outlines clear summarize");
            
			//assign scores to all particles / potential biofilms. Highest score -> biofilm
            n = nResults;
            bestScore = 0;
            bestIndex = -1;

            getDimensions(width, height, channels, slices, frames);
            getPixelSize(unit, pixelWidth, pixelHeight, voxelDepth);

            xc = width / 2;
            yc = height / 2;
            if (width < height)
                minDim = width;
            else
                minDim = height;

            edge_margin = 400; // in pixels, distance from image edges within which the centre of the biofilm can't be

            for (j = 0; j < n; j++) {
                xm_obj = getResult("XM", j);
                ym_obj = getResult("YM", j);

                // Convert µm to pixels
                xm_pix = xm_obj / pixelWidth;
                ym_pix = ym_obj / pixelHeight;

                // Only consider objects safely within the frame 
                if (xm_pix >= edge_margin && xm_pix <= (width - edge_margin) &&
                    ym_pix >= edge_margin && ym_pix <= (height - edge_margin)) {

                    a = getResult("Area", j);
                    c = getResult("Circ.", j);

                    // Compute distance in um for centre weighting
                    dx = xm_obj - (xc * pixelWidth);
                    dy = ym_obj - (yc * pixelHeight);
                    dist = sqrt(dx*dx + dy*dy);
                    normalisedDist = dist / ((minDim * pixelWidth) / 2.0);
                    alpha = 20.0;
                    center_weight = exp(-alpha * normalisedDist * normalisedDist);
                    score = a * c * center_weight;

                    if (bestIndex == -1 || score > bestScore) {
                        bestScore = score;
                        bestIndex = j;
                    }
                }
                
            }

            if (bestIndex == -1) bestIndex = 0;
			//Extract the centre point and area of the biofilm
            xm = getResult("XM", bestIndex);
            ym = getResult("YM", bestIndex);
            Area = getResult("Area", bestIndex);

            run("Clear Results");
            close(); // Close duplicate image

            return newArray(xm, ym, Area);
            return Threshold;
        }

        // Process both channels
        obj1 = getLargestCircularObject(baseName + "-0003");

        radius1 = sqrt(obj1[2] / PI);

        xm = obj1[0];
        ym = obj1[1];
        Area = obj1[2];
        radius_um = radius1;

        getPixelSize(unit, pixelWidth, pixelHeight, voxelDepth);
        xm_pix = xm / pixelWidth;
        ym_pix = ym / pixelHeight;
        radius_pix = radius_um / pixelWidth + r_add;

        print("Selected radius_pix = " + radius_pix);
        print("Selected largest area = " + Area);
        print("x = " + xm_pix);
        print("y = " + ym_pix);
        
        //Radial profile angle analysis for both fluorescent channels

        // RED CHANNEL
        selectImage(baseName + "-0002");
        run("Radial Profile Angle",
            "x_center=" + xm_pix +
            " y_center=" + ym_pix +
            " radius=" + radius_pix +
            " starting_angle=0" +
            " integration_angle=180 ");
        wait(200);

        Plot.getValues(xpoints, ypoints);

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

        for (j = 0; j < ypoints.length; j++) {
            ypoints[j] = ypoints[j] - bg_r_mean;
            if (ypoints[j] < 0) ypoints[j] = 0;
        }

        filename = outputDir + baseName + "_RadialProfile_Angle_mCherry.csv";
        file = File.open(filename);
        print(file, "Distance,Intensity");
        for (j = 0; j < xpoints.length; j++) {
            print(file, xpoints[j] + "," + ypoints[j]);
        }
        File.close(file);

        // YELLOW CHANNEL
        selectImage(baseName + "-0003");
        run("Radial Profile Angle",
            "x_center=" + xm_pix +
            " y_center=" + ym_pix +
            " radius=" + radius_pix +
            " starting_angle=0" +
            " integration_angle=180 ");
        wait(200);

        Plot.getValues(xpoints, ypoints);

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

        for (j = 0; j < ypoints.length; j++) {
            ypoints[j] = ypoints[j] - bg_y_mean;
            if (ypoints[j] < 0) ypoints[j] = 0;
        }

        filename = outputDir + baseName + "_RadialProfile_Angle_YFP.csv";
        file = File.open(filename);
        print(file, "Distance,Intensity");
        for (j = 0; j < xpoints.length; j++) {
            print(file, xpoints[j] + "," + ypoints[j]);
        }
        File.close(file);
        
        //Also run the RPA analysis over the thresholded image (Mask)
        selectImage(baseName + "-0003");
        run("Duplicate...", "title=Threshold");
        selectImage("Threshold");
        run("8-bit");

        run("Gaussian Blur...", "sigma=4"); // introduce a gaussian blur before detecting the radius
   		
   		run("Auto Local Threshold", "method=Phansalkar radius=650 parameter_1=0.25 parameter_2=0 white");
        
        // RPA for the Mask
        run("Radial Profile Angle",
            "x_center=" + xm_pix +
            " y_center=" + ym_pix +
            " radius=" + radius_pix +
            " starting_angle=0" +
            " integration_angle=180 ");
        wait(200);
        //waitForUser;

        Plot.getValues(xpoints, ypoints);

        filename = outputDir + baseName + "_RadialProfile_Angle_Threshold.csv";
        file = File.open(filename);
        print(file, "Distance,Intensity");
        for (j = 0; j < xpoints.length; j++) {
            print(file, xpoints[j] + "," + ypoints[j]);
        }
        File.close(file);

        // save Images

		//YFP image
        selectImage(baseName + "-0003");
        run("Duplicate...", baseName + "-0003_copy");
        run("Enhance Contrast", "saturation=0.35");
        run("Scale Bar...", "width=5000 height=30 font=28 color=White background=None location=[Lower Right]");
        saveAs("Jpeg", outputDir + baseName + "-YFP.jpg");
        //RFP image
        selectImage(baseName + "-0002");
        run("Duplicate...", baseName + "-0002_copy");
        run("Enhance Contrast", "saturation=0.35");
        run("Scale Bar...", "width=5000 height=30 font=28 color=White background=None location=[Lower Right]");
        saveAs("Jpeg", outputDir + baseName + "-mCherry.jpg");
		//brightfield image
        selectImage(baseName + "-0001");
        run("Duplicate...", baseName + "-0001_copy");
        run("Enhance Contrast", "saturation=0.50");
        run("8-bit");
		run("Scale Bar...", "width=5000 height=30 font=28 color=White background=None location=[Lower Right]");
        saveAs("Jpeg", outputDir + baseName + "-brightfield.jpg");
        
        //FM-ratio
        selectImage(baseName + "-0003");
        run("Duplicate...", "title=" + baseName + "-0003_copy2");
        run("Subtract...","value=" + 1.5 * bg_y_mean);
        selectImage(baseName + "-0003_copy2");
		run("8-bit");
		run("Add...", "value=1");

        selectImage(baseName + "-0002");
        run("Duplicate...", "title=" + baseName + "-0002_copy2");
        run("Subtract...","value=" + 1.5 * bg_r_mean);
        selectImage(baseName + "-0002_copy2");
		run("8-bit");
		run("Add...", "value=1");

        imageCalculator("Divide create 8-bit", baseName + "-0003_copy2", baseName + "-0002_copy2");
        run("Green");
        run("8-bit");
        run("Enhance Contrast", "saturation=0.50");
        run("Scale Bar...", "width=5000 height=30 font=28 color=White background=None location=[Lower Right]");
        saveAs("Jpeg", outputDir + baseName + "-Ratio.jpg");
        

        
        //Composite of the fluorescent images
        run("Merge Channels...", "c1=" + baseName + "-0002 c2=" + baseName + "-0003 create");
        run("Scale Bar...", "width=5000 height=10 font=28 color=White background=None location=[Lower Right]");
        saveAs("Jpeg", outputDir + baseName + "-Composite.jpg");

        // Close all images
        run("Close All");
    }
}
