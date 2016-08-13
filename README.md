# viddupes
Finds possible video duplicates in a folder

```!/usr/bin/perl
 viddupes.pl
 found at
 http://ubuntuforums.org/archive/index.php/t-1110488.html
 Author: User xxsludgexx on ubuntuforums.org
 Code cleanup, comments: stueja on github.com```
 - use graphicsmagick (gm mogrify) instead of imagemagick (mogrify)
 - one line per command
 - more explanatory error messages
 - code comments and explanations as good as I understood
 - renamed some file handles and variables
 - minor corrections (e. g. printf("\%") to printf("%%")
 - changed ffmpeg command line to use frames from somewhere within the video
   (to adjust to video recordings with differing commercials before the recording)

