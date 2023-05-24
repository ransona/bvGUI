function build_image_set()

image_folder = 'C:\Users\lab\Pictures\catset';
images_per_experiment = 2;

% variables
expData.vars = 'width=30; height=30; x=0; y=0; loop=1; speed=30; onset=0; duration=2';
expData.iti = 1;
expData.seqreps = 1;

% load the default stimulus
template = load('C:\bvGUI\stimsets\Templates\image_set.mat');
default_stim = template.expData.stims;

% find number of images in the image folder
all_images = dir(image_folder);
all_images = all_images(~[all_images.isdir]);

% loop through building stim sets

end