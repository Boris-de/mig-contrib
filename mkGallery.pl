#!/usr/bin/perl -w
#
# mkGallery.pl - turns a directory full of image files into a "gallery".
#
# Copyright 2000-2002 Daniel M. Lowe <dan@tangledhelix.com>
#
# http://mig.sourceforge.net/
#
# $Id$
#
#
# LICENSE INFORMATION
# ===================
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#
# MISCELLANEOUS
# =============
#
# See the file docs/text/utilities.txt for more information.
# (If you prefer HTML, docs/html/utilities.html)
#
#     I haven't tested mkGallery.pl under Microsoft Windows, so Windows
#     users will proceed at their own risk!
#
# You should not need to modify this code directly.  If you do, and want
# to contribute your changes to Mig, please send me email with a diff
# (contextual diffs are preferred, i.e. "diff -c"), and if I agree that
# your change is of use to the general public, I will incorporate it into
# the main code tree.
#
# However, in general Mig is written with the goal that the user should
# never have to modify actual code to use the software - everything is
# taken care of either automatically, or using configuration files.
#
# Please submit any bug reports or feature requests to the Sourceforge
# Tracker:
#
#     http://sourceforge.net/tracker/?group_id=24365
#

use strict;
use Cwd;
use File::Basename;
use File::Find;
use Getopt::Std;

my $myself = File::Basename::basename($0);  # Program name
my $mydir  = File::Basename::dirname($0);   # Directory $myself lives in
my $myRoot = cwd;                           # Directory I was started in

my $exifProg = $mydir . '/jhead';           # Location of jhead program
my $exifArgs = '-v';                        # Flags to pass jhead
my $exifFile = 'exif.inf';                  # File to store exif data in

# Defaults for boolean command-line flags
my $allFlag         = 0;        # -a: Process all images
my $exifFlag        = 0;        # -e: Process EXIF data
my $overwriteFlag   = 0;        # -w: Over-write files instead of appending
my $thumbFlag       = 0;        # -t: Create thumbnails
my $commentsFlag    = 0;        # -c: Create comments
my $interactFlag    = 0;        # -i: Interactive mode
my $recurseFlag     = 0;        # -r: Recursion mode
my $newOnlyFlag     = 0;        # -n: Process only new items
my $thumbDirFlag    = 0;        # -d: Use thumbnail subdirectories

# Defaults for command-line flags which take arguments
my $defaultSize     = 100;          # -s: Thumbnail size
my $defaultQuality  = 50;           # -q: Thumbnail quality
my $defaultMarker   = '';           # -m: Thumbnail label
my $markerType      = '';           # -M: Thumbnail label position
my $defaultThumbDir = 'thumbs';     # -D: Name of thumbnail subdirectory
my $defaultThumbExt = '';           # -E: File extension for thumbnails

# Mode to use for thumbnail subdirectories
my $thumbDirMode    = 0755;

# For the help routine
my $pkgName = 'Mig';
my $url = 'http://mig.sourceforge.net/';
my $email = 'dan@tangledhelix.com';

my $migConfig = 'mig.cf';       # Name of per-directory configuration file

my $globalConfig = $mydir . '/../config.php';       # Global config file

# Fetch command line options
my %opt = ();
getopts('acdD:eE:f:hiM:m:nq:rs:tw', \%opt);

# Set new config file if one was specified.
$globalConfig = $opt{'f'} if $opt{'f'};

# Parse global config file, if it exists.
if (-r $globalConfig) {
    ($markerType, $defaultMarker, $thumbDirFlag, $defaultThumbDir,
     $defaultThumbExt) =
                &parseMyConfig($globalConfig, $markerType, $defaultMarker,
                               $thumbDirFlag, $defaultThumbDir,
                               $defaultThumbExt);
}

# Prototypes
my ($item, $file, $ext, $size, $quality, $markerLabel, $marktestpat, $cmd);
my ($thumbDir, $thumbExt);
my @contents        = ();
my @processDirs     = ();
my @processFiles    = ();
my @noprocess       = ();
my @origfile        = ();
my @newfile         = ();
my %FILE            = ();
my %EXT             = ();

