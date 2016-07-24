#!/usr/bin/perl
# viddupes.pl
# found at
# http://ubuntuforums.org/archive/index.php/t-1110488.html
# Author: User xxsludgexx on ubuntuforums.org
# Code cleanup, comments: stueja on github.com
## - use graphicsmagick (gm mogrify) instead of imagemagick (mogrify)
## - one line per command
## - more explanatory error messages
## - code comments and explanations as good as I understood
## - renamed some file handles and variables
## - minor corrections (e. g. printf("\%") to printf("%%")
## - changed ffmpeg command line to use frames from somewhere within the video

use File::Path;
use File::Basename;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Term::ANSIColor;
use File::Temp qw/ tempdir /;
use Getopt::Long;
use File::Find;

use warnings;

GetOptions('path=s' => \$searchdir,'report=s' => \$report);
die "Option `--path` not defined" unless defined $searchdir;
my $ofh = select STDOUT; 
$| = 1; 
select STDOUT;

#$renderfirst = 2500;
$renderfirst = 50;
$threshold = 5;

# $basedir will later contain files named after the md5 hash of the threshold image
# with the video filename as content
# ff87500bf6d365eb4c1fcd3590f4e15b.md5 contains video.mp4
$basedir = tempdir ( DIR => "/tmp/" );

sub banner { 
	print colored ['red'],"--------> "; 
	print color 'green'; 
	printf '%-96s',@_; 
	print colored ['red']," <--------"; 
	print color 'reset'; 
	print "\n";
}

sub wanted {
	if ((-f $File::Find::name) && ($File::Find::name =~ m/\.bmp$/i)) {
		$filename = $File::Find::name; 
		# $filename = /tmp/t2tfdjaPXyVideos/video.mp4/imageA02500.bmp

		$filename =~ s/^$basedir//g; 
		# $filename = Videos/video.mp4/imageA02500.bmp

		$filename =~ s/^$searchdir//g; 
		# $filename = video.mp4/imageA02500.bmp

		$filename =~ s/\/image.*bmp$//g;
		# $filename = video.mp4
		
		# open /tmp/t2tfdjaPXyVideos/video.mp4/imageA02500.bmp
		# which is a black-and-white threshold image
		open(FRAME, $File::Find::name); 
		binmode(FRAME);
		# create md5 hash of it
		$md5 = Digest::MD5->new->addfile(*FRAME)->hexdigest; 
		close(FRAME);

		# create a file named $md5.md5 with the md5 hash as file name
		open (MD5FILE, ">>$basedir/$md5.md5") or die "couldn't open file $basedir/$md5.md5\n"; 
		# print the original video file name (video.mp4) into it
		# so file 00ee1df73143cbb468282713b969a3ef.md5 contains video.mp4
		print MD5FILE "$filename\n"; 
		close (MD5FILE);

		unlink($filename);
	}
}

################################################
# Rendering video, thresholding, and hashing #
################################################
banner "Rendering video from $searchdir -> $basedir";

# finds video files in searchdir
#@videofiles=`find "$searchdir" -type f -printf "%p\n" | grep -Ei "\.(mp4|flv|wmv|mov|avi|mpeg|mpg|m4v|mkv|divx|asf)"`;
@videofiles=`find "$searchdir" -type f -printf "%p\n" | grep -Ei "Medical.*\.mp4"`;

# get number of found video files
$numfiles = @videofiles; 
$count = 1; 
chomp(@videofiles);

# walk through array of video files
foreach $i (@videofiles) {
	# extract directory name and file name
	$dir = dirname($i); 
	$file = basename($i);

	print color 'cyan'; 
	printf "%4s of %-6s",$count,$numfiles; 
	print "$i\t"; 
	$count++; 
	print color 'reset';

	# create new, temporary path $imgdir containing the extracted threshold images
	$imgdir = $basedir . $dir . "/" . $file; 
	# making a path in $basedir with $searchdir and filename 
	# $basedir=/tmp/0rrEk9m856
	# $dir=Videos
	# $file=video.mp4
	# => mkpath /tmp/0rrEk9m856Videos/video.mp4
	# will contain extracted frame images later
	mkpath($imgdir);

	# extract the first $renderfirst (default: 2500) frames and store them in $imgdir
#	$data=`ffmpeg -i "$i" -s "64x64" -vframes $renderfirst -f image2 "$imgdir/imageA%05d.bmp" 2>&1`; 
# for a different starting position, e. g. the video(s) are video recordings with different commercials at the beginning
# here: starting at 10min15sec, extract 30 seconds
# takes significantly longer than simply extracting the first 2500 frames.
# do not forget to adjust $renderfirst, because it will be used for calculation of the percentage of the intersection below
$data=`ffmpeg -i "$i" -s "64x64" -ss 00:10:15 -t 00:00:30 -f image2 "$imgdir/imageA%05d.bmp" 2>&1`;
$renderfirst=30*25;
	print ".";

	# convert extracted frames to an 8x8, black and white image; 
	# -resize 8x8!   : resize disregarding original aspect ratio
	# -threshold 25% : convert to black and white / threshold (https://www.imagemagick.org/script/command-line-options.php#threshold)
	# use `/usr/bin/gm mogrify` for GraphicsMagick, `/usr/bin/mogrify` for ImageMagick
	$data=`/usr/bin/gm mogrify -resize 8x8! -threshold 25% "$imgdir/*"`; 
	print ".";
	
	# create files with md5 hash as filename in $basedir and video file name as content,
	# see sub wanted()
	find(\&wanted, $imgdir); 
	print ".";

	# remove the directory containing the extracted threshold images 
	rmtree($imgdir); 
	print " Done\n";
}

