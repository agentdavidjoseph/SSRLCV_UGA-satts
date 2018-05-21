# Tegra SfM

## Compilation

If you are running this for the first time you need to make a `bin` folder in the root of this repo.

`make` and `make clean`, per the uz

Depending on how cuda are installed on your system you make have to change the first few
lines in the Makefile to specify the location of the library.

## Running

The executables for `.cpp` and `.cu` programs are placed in the `bin` folder with the extension `.x`

To run the reprojection from the root folder of this repo: `./bin/reprojection.x path/to/cameras.txt path/to/matches.txt`

Additionally, a `1` or a `0` can be placed at the end of the statement. A `0` makes it so that the program runs on the CPU with a CPU implementation. Be careful, this is super slow. 

## Source

Source files for the nominal program are located in the `src` folder. Some additional programs are located in the `util` folder.

## File Formats

### Matches
Feature matches, for sift, are stored in a `.txt` file. The first line of the file is the number of matches.

> matches (int)

The file type is basically a `.csv` of the following format:

> image 1 (string),image 2 (string),image 1 x value (float),image 1 y value (float),image 2 x value (float),image 2 y value (float),r (0-255),g (0-255),b (0-255)

### Cameras
Camera location and pointing data is stored in a in a `.txt` file. The file includes a location in `(x,y,z)` as well as a unit vector `(u_x,u_y,u_z)` to represent the orientation of the camera. The file type is basically a `.csv` of the following format:

> image number (int), camera x (float), camera y (float), camera z (float), camera unit x (float), camera unit y (float), camera unit z (float)

## TX1 information

* Username: ubuntu
* Password: ubuntu
* IP: 128.192.19.163

## TX2 information

* Username: nvidia
* Password: nivida
* IP: 172.28.143.74