# Set appropriate flag variables
$allFlag        = 1 if $opt{'a'};   # set "process all images" flag
$commentsFlag   = 1 if $opt{'c'};   # set "process comments" flag
$exifFlag       = 1 if $opt{'e'};   # set "process EXIF info" flag
$thumbFlag      = 1 if $opt{'t'};   # set "thumbnails" flag
$overwriteFlag  = 1 if $opt{'w'};   # set "overwrite" flag
$interactFlag   = 1 if $opt{'i'};   # set "interactive" flag
$recurseFlag    = 1 if $opt{'r'};   # set "recursion" flag
$newOnlyFlag    = 1 if $opt{'n'};   # set "new only" flag
$thumbDirFlag   = 1 if $opt{'d'};   # set "use thumb subdir" flag

# For "convert"
$size       = $opt{'s'};    # thumbnail size in pixels
$quality    = $opt{'q'};    # quality level for thumbnails

# Thumbnail naming rules
$markerLabel = $defaultMarker;
$markerLabel = $opt{'m'} if $opt{'m'};
$markerType = $opt{'M'} if $opt{'M'};
$thumbDir = $defaultThumbDir;
$thumbDir = $opt{'D'} if $opt{'D'};
$thumbExt = $defaultThumbExt;
$thumbExt = $opt{'E'} if $opt{'E'};

# Print help, if asked to.
if ($opt{'h'}) {
    &helpMessage($myself, $pkgName, $url, $email, $exifFile);
    exit(0);
}

# Error out and exit if there are both filenames and "-a" specified.
if ($allFlag and $ARGV[0]) {
    print "ERROR: -a specified as well as filenames.\n\n";
    exit(1);
}

# Error out and exit if -r is present without -a
if ($recurseFlag and not $allFlag) {
    print "ERROR: -r specified without -a.\n\n";
    exit(1);
}

# Error out and exit if -n is present without -t
if ($newOnlyFlag and not $thumbFlag) {
    print "ERROR: -n specified without -t.\n\n";
    exit(1);
}

# Error out if -E was given without -t
if ($opt{'E'} and not $thumbFlag) {
    print "ERROR: -E specified without -t.\n\n";
    exit(1);
}

# If no files are specified and also no "-a", bail out.
unless ($allFlag or $ARGV[0]) {
    print "ERROR: no filenames specified, and -a not specified.\n\n";
    exit(1);
}

# If "-e" is specified but $exifProg isn't executable, bail out.
if ($exifFlag) {
    unless (-x $exifProg) {
        print "\nERROR: \"-e\" specified, but $exifProg not found.\n";
        print "See the file docs/Utilities.txt for more information.\n\n";
        exit(1);
    }
}

# If none of -c, -e, -t are specified, quit (no action to take).
unless ($commentsFlag or $exifFlag or $thumbFlag) {
    print "ERROR: no action specified.  You must specify at least one\n";
    print "of -c, -e or -t.  More than one is OK, but at least one must\n";
    print "be specified.\n\n";
    exit(1);
}

# If -M is an invalid type, bail out.
if ($markerType ne 'prefix' and $markerType ne 'suffix') {
    print "ERROR: marker type \"$markerType\" is invalid.\n";
    print "Only \"prefix\" and \"suffix\" are valid.  This could\n";
    print "be specified as an argument for -M, or can be specifed\n";
    print "in your config.php file (see \$markerType)\n\n";
    exit(1);
}

# If -i was used without -c, bail out.
if ($interactFlag and not $commentsFlag) {
    print "ERROR: -i specified without -c.\n\n";
    exit(1);
}

# Set values based on the markerType.
if ($markerType eq 'prefix') {
    $markerLabel .= '_';
    $marktestpat = '^' . $markerLabel;
}
if ($markerType eq 'suffix') {
    $markerLabel = '_' . $markerLabel;
    $marktestpat = $markerLabel . '$';
}

# Use defaults if they weren't specified.
$size = $defaultSize unless $size;
$quality = $defaultQuality unless $quality;

# If we're running in recursion mode, then figure out what directories we
# need to be looking at.
if ($recurseFlag) {
    @File::Find::mkGalleryDirs = ();    # initialize empty array
    # define what to look for
    sub dirfind {
        my $thumbDirFlag = $File::Find::mkGalleryThumbDirFlag;
        my $thumbDir = $File::Find::mkGalleryThumbDir;
        if ($thumbDirFlag) {
            unless (/^$thumbDir$/) {
                push(@File::Find::mkGalleryDirs, $File::Find::name) if -d;
            }
        } else {
            push(@File::Find::mkGalleryDirs, $File::Find::name) if -d;
        }
    }
    $File::Find::mkGalleryThumbDirFlag = $thumbDirFlag;
    $File::Find::mkGalleryThumbDir = $thumbDir;
    find(\&dirfind, $myRoot); # do the find itself
    @processDirs = @File::Find::mkGalleryDirs;  # stash in @processDirs
} else {
    # otherwise, just do the current directory (default behavior)
    @processDirs = ( $myRoot );
}