###################################
# Hash sorting time #
###################################

banner "Sorting through the hashes...";

# find the md5 files created in \&wanted
# e. g. /tmp/QO0QZUZ5sD/6d59e2011be6582e4a97e9e79672888a.md5
# @hashfiles contains list of those filenames
@hashfiles=`find "$basedir" -maxdepth 1 -type f -iname "*.md5"`; 
chomp(@hashfiles);
# walk through each file
foreach $md5file (@hashfiles) {
	# sort the list, remove duplicate lines, output line count (-c), delete tabs and spaces
	# => example for one line:  $md5file = 1 /tmp/HmZzBO_SWl/00ee1df73143cbb468282713b969a3ef.md5
	@uniqfiles=`sort "$md5file" | uniq -c | sed "s/^[\t ]*//g"`; 
	chomp(@uniqfiles); 
	$uniqsize=@uniqfiles;

	# if there is more than 1 
	if ($uniqsize > 1) {
		#print "$uniqsize File(s) in array:\n";
		# walk through array of sorted/uniq'd hashes from 0 to $#uniqfiles
		# let's call it NEEDLE for the moment
		for ($skip = 0; $skip < $uniqsize; $skip++) {
			# split line into count and filename
			# example:
			# $duplicatemd5s = 5
			# $outputpath = /tmp/HmZzBO_SWl/00ee1df73143cbb468282713b969a3ef.md5
			$uniqfiles[$skip] =~ m/^([0-9]{1,10})[ \t]{1,2}(.*)/i; 
			$duplicatemd5s=$1; 
			$outputpath=$2; 
			#print "\t $skip -> $outputpath\n";
			
			# the same again, recursively; lcv := list compare value?
			# let's call it HAYSTACK for the moment
			for ($lcv = $skip; $lcv < $uniqsize; $lcv++) {
				$uniqfiles[$lcv] =~ m/^([0-9]{1,10})[ \t]{1,2}(.*)/i; 
				$count = $1; 
				$filename=$2;
				
				# if position of this (lcv) HAYSTACK  element not equal to the (skip) NEEDLE element
				if ($lcv != $skip) {
					# if number of duplicate HAYSTACK lines is greater/equal number of duplicate NEEDLE lines
					if ($count >= $duplicatemd5s) { 
						# newcount = NEEDLE duplicate count
						$newcount = $duplicatemd5s 
					} else {
						# newcount = HAYSTACK duplicate count 
						$newcount = $count 
					}
					#print "\t\t+$duplicatemd5s +$count = $newcount\t$filename\t";

					if ($outputpath gt $filename) {
						#print "$outputpath gt $filename\n";
						if (!defined $hasharray{"$outputpath|$filename"} ) { 
							$hasharray{"$outputpath|$filename"} = 0	
						}
						if (defined $hasharray{"$outputpath|$filename"} ) { 
							$hasharray{"$outputpath|$filename"} += $newcount 
						}
					}
					
					if ($outputpath lt $filename) {
						#print "$outputpath lt $filename\n";
						if (!defined $hasharray{"$filename|$outputpath"} ) { 
							$hasharray{"$filename|$outputpath"} = 0 
						}
						if (defined $hasharray{"$filename|$outputpath"} ) { 
							$hasharray{"$filename|$outputpath"} += $newcount 
						}
					}
				}
			}
		}
	}
}

# remove directory containing the .md5 files
rmtree($basedir);

############################
# Outputing dupes time #
############################
banner "Report of dupes in $searchdir"; print "\n";

# sorting subroutine
sub by_value { 
	$hasharray{$a} <=> $hasharray{$b}; 
}

if (defined $report) { 
	open (REPORTFILE, ">",$report) or die "could not open file $report\n";
}


foreach $key (sort by_value keys %hasharray) {
	$value = $hasharray{$key};
	$newvalue = ($value * 100.0) / $renderfirst;
	if ($newvalue >= $threshold) {
		$keyout = $key; 
		$keyout =~ s/\|/\n\t/g;
		# corrected: \% to %%
		# http://stackoverflow.com/a/1102638/6426489
		printf("%.1f%%\t%s\n\n",$newvalue,$keyout);
		if (defined $report) { 
			printf REPORTFILE "%.1f%%\t%s\n",$newvalue,$keyout;	
		}
	}

}

if (defined $report) { 
	close (REPORTFILE);
}

exit;

