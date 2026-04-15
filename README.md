# Master-Thesis
Image analysis pipeline developed for the analysis of  biofilm snapshots and timelapses. Included are the detection of the biofilm, radial averaging of fluorescent channels, background subtraction, and plotting of the fluorescent intensities, ratios, maxima, and the integrals of the profiles.

It is crucial for all Fiji macros that the file names contain no spaces!

The images in my master thesis were created with these two Fiji macros: "Snapshot_Images_BD_RFP_YFP_FM-ratio.ijm", and "Timelapse_Images_BD_RFP_YFP_FM-ratio.ijm".

The "Snapshot" macro takes a folder of ".czi" files as an input, while the individual series/tile of the timelapse images have to be opened for the "Timelapse" macro.

Image processing was done in Fiji with these two macros: "Snapshot_image_processing.ijm", and "Timelapse_image_procesing.ijm". Image processing contains the biofim detection, by masking the image using the Phansalkar algorithm. The Phansalkar algorithm with the used paramters is optimised for the broadest application. It is capable of thresholding both wrinkled and smooth biofilms. The biofilm are detected usig a score-based system that accounts for the area, circularity, and proximity to the centre of the image.
After biofilm detection, a radial profile angle analysis is perforemd from whic the background fluorescence is subtracted. Finally, the images are saved. The radial profiles are saved as ".csv" files.

The "Snapshot" macro takes a folder of ".czi" files as an input, while the individual series/tile of the timelapse images have to be opened for the "Timelapse" macro.

All subsequent image analysis was done in a Jupyter Notebook, using a Python environment: "2026_04_15_Biofilm_Snapshot_and_Timelapse_Analysis.ipynb".

The beginning of the Jupyter Notebook is dedicated to the Snapshot image analysis. This includes an image analysis that plots the indivdual profiles for every ".csv. file in a folder. In the next cell, we plot the extrema of the fluorescence profiles and of the FM-ratio (more details in the Methods section of the thesis). Then we plot the integrals of the fluorescent profiles and their ratop psi.

The second part of the Jupyter Notebook is dedicated to the analysis of the timelapse images. Similar graphs can be created, but instead of plotting against concentration, we plot against time.