# Iterate through each directory
foreach (@processDirs) {

    chdir $_;
    print "=> $_\n";        # print a line each time we chdir()

    if ($allFlag) {         # build a list of all files

        opendir(DIR, $_) or die "Can't open directory $_ !\n";
        @contents = ();
        @contents = readdir(DIR);
        closedir(DIR);

        @processFiles = ();
        @noprocess = ();
        %FILE = ();
        %EXT = ();
        foreach $item (sort(@contents)) {
            if (-f $item) {
                ($file, $ext) = &fileExtension($item);
                if (&testFileType($ext) and $file !~ /$marktestpat/) {
                    push (@processFiles, $item);
                    $FILE{$item} = $file;
                    $EXT{$item} = $ext;
                } else {
                    push (@noprocess, $item);
                }
            }
        }

    } else {
        @processFiles = ();
        @noprocess = ();
        %FILE = ();
        %EXT = ();
        foreach $item (@ARGV) {
            ($file, $ext) = &fileExtension($item);
            if (&testFileType($ext) and $file !~ /$marktestpat/) {
                push (@processFiles, $item);
                $FILE{$item} = $file;
                $EXT{$item} = $ext;
            } else {
                push (@noprocess, $item);
            }
        }
    }

    # If -e and -w were used, remove any existing exif.inf files
    if ($exifFlag and $overwriteFlag) {
        unlink $exifFile;
    }

    # If -c was used, process comment file
    if ($commentsFlag) {
        print "Processing comments file \"$migConfig\"...\n";
        &processComments($migConfig, '.', $interactFlag, @processFiles);
    }

    foreach $item (@processFiles) {

        my ($orig_file, $new_file, $SIZE);

        $orig_file = $FILE{$item} . '.'    . $EXT{$item};

        if ($thumbDirFlag) {
            if ($thumbExt) {
                $new_file = "$thumbDir/" . $FILE{$item} . '.' . $thumbExt;
            } else {
                $new_file = "$thumbDir/" . $FILE{$item} . '.' . $EXT{$item};
            }
            if (not -d $thumbDir) {
                mkdir $thumbDir, $thumbDirMode;
            }
        } else {
            if ($markerType eq 'prefix') {
                if ($thumbExt) {
                    $new_file  = $markerLabel . $FILE{$item} . '.';
                    $new_file .= $thumbExt;
                } else {
                    $new_file  = $markerLabel . $FILE{$item} . '.';
                    $new_file .= $EXT{$item};
                }
            } else {
                if ($thumbExt) {
                    $new_file  = $FILE{$item} . $markerLabel . '.';
                    $new_file .= $thumbExt;
                } else {
                    $new_file  = $FILE{$item} . $markerLabel . '.';
                    $new_file .= $EXT{$item};
                }
            }
        }

        $SIZE = $size . 'x' . $size;

        # Make a thumbnail, if -t was invoked
        if ($thumbFlag) {

            $cmd = "convert -geometry $SIZE -quality $quality \"$orig_file\"";
            $cmd .= " \"$new_file\"";

            # 1) -n wasn't used.
            if (not $newOnlyFlag) {
                print "Generating thumbnail \"$new_file\" ...\n";
                system($cmd);

            # 2) -n was used, but thumbnail does not exist.
            } elsif ($newOnlyFlag and not -f $new_file) {
                print "Generating thumbnail \"$new_file\" ...\n";
                system($cmd);

            } else {
                @origfile = stat($orig_file);
                @newfile  = stat($new_file);
                # 3) -n was used but thumbnail is older than image file
                if ($origfile[9] > $newfile[9]) {
                    print "Generating thumbnail \"$new_file\" ...\n";
                    system($cmd);
                }
            }
        }

        if ($exifFlag and $EXT{$item} =~ /^(jpg|jpe|jpeg)$/i) { # only for JPG
            print "Parsing $orig_file EXIF header...\n";
            &getExifInfo($exifProg, $exifArgs, $exifFile, $orig_file);
        }
    }
}


##
##  Subroutines
##



# fileExtension() - given a filename, breaks it into a filename and an
# extension.  Returns list value (file,ext)

sub fileExtension {

    my $filename = shift;
    my ($extension, $stripname);

    $extension = $filename;
    $stripname = $filename;

    $stripname =~ s/^(.*)\.([^\.]+)$/$1/;
    $extension =~ s/^.*\.([^\.]+)$/$1/;

    return $stripname, $extension;

}   # -- End of fileExtension()



# testFileType() - given a file extension, returns boolean (0|1) indicating
# it is, or isn't, a valid file type for handling.

sub testFileType {

    my $extension = shift;

    if ($extension =~ /^(jpg|jpeg|jpe|png|gif)$/i) {
        return 1;
    } else {
        return 0;
    }
}   # -- End of testFileType()



# getExifInfo() - Given a file to process, calls an external program to
# parse the EXIF and JPEG comment information from that file.

sub getExifInfo {

    my $exifProg = shift;
    my $exifArgs = shift;
    my $exifFile = shift;
    my $image = shift;

    open(OUT, ">>$exifFile") or die "Can't open $exifFile for writing\n";

    open(EXIF,"$exifProg $exifArgs \"$image\"|")
                        or die "Can't exec $exifProg\n";

    print OUT "BEGIN $image\n";
    print OUT while <EXIF>;
    print OUT "\n";
    close EXIF;

    close OUT;

    return 1;

}   # -- End of getExifInfo()



# helpMessage() - Prints a help message

sub helpMessage {

    my $myself = shift;
    my $pkgName = shift;
    my $url = shift;
    my $email = shift;
    my $exifFile = shift;

    print "\nUsage:\n";
    print "   $myself [ -h ] [ -a ] [ -w ] [ -t ] [ -e ] [ -c ] [ -i ]\n";
    print "\t[ -s <size> ] [ -q <quality> ] [ -M <type> ] [ -m <label> ]\n";
    print "\t[ -n ] [ -r ] [ -d ] [ -D <dir> ] [ -E <ext> ] [ -f <file> ]\n";
    print "\t[ <file1> <file2> <...> ]\n\n";
    print "      -h : Prints this help message.\n";
    print "      -f : Use alternate configuration file (config.php)\n";
    print "      -a : Process all image files in current directory.\n";
    print "      -w : Turn over-write on.  By default, files written such\n";
    print "           as the EXIF file will be appended to rather than\n";
    print "           over-written.  Using \"-w\" indicates the file should\n";
    print "           be over-written instead.\n";
    print "      -t : Generate thumbnail images.\n";
    print "      -e : Build \"$exifFile\" file.  You must compile the jhead\n";
    print "           utility (included) before you can use the -e option.\n";
    print "      -c : Generate blank comments for uncommented images.\n";
    print "      -i : \"Interactive\" mode for comments.\n";
    print "      -s : Set pixel size for thumbnails.\n";
    print "      -q : Set quality level for thumbnails.\n";
    print "      -M : Define type of \"prefix\" or \"suffix\".\n";
    print "      -m : thumbnail marker label (default \"th\").\n";
    print "      -n : Only process thumbnails that don't exist (new-only).\n";
    print "           Will also process thumbnails which are older than the\n";
    print "           full-size images they are associated with.\n";
    print "      -r : Recursive mode - process this folder as well as any\n";
    print "           folders and subfolders beneath it.\n";
    print "      -d : Use thumbnail subdirectories (instead of using _th, etc)\n";
    print "      -D : Name of thumbnail subdirectory to use (default is \"thumbs\" or\n";
    print "           whatever is in your config.php file).\n";
    print "      -E : File extension to use for thumbnails.\n\n";
    print " * If creating thumbnails, \"convert\" must be in your \$PATH.\n";
    print " * This program supports JPEG, PNG and GIF formats.\n";
    print " * The \"-e\" feature only supports JPEG files.\n";
    print " * See the \"utilities\" document for more information.\n\n";
    print "   $pkgName - $url\n\n";

    return 1;

}   # -- End of helpMessage()



# parseMyConfig() - parses global configuration file for certain
# configuration options

sub parseMyConfig {

    my $configFile = shift;
    my $markerType = shift;
    my $defaultMarker = shift;
    my $thumbDirFlag = shift;
    my $defaultThumbDir = shift;
    my $defaultThumbExt = shift;

    my $type = undef;

    unless (open(CF, $configFile)) {
        print "Can't open $configFile for reading, skipping it.\n";
        return $markerType, $defaultMarker, $thumbDirFlag,
               $defaultThumbDir, $defaultThumbExt;
    }

    while (<CF>) {
        chomp;
        if (/^[\s]*\$markerType/) {
            s/^.*\$markerType[\s]*=[\s]*["']([^"']*)["'][\s]*;.*$/$1/i;
            $type = lc $_;          # just in case
            if ($type eq 'prefix' or $type eq 'suffix') {
                $markerType = $type;
            }
        }
        if (/^[\s]*\$markerLabel/) {
            s/^.*\$markerLabel[\s]*=[\s]*["']([^"']*)["'][\s]*;.*$/$1/i;
            $defaultMarker = $1 if $1;
        }
        if (/^[\s]*\$useThumbSubdir/) {
            s/^.*\$useThumbSubdir[\s]*=[\s]*([A-Z]+)[\s]*;.*$/$1/i;
            $thumbDirFlag = 1 if /^TRUE$/;
            $thumbDirFlag = 0 if /^FALSE$/;
        }
        if (/^[\s]*\$thumbSubdir/) {
            s/^.*\$thumbSubdir[\s]*=[\s]*["']([^"']*)["'][\s]*;.*$/$1/i;
            $defaultThumbDir = $1 if $1;
        }
        if (/^[\s]*\$thumbExt/) {
            s/^.*\$thumbExt[\s]*=[\s]*["']([^"']*)["'][\s]*;.*$/$1/i;
            $defaultThumbExt = $1 if $1;
        }
    }
    close CF;

    return $markerType, $defaultMarker, $thumbDirFlag, $defaultThumbDir,
           $defaultThumbExt;

}   # -- End of parseMyConfig()



# processComments() - Handles creation of <Comment> elements in mig.cf.

sub processComments {

    my $migConfig = shift;
    my $currDir = shift;
    my $interactFlag = shift;
    my @process = @_;

    my $tempConfig = $migConfig . '.tmp';
    my $commIn = undef;
    my $saw_bulletin = undef;
    my $bulletin = undef;
    my $bullIn = undef;
    my %noadd = ();

    # Bail out if the file is there but it can't be read.
    if (-f $migConfig and not -r $migConfig) {
        print "ERROR: $migConfig exists, but I can't read it.\n";
        print "ERROR: skipping comment processing.\n";
        return 0;
    }

    # bail out if we can't write to it, either.
    if (-f $migConfig and not -w $migConfig) {
        print "ERROR: $migConfig exists, but I can't write to it.\n";
        print "ERROR: skipping comment processing.\n";
        return 0;
    }

    if (-r $migConfig) {
        open(CF, $migConfig);
        while (<CF>) {
            chomp;
            if (/^<comment/i) {
                s/^<comment[\s]+\"([^"]+)\"[\s]*>.*$/$1/i;
                $noadd{$_} = 1 if $_ ne '';
            }
            if (/^<bulletin/i) {
                $saw_bulletin = 1;
            }
        }
        close CF;
    }

    open(OUT, ">>$migConfig");
    # Not sure why this was here.
    #print OUT "\n";
    # stick a bulletin entry in while we are here, unless one is already
    # present in mig.cf.
    unless ($saw_bulletin) {
        if ($interactFlag) {
            print "A bulletin entry is a comment covering the entire\n";
            print "folder.  It shows up on the thumbnail page for the\n";
            print "folder.\n\n";
            print "Would you like to add a bulletin entry? (y/n) ";
            $bullIn = <STDIN>;
            if ($bullIn =~ /^[yY]/) {
                print 'Enter bulletin: ';
                chomp($bulletin = <STDIN>);
                print OUT "<Bulletin>\n$bulletin\n</Bulletin>\n\n";
            }
        } else {
            print OUT "<Bulletin>\n</Bulletin>\n\n";
        }
    }

    foreach (@process) {
        unless ($noadd{$_}) {
            print OUT '<Comment "', $_, '">', "\n";
            if ($interactFlag) {
                print "Enter comment for $_: ";
                chomp($commIn = <STDIN>);
                if ($commIn) {
                    print OUT "$commIn\n";
                }
            }
            print OUT "</Comment>\n\n";
        }
    }
    close OUT;

    return 1;

}   # -- End of processComments()

