#!/usr/bin/perl
# GoldenPod
# Copyright (C) Eskild Hustvedt 2005, 2006, 2007, 2009, 2010, 2011
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Force strict mode, and useful warnings
use strict;
use warnings;
# Require perl 5.14 to get unicode_strings, say, //, package blocks
use 5.014;

# Make perl automatically die if any of these fails
use Fatal qw/ open chdir mkdir close /;
# Used to find our directory and name
use File::Basename;
# Used to create our dirs
use File::Path qw(mkpath);
# We need realpath and getcwd
use Cwd qw(getcwd realpath);
# Parsing of commandline parameters
use Getopt::Long;
# Copying files
use File::Copy;
# Used to get OS name for user agent
use POSIX qw(uname);
# open() call to commands
use IPC::Open2;
# Using true/false is easier to read than 0/1
use constant { true => 1, false => 0 };
# Allow bundling of options with GeteOpt
Getopt::Long::Configure ('bundling', 'prefix_pattern=(--|-)');
# Version number
my $Version = '0.9';

# The path to our podcast list config file
my $PodcastList;
# Our verbosity
my $Verbose = 0;
# When set to any true value this disables logging. When set to 2 it
# disables logging and directs all of our output to /dev/null
my $NoLog = 0;
# When set to true, goldenpod will only download the first entry in a feed
my $FirstOnly = 0;
# When set to true, goldenpod will not download anything at all, but will
# add all entries in all feeds to its list of already downloaded files.
my $NoDownloadMode = 0;
# When set to true, goldenpod will delete files when in --copy mode
my $CopyFiles_Delete = 0;
# The path to our config dir, set by initialize()
my $UserConfigDir;
# If true, enables dry-run mode
my $DryRun_Mode = 0;
# A regex used to ignore files, either from the config or --ignore-pattern
my $IgnorePattern;
# Where to copy files to when in --copy mode
my $CopyFilesTo;
# True if we should delete old podcasts
my $RemoveOldFiles = 0;
# The number of --files to --copy or --rmold
my $FileNumber = undef;
# The path to the podcast logfile
my $PodcastLog;

# Our config
my %Config;
# Return values that are captured by our SIGCHLD handler
my %ReturnVals;
# Contains a list of already downloaded podcasts
my %AlreadyDownloaded;
# Contains a list of podcasts to be added to our "already downloaded" list
my %NoDownload;
# Podcast feed names used to populate the catalogue
my %PodNames;

# Our user agent string
my $UserAgent = 'GoldenPod/'.$Version.' (%OS%; podcatcher; Using %downloader%)';

my %Has = (
	LWP => 0,
	curl => 0,
	HTMLE => undef,
);
# The global date, as used in directory names, value set in main()
my $date;

# The downloader
my $downloader = 'LWP';

# These are global state varibles for the LWP download component
my $lastP = 0;
my $prevLen = 0;

my $AudioRegex = '(ogg|oga|mp3|m4a|wave?|flac|wma|ape|tta|aac|mp2|mpa|ram?|aiff?|au|mpu)';

# This makes sure children are slayed properly and their return values
# are kept (in the %ReturnVals hash)
$SIG{CHLD} = sub
{
	my $PID = wait;
	$ReturnVals{$PID} = $? >> 8;
	return(1);
};

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Help function declerations
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Purpose: Print formatted --help output
# Usage: PrintHelp('-shortoption', '--longoption', 'description');
#  Description will be reformatted to fit within a normal terminal
sub PrintHelp
{
	# The short option
	my $short = shift,
	# The long option
	my $long = shift;
	# The description
	my $desc = shift;
	# The generated description that will be printed in the end
	my $GeneratedDesc;
	# The current line of the description
	my $currdesc = '';
	# The maximum length any line can be
	my $maxlen = 80;
	# The length the options take up
	my $optionlen = 20;
	# Check if the short/long are LONGER than optionlen, if so, we need
	# to do some additional magic to take up only $maxlen.
	# The +1 here is because we always add a space between them, no matter what
	if ((length($short) + length($long) + 1) > $optionlen)
	{
		$optionlen = length($short) + length($long) + 1;
	}
	# Split the description into lines
	foreach my $part (split(/ /,$desc))
	{
		if(defined $GeneratedDesc)
		{
			if ((length($currdesc) + length($part) + 1 + 20) > $maxlen)
			{
				$GeneratedDesc .= "\n";
				$currdesc = '';
			}
			else
			{
				$currdesc .= ' ';
				$GeneratedDesc .= ' ';
			}
		}
		$currdesc .= $part;
		$GeneratedDesc .= $part;
	}
	# Something went wrong
	die('Option mismatch') if not $GeneratedDesc;
	# Print it all
	foreach my $description (split(/\n/,$GeneratedDesc))
	{
		printf "%-4s %-15s %s\n", $short,$long,$description;
		# Set short and long to '' to ensure we don't print the options twice
		$short = '';$long = '';
	}
	# Succeed
	return true;
}

# Purpose: Output the program --help info.
# Usage: Help();
sub Help
{
	$PodcastLog =~ s/$ENV{HOME}/~/;
	my $all = shift;
	Version();
	printf("\nUsage: %s", basename($0));
	printf("\n  or : %s [OPTIONS]\n\n", basename($0));
	PrintHelp('', '--version', 'Display version information and exit');
	PrintHelp('-h', '--help', 'This help screen');
	PrintHelp('-h', '--help-all', 'Print an extended help screen with additional options');
	# Inform the user about the default based upon the value of $Config{DefaultVerbosity}
	if ($Config{DefaultVerbosity})
	{
		PrintHelp('-v', '--verbose', 'Be verbose (default)');
		PrintHelp('-s', '--silent', 'Be silent');
	}
	else
	{
		PrintHelp('-v', '--verbose', 'Be verbose');
		PrintHelp('-s', '--silent', 'Be silent (default)');
	}
	PrintHelp('', '--list', 'Print the list of podcasts added to goldenpod');
	PrintHelp('-a', '--add [URL]', 'Add the URL specified as a feed in goldenpod. You may optionally supply a second parameter, which makes the feed use the fuzzy parser with the regular expression supplied.');
	PrintHelp('-r', '--remove [URL]', 'Remove the URL specified from goldenpod\'s feed list.');
	PrintHelp('', '--ping URL', 'Test URL using both parsers and display which parser is recommended for it.');
	PrintHelp('', '--stats', 'Print some simple statistics');
	PrintHelp('-u', '--dry-run', 'Display what would be done but don\'t do it. Implies --verbose');
	PrintHelp('-w', '--no-download','Mark all podcasts as downloaded. Implies --verbose.');
	PrintHelp('-f', '--first-only', 'Only download the first file in any feed. Permanently ignore the others.');
	PrintHelp('-c', '--copy [path]', 'Copy the last N downloaded files to path. N is either 4 or the number supplied to --files.');
	PrintHelp('-n', '--files N', 'Copy N files instead of 4 (use with --copy or --rmold)');
	PrintHelp('-d', '--delete', 'Delete all other files in the target --copy directory');
	PrintHelp('-o', '--rmold', 'Delete N old podcasts where N is 4 or the number supplied to --files');
	PrintHelp('-i', '--ignore-pattern', 'Ignore filenames matching the regexp pattern supplied when downloading, copying or deleting podcasts.');
	PrintHelp('','--quick','Download the first podcast found in the feed supplied to this parameter and exit');
	PrintHelp('','--clean','Clean up the podcasts directory and catalogue.');
	if ($all)
	{
		PrintHelp('', '--debuginfo', 'Print the files goldenpod works with and some system information');
		PrintHelp('-l', '--nolog', 'Don\'t create a message logfile when in silent mode.');
		PrintHelp('', '--prefer-curl', 'Prefer to use curl for downloading if available, instead of LWP (curl is used by default if LWP is missing)');
		PrintHelp('', '--fuzzydump URL', 'Dump the list of files found by the fuzzy parser in URL. See the manpage for more information');
		PrintHelp('', '--rssdump URL', 'Dump the list of files found by the standard parser in URL. See the manpage for more information');
	}
}

# Purpose: Print version and warranty information
# Usage: Version();
sub Version
{
	print "GoldenPod $Version\n";
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Download helpers
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# GPLWP is a subclass of LWP::UserAgent that overrides the progress method in
# order to output more useful progress messages from goldenpod.
package GPLWP
{
    our @ISA = qw(LWP::UserAgent);
    sub progress
    {
        shift;
        no warnings 'once';
        return if not $main::Verbose;
        my ($status, $response) = @_;
        $| = 1;
        if ($status eq 'tick')
        {
            main::progressed();
        }
        elsif ($status eq 'begin')
        {
            main::progressed();
        }
        elsif ($status eq 'end')
        {
            return;
        }
        else
        {
            $status = int($status * 100);
            main::iprint(sprintf('%-4s',$status.'%'));
        }
    }
}

# Purpsoe: Initialize the downloader
# Usage: initDownload();
sub initDownload
{
    state $downloadInitialized = 0;
    if ($downloadInitialized)
    {
        return;
    }
	detectDownloader();
	my $os = [uname()]->[0];
	$os = $os eq 'Linux' ? 'GNU/Linux' : $os;
	$UserAgent =~ s/%OS%/$os/g;
	$UserAgent =~ s/%downloader%/$downloader/g;
    $downloadInitialized = 1;
}

# Purpose: Detect our downloader
# Usage: detectDownloader();
sub detectDownloader
{
	if(InPath('curl'))
	{
		$Has{curl} = 1;
		if ($downloader eq 'curl')
		{
			return;
		}
	}
	if(eval('use LWP::UserAgent; 1;'))
	{
		$Has{LWP} = 1;
		return;
	}

	if(not $Has{LWP} and not $Has{curl})
	{
		die("Both LWP and curl are missing\n");
	}
	elsif ($Has{curl})
	{
		$downloader = 'curl';
		return;
	}
	else
	{
		die("No downloader found. GoldenPod needs either LWP (libwww-perl) or curl.\n");
	}
}

# Purpose: Fetch a URL, either returning the data or writing a file
# Usage: fetchURL( SOME_URL, FileName?);
# Will download to FileName if present, if undef then it will return
# the content;
sub fetchURL
{
    # Initialize the downloader if needed
    initDownload();

	my $URL = shift;
	my $targetFile = shift;

	if(not $URL =~ m#^\S+://#)
	{
		$URL = 'http://'.$URL;
	}

	if ($downloader eq 'LWP')
	{
		# Reset our state
		$lastP = 0;
		$prevLen = 0;

		# GPLWP is a GoldenPod wrapper around LWP
		my $UA = GPLWP->new(
			agent => $UserAgent.' libwwwperl',
			requests_redirectable => [ 'GET', 'HEAD' ],
		);
		# Honor proxy settings in env
		$UA->env_proxy();
		my $response;

		# if we have a target file then we just use ->mirror, that downloads
		# it to a file instead and handles all the nasties for us.
		if ($targetFile)
		{
			printv('Downloading '.$URL.' ... ');
			$response = $UA->mirror($URL,$targetFile);
		}
		# If we don't, just use standard get
		else
		{
			printv('Fetching '.$URL.' ... ');
			$response = $UA->get($URL);
		}
		if ($Verbose)
		{
			iprint('100% done');
			printv ("\n");
		}
		if(not $response->is_success)
		{
			warn("Download of $URL failed: ".$response->status_line."\n");
			return;
		}
		# Return the content
		return $response->content;
	}
	elsif ($downloader eq 'curl')
	{
		my ($Child_IN, $Child_OUT, $Output);
		# Curl options:
		# -C to continue when possible
		# -k for insecure (allow ssl servers with odd certificates)
		# -L to follow location hints
		# -A sets the user agent string
		my @CurlArgs = ( qw(-C - -k -L -A),$UserAgent);

		# Set verbosity
		if ($Verbose)
		{
			push(@CurlArgs,'-#');
		}
		else
		{
			push(@CurlArgs, qw(--silent --show-error));
		}
		# Output to a file
		if ($targetFile)
		{
			push(@CurlArgs,'-O');
			printv('Downloading '.$URL."\n");
		}
		else
		{
			printv('Fetching '.$URL."\n");
		}

		my $PID = open2($Child_OUT, $Child_IN, 'curl',@CurlArgs,$URL) or die("Unable to open3() connection to curl: $!\n");

		# Read from curl
		while(<$Child_OUT>)
		{
			if (not $targetFile)
			{
				$Output .= $_;
			}
		}
		close($Child_OUT);
		close($Child_IN);

		# If we don't have a return value yet, wait one second and see if we get one
		if(not defined $ReturnVals{$PID})
		{
			sleep(1);
		}

		if(defined $ReturnVals{$PID} and not $ReturnVals{$PID} == 0)
		{
			warn("Download of $URL failed, curl exited with the return value ".$ReturnVals{$PID}."\n");
			return;
		}
		# Return the output
		return $Output;
	}
	else
	{
		die("Unknown downloader: $downloader\n");
	}
}

# Purpose: Download a URL
# Usage: DownloadURL(ToDir, URL);
#  Also handles creating the ToDir
sub DownloadURL
{
	my ($ToDir, $URL) = @_;
	my $CWD = getcwd();
	if(not -d $ToDir)
	{
		mkdir($ToDir) or die("Unable to mkdir $ToDir: $!\n");
	}
	chdir($ToDir);

	my @fileName = split('\?', basename($URL));

	if(fetchURL($URL,$fileName[0]))
	{
		return true;
	}
	else
	{
		return false;
	}
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Helper functions
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Purpose: A print that removes previous text before printing. Used for status Information messages.
# Usage: iprint(text);
sub iprint
{
	local $| = false;
    my $data = shift;
    if ($prevLen)
    {
        for(my $i = 0; $i < $prevLen; $i++)
        {
            print "\b \b";
        }
    }
    $prevLen = length($data);
    print $data;
	local $| = true;
}

# Purpose: Output pretty progression indicator
# Usage: progressed();
#		- Outputs something every ten times it is called
sub progressed
{
	$lastP++;
	my $v;
	if(not defined($lastP) or $lastP == 1 or $lastP == 5){
		$v = '-';
	}elsif($lastP == 2 or $lastP == 6) {
		$v = '\\';
	}elsif($lastP == 3 or $lastP == 7) {
		$v = '|';
	}elsif($lastP == 4 or $lastP == 8) {
		$v = '/';
	}
	$lastP = $lastP == 8 ? 0 : $lastP;
	iprint($v);
	return true;
}

# Purpose: print() something if we're verbose
# Usage: printv(OPTS);
#  OPTS are identical to print();
sub printv
{
	if($Verbose)
	{
		print(@_);
	}
}

# Purpose: Get the path to the logfile
# Usage: logfile = GetLogFile();
sub GetLogFile
{
	return $Config{WorkingDir}.'/goldenpod.log';
}

# Purpose: Prepare logging (if needed)
# Usage: PrepareLogging();
sub PrepareLogging
{
	if(not $NoLog)
	{
		my $ProgramLog = GetLogFile();
		# Unless we're verbose, write stuff to $ProgramLog
		open(STDOUT, '>>',$ProgramLog);
		open(STDERR, '>>',$ProgramLog);
		# Log the date and time we started
		print 'Started at ' . localtime(time);
	}
	# If we're not verbose and $NoLog is 2 (-l) then write stuff to /dev/null ;)
	elsif($NoLog == 2)
	{
		open(STDOUT, '>', '/dev/null');
		open(STDERR, '>', '/dev/null');
	}
}

# Purpose: Check for a file in path
# Usage: InPath(FILE)
sub InPath
{
	foreach (split /:/, $ENV{PATH}) { if (-x "$_/@_" and ! -d "$_/@_" ) {	return "$_/@_"; } } return false;
}

# Purpose: Check if a directory is empty
# Usage: DirIsEmpty(PATH);
#  Returns 1 if it is empty, 0 if it isn't.
sub DirIsEmpty
{
	my $dir = shift;
	opendir(TESTDIR, $dir);
	my @TestDir = readdir(TESTDIR);
	closedir(TESTDIR);
	if(not scalar @TestDir > 2)
	{
		return true;
	}
	return false;
}

# Purpose: Prefix a "0" to a number if it is only one digit.
# Usage: my $NewNumber = PrefixZero(NUMBER);
sub PrefixZero
{
	my $number = shift;
	if ($number =~ /^\d$/)
	{
		return("0$number");
	}
	return($number);
}

# Purpose: Get OS/distro version information
# Usage: print "OS: ",GetDistVer(),"\n";
sub GetDistVer
{
	# Try LSB first
	my %LSB;
	if (-e '/etc/lsb-release')
	{
		LoadConfigFile('/etc/lsb-release',\%LSB);
		if(defined($LSB{DISTRIB_ID}) and $LSB{DISTRIB_ID} =~ /\S/ and defined($LSB{DISTRIB_RELEASE}) and $LSB{DISTRIB_RELEASE} =~ /\S/)
		{
			my $ret = '/etc/lsb-release: '.$LSB{DISTRIB_ID}.' '.$LSB{DISTRIB_RELEASE};
			if(defined($LSB{DISTRIB_CODENAME}))
			{
				$ret .= ' ('.$LSB{DISTRIB_CODENAME}.')';
			}
			return($ret);
		}
	}
	# GNU/Linux and BSD
	foreach(qw/arch mandriva mandrakelinux mandrake fedora redhat red-hat ubuntu debian gentoo suse distro dist slackware freebsd openbsd netbsd dragonflybsd NULL/)
	{
		if (-e "/etc/$_-release" or -e "/etc/$_-version" or -e "/etc/${_}_version" or $_ eq 'NULL') {
			my ($DistVer, $File, $VERSION_FILE);
			if(-e "/etc/$_-release") {
				$File = "$_-release";
				open($VERSION_FILE, '<', "/etc/$_-release");
				$DistVer = <$VERSION_FILE>;
			} elsif (-e "/etc/$_-version") {
				$File = "$_-version";
				open($VERSION_FILE, '<', "/etc/$_-release");
				$DistVer = <$VERSION_FILE>;
			} elsif (-e "/etc/${_}_version") {
				$File = "${_}_version";
				open($VERSION_FILE, '<', "/etc/${_}_version");
				$DistVer = <$VERSION_FILE>;
			} elsif ($_ eq 'NULL') {
				last unless -e '/etc/version';
				$File = 'version';
				open($VERSION_FILE, '<', '/etc/version');
				$DistVer = <$VERSION_FILE>;
			}
			close($VERSION_FILE);
            $DistVer //= '';
			chomp($DistVer);
			return("/etc/$File: $DistVer");
		}
	}
	# Didn't find anything yet. Get uname info
	my ($sysname, $nodename, $release, $version, $machine) = POSIX::uname();
	if ($sysname =~ /darwin/i) {
		my $DarwinName;
		my $DarwinOSVer;
		# Darwin kernel, try to get OS X info.
		if(InPath('sw_vers')) {
			if(eval('use IPC::Open2;1')) {
				if(open2(my $SW_VERS, my $NULL_IN, 'sw_vers')) {
					while(<$SW_VERS>) {
						chomp;
						if (s/^ProductName:\s+//gi) {
							$DarwinName = $_;
						} elsif(s/^ProductVersion:\s+//) {
							$DarwinOSVer = $_;
						}
					}
					close($SW_VERS);
				}
			}
		}
		if(defined($DarwinOSVer) and defined($DarwinName)) {
			return("$DarwinName $DarwinOSVer ($machine)");
		}
	}
	# Detect additional release/version files
	my $RelFile;
	foreach(glob('/etc/*'))
	{
		next if not /(release|version)/i;
		next if m/\/(subversion|lsb-release)$/;
		if ($RelFile)
		{
			$RelFile .= ', '.$_;
		}
		else
		{
			$RelFile = ' ('.$_;
		}
	}
	if ($RelFile)
	{
		$RelFile .= ')';
	}
	else
	{
		$RelFile = '';
	}
	# Some distros set a LSB DISTRIB_ID but no version, try DISTRIB_ID
	# along with the kernel info.
	if ($LSB{DISTRIB_ID})
	{
		return($LSB{DISTRIB_ID}."/Unknown$RelFile ($sysname $release $version $machine)");
	}
	return("Unknown$RelFile ($sysname $release $version $machine)");
}

# Purpose: Display useful information
# Usage: DumpInfo();
sub DumpInfo
{
    initialize('util');
	Version();
	print "\n";
	my $pattern = "%-28s: %s\n";
	printf($pattern, 'Configuration file',$UserConfigDir.'/goldenpod.conf');
	printf($pattern, 'Podcast list',$PodcastList);
	if ($Verbose and not $NoLog)
	{
		printf($pattern, 'Logfile',GetLogFile());
	}
	printf($pattern, 'List of downloaded podcasts',$PodcastLog);
	printf($pattern, 'Target download directory',$Config{WorkingDir});
    printf($pattern, 'Perl version', sprintf('%vd',$^V));
    # Don't output useless "used only once, possible typo" warnings
    no warnings 'once';
    if (eval('use LWP;use LWP::UserAgent;1;'))
    {
        printf($pattern,'LWP version',$LWP::VERSION);
        printf($pattern,'LWP::UserAgent version',$LWP::UserAgent::VERSION);
    }
    else
    {
        printf($pattern,'LWP','missing');
    }
    my $HTMLEV = 'missing';
    if(eval('use HTML::Entities qw(decode_entities);1'))
    {
        $HTMLEV = $HTML::Entities::VERSION;
    }
    printf($pattern,'HTML::Entities',$HTMLEV);
    printf($pattern, 'OS',GetDistVer());
    eval('use Digest::MD5;');
    my $md5 = Digest::MD5->new();
    my $self = $0;
    if(not -f $self)
    {
        $self = InPath($self);
    }
    open(my $f,'<',$self);
    $md5->addfile($f);
    my $digest = $md5->hexdigest;
    close($f);
    printf($pattern,'MD5',$digest);
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# NoDownload routine
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Purpose: Adds all items in %NoDownload to the logfile
# Usage: PerformNoDownload();
sub PerformNoDownload
{
	if(not $FirstOnly)
	{
		printv("\nWriting older podcasts to the logfile...");
	}
	open(my $LOGFILE, '>>',$PodcastLog);
	foreach (keys (%NoDownload))
	{
		if(not $AlreadyDownloaded{$_})
		{
			print $LOGFILE $_."\n";
		}
	}
	if(not $FirstOnly)
	{
		printv(" done\n");
	}
	close($LOGFILE);
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Helper routines for --copy and --rmold
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Purpose: Returns the value supplied to --files or 4
# Usage: HowManyFiles();
sub HowManyFiles
{
	my $FileCount = $FileNumber ? $FileNumber : 4;
	# Unless it's an integer we can't continue
	if ($FileCount =~ /\D/)
	{
		die "Error: The option passed to --files ($FileCount) is not an integer number.\n";
	}
	return $FileCount;
}

# Purpose: Finds and sorts files in the current directory by time (newest first)
#  and returns an array containing them.
# Usage: my @List = SortedFileList();
# NOTE: Ignores files that aren't symlinks.
sub SortedFileList
{
	my $FromDir = shift;
	my (@SortedFileList, %FileCopyList);

	# For compatibility with older GoldenPods
	my $CWD = getcwd();
	chdir($FromDir);
	# Create a hash of possible filenames
	foreach my $FileName (glob("$FromDir/*"))
	{
		# Is it a link? If it isn't then we don't bother testing it
		next if not -l $FileName;
		# If the link points to something that doesn't exist them we omit it.
		if (-e (readlink $FileName))
		{
			# We don't care about directories
			if(not -d $FileName)
			{
				$FileCopyList{Cwd::realpath(readlink($FileName))} = 1;
			}
		}
	}
	# Create a sorted array of filenames
	# map { [ $_, -M $_||0 ] } keys(%FileCopyList); = that means make a two dimensional array so that $_->[0]="filename.txt" and $_->[1] is the -M value
	# sort { $a->[1] <=> $b->[1] } = sort the array we just thought of by the $_->[1] index, ie the -M times
	# map { $_->[0] } take the sorted array and convert it back to a plain list of filenames by reading out the $_->[0] values.  These are now in the right order as they are sorted
	@SortedFileList = map { $_->[0] } sort { $a->[1] <=> $b->[1] } map { [ $_, -M $_ ] } keys(%FileCopyList);
	chdir($CWD);
	return @SortedFileList;
}

# Purpose: Clean up the catalogue.
# Usage: CleanCatalogue();
sub CleanCatalogue
{
	my $CatalogueBase = shift;
	die("Catalogue didn't exist. Maybe you haven't downloaded anything yet?\n") if not -e $CatalogueBase;
	# For compatibility with older GoldenPods
	my $CWD = getcwd();
	chdir($CatalogueBase);
	my $removedSomething = false;
	print 'Cleaning up the catalogue...';
	foreach my $CurrentDirectory (glob("$CatalogueBase/*"))
	{
		chdir($CurrentDirectory);
		foreach my $CurrentFile (glob("$CurrentDirectory/*"))
		{
			next if not -l $CurrentFile;
			if(not -e readlink($CurrentFile))
			{
				$removedSomething = true;
				unlink($CurrentFile);
			}
		}
		chdir('..');
	}
	chdir($CWD);
	if (not $removedSomething)
	{
		print "nothing to clean\n";
	}
	else
	{
		print "done\n";
	}
}

# Purpose: Remove empty directories in ./
# Usage: RemoveEmptyDirs();
sub RemoveEmptyDirs
{
	my $FromDirectory = shift;
	my $removed = 0;
	foreach my $Directory (glob("$FromDirectory/*"))
	{
		next if not -d $Directory;
		if(DirIsEmpty($Directory))
		{
			rmdir($Directory);
			$removed++;
		}
	}
	return $removed;
}

# Purpose: Rewrite all playlists
# Usage: RewritePlaylists(Base CatalogueDir);
#  Call this before you delete directories to remove old playlists that are no
#  longer used.
sub RewritePlaylists
{
	my $CatalogueBase = shift;
	print 'Rewriting playlists...';
	my $CWD = getcwd();
	foreach (glob("$CatalogueBase/*"))
	{
		# Only process directories and don't process 'All'
		if(not -d $_ or basename($_) eq 'All')
		{
			next;
		}
		# This variable will be 1 if we wrote something to the playlist
		my $WrotePlaylistContent = 0;
		# The dirname, as used in the playlist filenames
		my $DirName = basename($_);
		if (-e $_.'/'.$DirName.'m3u')
		{
			unlink($_.'/'.$DirName.'.m3u');
		}
		# Skip directory if it's empty
		if(DirIsEmpty($_))
		{
			next;
		}
		# Open our new playlist
		open(my $PLAYLIST, '>', "$_/$DirName.m3u");
		chdir($_);
		# Create the playlist based upon the output of SortedFileList
		foreach my $CurrentFile (SortedFileList($_))
		{
			# Skip playlists
			next if $CurrentFile =~ /\.m3u$/;
			# Add to the playlist
			print $PLAYLIST basename($CurrentFile),"\n";
			$WrotePlaylistContent = 1;
		}
		close($PLAYLIST);
		if(not $WrotePlaylistContent)
		{
			unlink($_.'/'.$DirName.'.m3u');
		}
		chdir($CWD);
	}
	print "done\n";
}

# Purpose: Clean up our directories
# Usage: CleanupDirs();
sub CleanupDirs
{
	# Flush the output buffer faster.
	$| = 1;
	# Set the path to the Catalogue
	my $CatalogueDirectory = "$Config{WorkingDir}/catalogue/";
	# Remove dead links in the catalogue
	CleanCatalogue($CatalogueDirectory);
	# Rewrite the playlists, removing the dead files
	RewritePlaylists($CatalogueDirectory);
	# Remove empty directories
	print 'Removing empty directories...';
	my $removed = 0;
	$removed += RemoveEmptyDirs($CatalogueDirectory);
	$removed += RemoveEmptyDirs($Config{WorkingDir});
	if ($removed)
	{
		print "done\n";
	}
	else
	{
		print "nothing to remove\n";
	}
	if(-e ($Config{WorkingDir}.'/latest') and not readlink($Config{WorkingDir}.'/latest'))
	{
		unlink($Config{WorkingDir}.'/latest');
	}
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Subroutines for --copy and --rmold
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Purpose: Delete old podcasts
# Usage: DeleteOldPodcasts();
sub DeleteOldPodcasts
{
	my $CatalogueDirectory = "$Config{WorkingDir}/catalogue/";
	# Declare variables
	my (@FileList, %Files, @RemoveTheseFiles);
	my $NumberOfFiles = HowManyFiles();
	# Make sure the all All directory exists
	if(not -d $CatalogueDirectory.'/All')
	{
		die("The $CatalogueDirectory/All directory did not exist!\nAre you sure you have downloaded some podcasts?\n");
	}
	# Figure out which files are the oldest podcasts
	@FileList = reverse SortedFileList("$CatalogueDirectory/All");
	my $PodcastCount = @FileList;
	# We don't allow the user to delete the last remaining podcast.
	if ($PodcastCount == 1)
	{
		die("Only one podcast has been downloaded. If you really want to delete it you must do so manually.\n");
	}
	# Make sure we don't delete more than the total amount of podcasts minus one
	if ($NumberOfFiles >= $PodcastCount)
	{
		my $ErrorNo = $NumberOfFiles;
		while($NumberOfFiles >= $PodcastCount)
		{
			$NumberOfFiles--;
		}
		die "$ErrorNo is higher than the total amount of podcasts ($PodcastCount).\nIf you really want to clean up anyway, use --files to specify how many should be deleted\n";
	}
	# Delete the files
	my $DeletedFiles = 0;
	while ($NumberOfFiles > $DeletedFiles)
	{
		my $TargetBase = basename($FileList[0]);
		if(not $IgnorePattern or not $TargetBase =~ /$IgnorePattern/)
		{
			# If we're in dry run mode then we don't want to actually do anything.
			if ($DryRun_Mode)
			{
				print "Would delete $TargetBase\n";
			}
			else
			{
				print "Deleting $TargetBase...";
				if(unlink($FileList[0]))
				{
					print "done\n";
				}
				else
				{
					print "failed: $!\n";
				}
			}
			$DeletedFiles++;
		}
		shift @FileList;
		last if not $FileList[0];
	}
	# Stop here if we're in dry run mode
	exit if $DryRun_Mode;
	CleanupDirs();
	exit
}

# Purpose: Copy files to $CopyFilesTo
# Usage: CopyFiles();
sub CopyFiles
{
	# Declare variables
	my (@FileList, %Files, @CopyTheseFiles, %DontDeleteThese);
	my $NumberOfFiles = HowManyFiles();
	# Do a few directory checks before moving on.
	if(not -e './catalogue/All')
	{
		die "The ./catalogue/All/ directory did not exist!\nAre you sure you have downloaded some podcasts?\n";
	}
	elsif(not -e $CopyFilesTo)
	{
		die "$CopyFilesTo does not exist!\n";
	}
	elsif(not -d $CopyFilesTo)
	{
		die "$CopyFilesTo is not a directory!\n";
	}
	elsif(not -w $CopyFilesTo)
	{
		die "I can't write to the directory $CopyFilesTo!\n";
	}

	# Figure out which files are the latest podcasts
	# A sorted array of files
	@FileList = SortedFileList("$Config{WorkingDir}/catalogue/All/");
	# Create an array of the files we should copy
	my $CopiedFiles = 0;
	while (defined($FileList[$CopiedFiles]) and $CopiedFiles < $NumberOfFiles)
	{
		my $TargetBase = basename($FileList[$CopiedFiles]);
		# Check if we want to skip files matching a specific regexp
		if($IgnorePattern and not $TargetBase =~ /$IgnorePattern/)
		{
			push(@CopyTheseFiles, $FileList[$CopiedFiles]);
			$DontDeleteThese{$TargetBase} = 1;
			$CopiedFiles++;
		}
		else
		{
			shift(@FileList);
		}
	}
	# Delete routine (delete files unless we would have copied it)
	if ($CopyFiles_Delete)
	{
		# Time to delete files in the target directory

		# Babysitting the user :)
		if($CopyFilesTo =~ m#^($ENV{HOME}(/|/Documents/?.*)|/(usr|var|dev|etc|lib|sbin|sys|boot|proc|opt)/?.*)$#)
		{
			die "Not allowed to delete in the directory \"$CopyFilesTo\"\n";
		}
		# Delete the files
		while ($_ = glob("$CopyFilesTo/*"))
		{
			my $TargetBase = basename($_);
			# This one is merely cosmetic
			$_ =~ s#//#/#g;
			# If it is in the $DontDeleteThis hash or is a directory we skip it.
			if ($DontDeleteThese{$TargetBase} or -d $_)
			{
				next;
			}
			# If we're in dry run mode we don't want to actually do anything
			if ($DryRun_Mode)
			{
				print "Would delete $_\n";
			}
			else
			{
				print "Deleting $_\n";
				unlink($_) or warn "Deleting of $_ failed: $!\n";
			}
		}
	}
	# Copy the files
	foreach (@CopyTheseFiles)
	{
		my $TargetBase = basename($_);
		if (-e $CopyFilesTo.'/'.$TargetBase)
		{
			printv("Skipping pre-existing \"$TargetBase\"\n");
			next;
		}
		# If we're in dry run mode we don't want to actually do anything
		if ($DryRun_Mode)
		{
			print "Would copy $TargetBase\n";
		}
		else
		{
			print "Copying $TargetBase...\n";
			copy("$_", "$CopyFilesTo") or die "Copying failed: $!\n";
		}
	}
	# And finally, attempt to run sync once.
	if (InPath 'sync' and not $DryRun_Mode)
	{
		printv('Synchronizing disks...');
		system('sync');
	}
	printv("All done\n");
	exit
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Configuration file functions
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Purpose: Write a configuration file
# Usage: WriteConfigFile(/FILE, \%ConfigHash, \%ExplanationHash);
sub WriteConfigFile
{
	my ($File, $Config, $Explanations) = @_;

	# Open the config for writing
	open(my $CONFIG, '>', "$File") or do {
		# If we can't then we error out, no need for failsafe stuff - it's just the config file
		warn("Unable to save the configuration file $File: $!");
		return(0);
	};
	if(defined($Explanations->{HEADER})) {
		print $CONFIG "# $Explanations->{HEADER}\n";
	}
	foreach(sort(keys(%{$Config}))) {
		if(defined($Explanations->{$_})) {
			print $CONFIG "\n# $Explanations->{$_}";
		}
		print $CONFIG "\n$_=$Config->{$_}\n";
	}
	close($CONFIG);
}

# Purpose: Load a configuration file
# Usage: LoadConfigFile(/FILE, \%ConfigHash, \%OptionRegexHash, OnlyValidOptions?);
#  OptionRegeXhash can be available for only a select few of the config options
#  or skipped completely (by replacing it by undef).
#  If OnlyValidOptions is true it will cause LoadConfigFile to skip options not in
#  the OptionRegexHash.
sub LoadConfigFile
{
	my ($File, $ConfigHash, $OptionRegex, $OnlyValidOptions) = @_;

	open(my $CONFIG, '<', "$File") or do {
		warn(sprintf('Unable to read the configuration settings from %s: %s', $File, $!));
		return(0);
	};
	while(<$CONFIG>) {
		next if m/^\s*(#.*)?$/;
		next if not m/=/;
		chomp;
		my $Option = $_;
		my $Value = $_;
		$Option =~ s/^\s*(\S+)\s*=.*/$1/;
		$Value =~ s/^\s*\S+\s*=\s*(.*)\s*/$1/;
		if($OnlyValidOptions) {
			unless(defined($OptionRegex->{$Option})) {
				warn("Unknown configuration option \"$Option\" (=$Value) in $File: Ignored.");
				next;
			}
		}
		unless(defined($Value)) {
			warn("Empty value for option $Option in $File");
		}
		if(defined($OptionRegex) and defined($OptionRegex->{$Option})) {
			my $MustMatch = $OptionRegex->{$Option};
			unless ($Value =~ /$MustMatch/) {
				warn("Invalid setting of $Option (=$Value) in the config file: Must match $OptionRegex->{Option}.");
				next;
			}
		}
		$ConfigHash->{$Option} = $Value;
	}
	close($CONFIG);
}

# Purpose: Load the global config file from $UserConfigDir
# Usage: InitGlobalConfig();
sub InitGlobalConfig
{
	# Create the directory if it isn't already there
	if(not -e $UserConfigDir)
	{
		InitConfigDir();
	}
	my %OptionRegexHash = (
			WorkingDir => '.',
			DefaultVerbosity => '0|1',
			PodcastFilter => '0|1',
		);

	LoadConfigFile($UserConfigDir.'/goldenpod.conf', \%Config, \%OptionRegexHash);
	return(1);
}

# Purpose: Write the configuration file
# Usage: WriteConfig();
sub WriteGPConfig
{
	# Verify the options first
	if(not defined $Config{WorkingDir} or not length($Config{WorkingDir}))
	{
		$Config{WorkingDir} = "$ENV{HOME}/Podcasts";
	}
	if(not defined($Config{DefaultVerbosity}) or not length($Config{DefaultVerbosity}))
	{
		$Config{DefaultVerbosity} = 1;
	}
	if(not defined($Config{PodcastFilter}) or not length($Config{PodcastFilter}))
	{
		$Config{PodcastFilter} = 0;
	}
	my %Explanations = (
		WorkingDir => "The directory the podcasts will be downloaded to.\n"
		DefaultVerbosity => "How verbose GoldenPod should be by default (commandline arguments overrides this)\n# 1 means be verbose (default), 0 means be silent",
		IgnorePattern => "A regular expression pattern that GoldenPod should ignore when downloading or copying\n# podcasts. It will be applied to the filename. See the manpage for more information about it.\n# --ignore-pattern overrides this setting, and --rmold only obeys --ignore-pattern, not this configuration setting.",
		PodcastFilter => "If GoldenPod should ignore non-audio files in the feeds\n# 0 means don't ignore (default), 1 means ignore.",
		HEADER => "GoldenPod configuration file\n# DO NOT put feed URLs in this file. Those go in podcasts.conf",
	);
	# Write the actual file
	WriteConfigFile($UserConfigDir.'/goldenpod.conf', \%Config, \%Explanations);
}

# Purpose: Creates ~/.goldenpod or another $UserConfigDir
# Usage: InitConfigDir();
sub InitConfigDir
{
	if(not -e $UserConfigDir)
	{
		mkpath($UserConfigDir) or die "Unable to create the directory $UserConfigDir: $!";
	}
	# If /etc/goldenpod-podcasts.conf exists the copy that to ~/.goldenpod/podcasts.conf
	if ( -e '/etc/goldenpod-podcasts.conf' )
	{
		warn "Copying /etc/goldenpod-podcasts.conf to $UserConfigDir/podcasts.conf";
		copy('/etc/goldenpod-podcasts.conf', "$UserConfigDir/podcasts.conf") or warn "Copying of /etc/goldenpod-podcasts.conf failed: $!";
	}
	# If we don't have ~/.goldenpod/podcasts.conf (no /etc/goldenpod.conf or failure copying it)
	# then write an empty one.
	if(not -e "$UserConfigDir/podcasts.conf" )
	{
		open(my $PODCASTS_CONF, '>',"$UserConfigDir/podcasts.conf");
		print $PODCASTS_CONF "# Put your podcast feed URLs in this file seperated by newlines\n# All lines starting with # are ignored";
		close($PODCASTS_CONF);
	}
	WriteGPConfig();
}

# Purpose: Make us verbose
# Usage: Arg_Verbose();
sub Arg_Verbose
{
	$Verbose = 1;
	if(not $NoLog)
	{
		$NoLog = 1;
	}
}

# Purpose: Parse the podcasts.conf file
# Usage: my $confArray = ParseList();
sub ParseList
{
	# Open the configuration file for reading
	open(my $CONFIG, '<', $PodcastList);
	my $lineNo = 0;
	my @currentComments;
	my @list;

	# Read the configuration file and fetch feeds
	while(my $podcast = <$CONFIG>)
	{
		$lineNo++;
		chomp $podcast;
		my $match;

		if ($podcast =~ /^\s*#.*/)
		{
			push(@currentComments,$podcast);
			next;
		}
		elsif($podcast =~ /^\s*$/)
		{
			undef @currentComments;
			next;
		}
		my $hash = {
			comments => [@currentComments],
		};
		@currentComments = ();

		if ($podcast =~ m{^\s*/[^/]*[\\]?/.*})
		{
			($match = $podcast) =~ s{^\s*/([^/]*[^\\]?)/.*}{$1};
			$podcast =~ s{^\s*/([^/]*[^\\]?)/\s*}{};
			die("Error: Failed to extract regex\n") if not $match;
			eval('my $v = ""; $v =~ /'.$match.'/; 1;');
			if ($@)
			{
				die("Regex \"$match\" on line $lineNo in $PodcastList does not validate: $@\n");
			}
		}
		$hash->{podcast} = $podcast;
		$hash->{match} = $match;
		$hash->{lineNo} = $lineNo;
		push(@list,$hash);
	}
	return \@list;
}

# Purpose: Write the podcasts.conf file
# Usage: WriteList($confArray);
sub WriteList
{
	my $list = shift;
	return if not $list;
	open(my $CONFIG, '>', $PodcastList);
	print $CONFIG '# GoldenPod podcast list. Last written: '.scalar(localtime)."\n";
	print $CONFIG "# Put your podcast feed URLs in this file seperated by newlines\n";
	print $CONFIG "# All lines starting with # are ignored\n";
	foreach my $e (@{$list})
	{
		next if not defined $e;
		print $CONFIG "\n";
		foreach my $c (@{$e->{comments}})
		{
			print $CONFIG $c."\n";
		}

		if ($e->{match})
		{
			print $CONFIG '/'.$e->{match}.'/ '.$e->{podcast}."\n";
		}
		else
		{
			print $CONFIG $e->{podcast}."\n";
		}
	}
	close($CONFIG);
}

# Purpose: Handle --list to list feeds
# Usage: \&listFeeds in GetOptions
sub listFeeds
{
	print "\n";
    initialize('util');
	my @normalFeeds;
	my @fuzzyFeeds;
	my $feeds = ParseList();
	if(not @{$feeds})
	{
		die("You have no feeds added to GoldenPod\n");
	}

	foreach my $feed (@{$feeds})
	{
		if ($feed->{match})
		{
			push(@fuzzyFeeds,$feed);
		}
		else
		{
			push(@normalFeeds,$feed);
		}
	}

	if (@normalFeeds)
	{
		print "You have the following standard podcast feeds:\n";
		foreach my $feed (@normalFeeds)
		{
			print $feed->{podcast}."\n";
		}
	}
	if (@fuzzyFeeds)
	{
		print "\n" if (@normalFeeds);
		print "You have the following podcasts using the fuzzy parser:\n";
		my $format = '%-20s %s'."\n";
		printf($format,'Regex:','URL:');
		foreach my $feed (@fuzzyFeeds)
		{
			printf($format,'/'.$feed->{match}.'/',$feed->{podcast});
		}
	}
	exit(0);
}

# Purpose: Handle --addfeed to add a feed
# Usage: \&addFeed in GetOptions
sub addFeed
{
	shift;
    initialize('util');
	my $feed = shift;
	my $pattern;
	if (@ARGV)
	{
		$pattern = shift(@ARGV);
		$pattern =~ s{^\s*/(.*)/\s*}{$1};
		if(not eval('my $n = ""; $n =~ /'.$pattern.'/; 1;'))
		{
			die("The pattern \"$pattern\" does not validate: $@\n");
		}
	}
	if(not $feed =~ m{^(http|ftp)})
	{
		print "Warning: This does not look like a feed URL, adding anyway.\n";
		print "If you did not intend to add it, use this command to remove it:\n";
		print "  goldenpod --remove \"$feed\"\n\n";
	}
	my $feeds = ParseList();
	my $sources = locateSourceInFeedList($feed,$feeds);
	if ($sources)
	{
		foreach my $i (@{$sources})
		{
			$feeds->[$i] = undef;
		}
	}
	push(@{$feeds}, {
			podcast => $feed,
			match => $pattern,
			comments => ['# Added: '.scalar(localtime)],
		});
	WriteList($feeds);

	if ($pattern)
	{
		print "Added the fuzzy feed \"$feed\" with the regex pattern /$pattern/\n";
	}
	else
	{
		print "Added the feed $feed\n";
	}
	if ($sources)
	{
		if(scalar @{$sources} > 1)
		{
			print 'and removed '.scalar(@{$sources}).' old duplicates.'."\n";
		}
		else
		{
			print 'and removed one old duplicate.'."\n";
		}
	}
	exit(0);
}

# Purpose: Handle --removefeed to remove a feed
# Usage: \&removeFeed in GetOptions
sub removeFeed
{
	shift;
    initialize('util');
	my $feed = shift;
	my $feeds = ParseList();
	my $sources = locateSourceInFeedList($feed,$feeds);
	my $removed = 0;
	if ($sources)
	{
		foreach my $i (@{$sources})
		{
			$feeds->[$i] = undef;
			$removed = 1;
		}
	}
	WriteList($feeds);
	if ($removed)
	{
		print "Removed the feed \"$feed\".\n";
	}
	else
	{
		print "The feed \"$feed\" was not found.\n";
		exit(1);
	}
	exit(0);
}

# Purpose: Check if a feed contains instances of the supplied source,
# 	if it does returns an array of where in the $feeds array they are.
# Usage: my $array = locateSourceInFeedList($feed, $feeds);
sub locateSourceInFeedList
{
	my $feed = shift;
	my $feeds = shift;
	my $found = 0;
	my @sources;
	for my $n (0..@{$feeds})
	{
		my $thisfeed = $feeds->[$n];
		next if not defined $thisfeed or not defined $thisfeed->{podcast};
		if ($feed eq $thisfeed->{podcast})
		{
			push(@sources,$n);
			$found = 1;
		}
	}
	if(not $found)
	{
		return;
	}
	return \@sources;
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Download and feed functions
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Purpose: Decode XML entities
# Usage: decodedContent = decodeXMLentities(content);
sub decodeXMLentities
{
	my $thing = shift;
	if(not defined $Has{HTMLE})
	{
		if(eval('use HTML::Entities qw(decode_entities);1'))
		{
			$Has{HTMLE} = 1;
		}
		else
		{
			$Has{HTMLE} = 0;
		}
	}
	if ($Has{HTMLE})
	{
		return decode_entities($thing);
	}
	else
	{
		$thing =~ s/\&amp;/\&/g;
	}
	return $thing;
}

# Purpose: Get the title from a string
# Usage: title = ParseTitle(FEED_CONTENTS);
sub ParseTitle
{
	my $ParseTitle = shift;
	my $FeedTitle = '';
	chomp($ParseTitle);
	foreach my $t (split(/</i,$ParseTitle))
	{
		next if not $t =~ s/title[^>]*>//i;
		$FeedTitle = $t;
		if(length($FeedTitle) > 400)
		{
			my $orig = $FeedTitle;
			$FeedTitle = substr($FeedTitle,0,20);
			warn("WARNING: Unreasonably long feed title ($orig). Using $FeedTitle instead\n");
		}
		# Remove stuff in parens, as that often contains stuff like "mp3 feed"
		$FeedTitle =~ s/\([^\)]*\)//;
		$FeedTitle =~ s/<[^>]+>//g;
		$FeedTitle =~ s/\s+/_/g;
		$FeedTitle =~ s#(/|\#|\(|\)|\&|\%|\¤|\"|\|)#_#g;
		$FeedTitle =~ s/[\-\_]+(episodes?|promo|mp3|ogg|feed)*$//gi; # Remove various junk
		$FeedTitle =~ s/[\-\_]?$//; # Remove -_ in the end of the name
		# Remove more than one - or _ in a row
		$FeedTitle =~ s/-+/-/g;
		$FeedTitle =~ s/_+/_/g;
		last;
	}
	return $FeedTitle;
}

# Purpose: Ping a feed and output useful information to the user
# Usage: pingFeed(anything, URL, secondTry?)
#
# the first arg is ignored, this for use in getOpts, just leave it undef.
# URL is the url to ping
# secondTry is an int if this is our second attempt at parsing a feed.
sub pingFeed
{
	shift; my $url = shift;
	my $secondTry = shift;
	my $Output = fetchURL($url);
	exit if not $Output;
	my ($URLs, $Title) = ParseFeed($Output,'.',$url);
	my ($fURLs, $fTitle) = FuzzyParseFeed($Output,'.',$url);
	my $normalResults = scalar @{$URLs};
	my $fuzzyResults = scalar @{$fURLs};
	my $recommendedParser;
	my $baseZero = basename($0);
	my $feedList = locateFeed($Output);
	print "\n";
	if(not $normalResults and not $fuzzyResults)
	{
		if ($secondTry)
		{
			print "Found nothing using either parser this time either.\n";
			if ($secondTry > 1)
			{
				print "You may want to manually --ping any of the other feeds\n";
				print "listed above.\n";
			}
			exit(0);
		}
		if ($feedList and @{$feedList})
		{
			my $feed = @{$feedList} > 1 ? 'feeds' : 'feed';
			print "Found nothing using either parser, however, the page\nlisted the following $feed:\n";
			print $_."\n" foreach(@{$feedList});
			print "\nTrying the feed $feedList->[0]:\n";
			pingFeed(undef,$feedList->[0],scalar @{$feedList});
		}
		else
		{
			print "Found nothing using either parser\n";
		}
		exit(0);
	}
	print 'Found '.$normalResults.' files using the standard/RSS parser'."\n";
	print 'Found '.$fuzzyResults.' files using the fuzzy parser'."\n";
	(my $quotedUrl = $url) =~ s/'/\\'/g;
	if ($fuzzyResults > $normalResults)
	{
		$recommendedParser = 'fuzzy';
		print 'Recommended parser: Fuzzy parser'."\n";
		print 'Add with: '.$baseZero.' --add \''.$quotedUrl.'\' \'/someRegex/\''."\n";
		print 'To simply match/subscribe to all files, use: '.$baseZero.' --add \''.$quotedUrl.'\' \'/./\''."\n\n";
		print 'To subscribe to certain files, use a regex. You can list all files GoldenPod'."\n";
		print 'finds in the feed by running: '.$baseZero.' --fuzzydump \''.$quotedUrl.'\''."\n";
	}
	elsif($normalResults > $fuzzyResults || $normalResults == $fuzzyResults)
	{
		$recommendedParser = 'rss';
		print 'Recommended parser: standard/RSS parser'."\n";
		print 'Add with: '.$baseZero.' --add \''.$quotedUrl."'\n";
	}
	if ($normalResults > 0 && $fuzzyResults < $normalResults)
	{
		print "\n";
		print 'The reason the fuzzy parser found fewer results might be because the'."\n";
		print 'fuzzy parser limits results to only audio files. The recommended'."\n";
		print 'parser to use in these cases is still the RSS parser, as it will provide'."\n";
		print 'better results most of the time.'."\n";
	}
	elsif($normalResults > 0 && $fuzzyResults > $normalResults)
	{
		print "\n";
		print 'The fuzzzy parser found more results than the standard/RSS parser.'."\n";
		print 'This might be a bug in the standard/RSS parser. If this is an RSS feed'."\n";
		print 'please report this as a bug. Otherwise, use the fuzzy parser.'."\n";
	}
	elsif($fuzzyResults == $normalResults)
	{
		print "\n";
		print 'When both parsers return the same amount of results, the recommended'."\n";
		print 'parser is the standard/RSS parser, as it is more restrictive and'."\n";
		print 'accurate.'."\n";
	}
	if ($recommendedParser eq 'fuzzy' && $feedList && @{$feedList} > 0)
	{
		print "\n";
		my $feed = @{$feedList} > 1 ? 'feeds' : 'feed';
		my $other = @{$feedList} > 1 ? 'other' : 'another';
		my $oneOf = @{$feedList} > 1 ? ' one of' : '';
		print "NOTE: This URL referenced $other $feed. You may want to try$oneOf the $feed\n";
		$feed = ucfirst($feed);
		print "listed below instead of using the fuzzy parser directly on this URL.\n$feed: ";
		print "\n" if $feed eq 'Feeds';
		foreach my $f(@{$feedList})
		{
			print $f."\n";
		}
	}
	exit(0);
}

# Purpose: Parse a HTML page, looking for <link rel="alternate"> entries
# 	for feeds
# Usage: my $feedURLs = locateFeed(FEED_CONTENTS);
sub locateFeed
{
	my $contents = shift;
	my @URLs;

	foreach my $line (split(/(<|>|\n)/,$contents))
	{
		next if not $line =~ /rel="alternate"/i;
		my $type = $line;
		$type =~ s/.*type=["']([^"']+)["'].*/$1/i;
		next if not $type;
		if(not $type =~ /(rss|atom)\+xml/i and not $line =~ /rss/i)
		{
			next;
		}
		$line =~ s/.*href=["'](\S+)["'].*/$1/gi;
		next if not $line;
		push(@URLs,$line);
	}
	return \@URLs;
}

# Purpose: Parse a feed
# Usage: my($URLs,$Title) = ParseFeed(FEED_CONTENTS);
#  $Title can be undef. $URLs is an arrayref, can be empty.
sub ParseFeed
{
	my $FeedContents = shift;

	if(not $FeedContents)
	{
		return([],undef);
	}

	my $title;
	my @URLs;
	# This is used to avoid dupes in @URLs
	my %URLList;
	# We don't care about newlines
	$FeedContents =~ s/(\r\n|\r|\n)/ /g;

	# Try to find the title of the podcast
	my $FeedTitle = ParseTitle($FeedContents);

	# Do the real parsing and add to @urls
	# We want to extract all url='s
	foreach my $CurrUrl (split(/(<|>)/,$FeedContents))
	{
		next if not $CurrUrl =~ /(url=["'])/i;
		my $quote = $CurrUrl;
		$quote =~ s/.*url=(["']).*/$1/i;
		$CurrUrl =~ s/.*url=$quote([^$quote]+)$quote.*/$1/i;
		$CurrUrl = decodeXMLentities($CurrUrl);
		# Filter away non-audio feeds if the user wants it.
		if ($Config{PodcastFilter})
		{
			next if not basename($CurrUrl) =~ /.*\.$AudioRegex.*/i;
		}
		# Filter away stuff in $IgnorePattern
		if ($IgnorePattern)
		{
			next if basename($CurrUrl) =~ /$IgnorePattern/;
		}
		# Add the title string to the PodNames array (if we have found the title)
		$PodNames{$CurrUrl} = $FeedTitle;
		if(not $URLList{$CurrUrl})
		{
			push(@URLs, $CurrUrl);
			$URLList{$CurrUrl} = 1;
		}
	}
	# The current @URLs has the oldest first. Reverse it before returning it.
	@URLs = reverse(@URLs);
	return(\@URLs, $FeedTitle);
}

# Purpose: Fuzzy parse a feed. Gets audio URLs out of a non-RSS (ie. XML, HTML,
# 	or any text format really) address
# Usage: my($URLs,$Title) = FuzzyParseFeed(FEED_CONTENTS,regexToMatch,sourceURL);
sub FuzzyParseFeed
{
	my $FeedContents = shift;

	if(not $FeedContents)
	{
		return([],undef);
	}

	my $match = shift;
	my $fullURL = shift;
	my $URL = $fullURL;
	if(not $URL =~ s{^(\w+://[^/]+).*}{$1} or not $URL =~ s{^([^/]+).*}{$1})
	{
		$URL = undef;
	}
	my $title;
	my @URLs;
	# This is used to avoid dupes in @URLs
	my %URLList;

	# Try to find the title of the podcast
	my $FeedTitle = ParseTitle($FeedContents);

	# Do some elaborate fuzzy parsing of the content
	foreach my $e (split(/(\s+|<|>|\)|\(|"|')/,$FeedContents))
	{
		# Get URLs
		if (
			# This one extracts URLs not containing whitespace and \"'
			not $e =~ s#.*(https?[^\\"'\s]+)["']?.*#$1#gi and
			# The same as above, but allows "'
			not $e =~ s#.*(https?\S*)["']?.*#$1#gi and
			# /something/... - ie. without domain and http://
			not $e =~ s#.*["'](/\S+\.\S+)["'].*#$1#
		)
		{
			next;
		}
		# Only audio URLs
		next if not $e =~ /.*[^(www)]\.$AudioRegex.*/i;
		# Only stuff matching
		next if not $e =~ /$match/;
		chomp($e);

		# If it's a relative URL, do some additional processing
		if ($e =~ m{^/} or not $e =~ m{/})
		{
			# No URL? Then we can't handle it
			if(not $URL)
			{
				next;
			}
			# If fulLURL ends with / use that
			if ($fullURL =~ m{/$})
			{
				$e = $fullURL.$e;
			}
			# If there's .. then try fullURL
			elsif($e =~ m{^/?\.\.} )
			{
				my $u = $fullURL;
				$u =~ s{[^/]+$};
				$e = $u.$e;
			}
			else
			{
				# fall back to URL/e
				$e = $URL.'/'.$e;
			}
		}
		$e = decodeXMLentities($e);
		# Done, add it to the list
		if(not $URLList{$e})
		{
			push(@URLs,$e);
			$URLList{$e} = 1;
		}
	}
	return(\@URLs,$FeedTitle);
}

# Purpose: Download podcasts contained in the supplied array reference
# Usage: DownloadPodcasts(ARRAYREF);
sub DownloadPodcasts
{
	my $DownloadThese = shift;
	my $noTotal = shift;
	my $NeedToDownload = scalar(@{$DownloadThese});
	my @DownloadedFiles;
	# Output the amount of files we need to download
	if ($NeedToDownload and $Verbose)
	{
		print "\n";
	}
	if(not $noTotal)
	{
		print "Found a total of ";
		if ($NeedToDownload > 1)
		{
			print "$NeedToDownload new podcasts to download.\n\n";
		}
		elsif($NeedToDownload == 1)
		{
			print "$NeedToDownload new podcast to download.\n\n";
		}
	}

	# Open the logfile for writing
	open(my $LOGFILE, '>>',$PodcastLog);

	# Download the podcasts
	foreach my $URL (@{$DownloadThese})
	{
		if (not $DryRun_Mode)
		{
			print "Downloading $URL\n" if not $Verbose;
			# Curl returns nonzero on failure
			my $DownloadStatus = DownloadURL($Config{WorkingDir}.'/'.$date, $URL);
			if($DownloadStatus)
			{
				next;
			}
			else
			{
				push(@DownloadedFiles, $URL);
			}
			print $LOGFILE "$URL\n";
			# If we're in --first-only we add it to $AlreadyDownloaded{$URL} so that NoDownload doesn't add it
			if ($FirstOnly and $DownloadStatus)
			{
				$AlreadyDownloaded{$URL} = 1;
			}
		}
		else
		{
			print "Would download $URL\n";
		}
	}
	close($LOGFILE);
	return(\@DownloadedFiles);
}

# Purpose: Create the catalogue entries for the current date
# Usage: CreateCatalogue();
sub CreateCatalogue
{
	my $Downloaded = shift;
	# Filename filter
	# Remove junk after .EXTension and convert %20 to _
	foreach (glob($Config{WorkingDir}.'/'.$date.'/*'))
	{
		my $OldName = basename($_);
		my $NewName = basename($_);
		$NewName =~ s/\?.*//g;
		$NewName =~ s/(%20|\s+)/_/g;
		if(not $NewName eq $OldName)
		{
			rename($OldName, $NewName);
		}
	}
	# Make the ./latest symlink point to $date
	if (-l $Config{WorkingDir}.'/latest')
	{
		unlink $Config{WorkingDir}.'/latest';
	}
	symlink( $Config{WorkingDir}.'/'.$date, $Config{WorkingDir}.'/latest');

	# Create our catalogue directory (podcasts sorted in named directories)
	mkpath($Config{WorkingDir}.'/catalogue/All');

	# For every file, make sure it has a catalogue entry.
	foreach my $OrigName (@{$Downloaded})
	{
		# We don't want to do anything to playlists
		next if ($OrigName =~ /\.m3u$/);

		my $BaseName = basename($OrigName);
		my ($Existed, $PodBaseName);
		# Get the base name of the podcast
		if ($PodNames{$OrigName})
		{
			$PodBaseName = $PodNames{$OrigName};
		}
		else
		{
			$PodBaseName = $BaseName;
			# If we couldn't get the podcast name from the feed then try even
			# harder here.
			$PodBaseName =~ s/\d+//g;			# Remove digits
			$PodBaseName =~ s/[\-\_]+(show|promo)*$//gi;	# Remove various junk
			$PodBaseName =~ s/__+/_/g;			# Do some additional cleaning
			$PodBaseName =~ s/[\-\_].$//;			# Remove -_ in the end of the name
			$PodBaseName = "\u$PodBaseName";		# Make the first character be uppercase
			# Give up if we still don't have a name
			if(not $PodBaseName)
			{
				$PodBaseName = 'Unknown';
			}
		}
		mkpath($Config{WorkingDir}.'/catalogue/'.$PodBaseName);
		# We don't want to do anything if it already exists
		if (not -e $Config{WorkingDir}.'/catalogue/'.$PodBaseName.'/'.$BaseName)
		{
			# Try to get the extension
			my $NameExtension = $BaseName;
			$NameExtension =~ s/.*(\.\w)/$1/;
			# Symlink the files and write the playlist
			symlink($Config{WorkingDir}.'/'.$date.'/'.$BaseName,
				$Config{WorkingDir}.'/catalogue/'.$PodBaseName.'/'.$BaseName);
			if (-e $Config{WorkingDir}.'/catalogue/'.$PodBaseName.'/latest'.$NameExtension)
			{
				unlink( $Config{WorkingDir}.'/catalogue/'.$PodBaseName.'/latest'.$NameExtension);
			}
			symlink ($Config{WorkingDir}.'/'.$date.'/'.$BaseName,
				$Config{WorkingDir}.'/catalogue/'.$PodBaseName.'/latest'.$NameExtension);
			open(my $PLAYLIST, '>>',$Config{WorkingDir}.'/catalogue/'.$PodBaseName.'/'.$PodBaseName.'.m3u');
			print $PLAYLIST "$BaseName\n";
			close($PLAYLIST);
		}
		# Add it to All too if needed
		if (not -e $Config{WorkingDir}.'/catalogue/All/'.$BaseName)
		{
			symlink($Config{WorkingDir}.'/'.$date.'/'.$BaseName,
				$Config{WorkingDir}.'/catalogue/All/'.$BaseName);
		}
	}
}

# Purpose: Do a quick download from a feed
# Usage: quickDownload(anything,URL);
sub quickDownload
{
	shift;
	my $URL = shift;

	# Initialize
	initialize('full');

	# Download data
	my $Output = fetchURL($URL);

	# Skip if we didn't recieve anything
	exit if not $Output;

	my $download;

	my ($URLs, $Title) = FuzzyParseFeed($Output,'.',$URL);
	my ($fURLs, $fTitle) = ParseFeed($Output);

	if(not @{$URLs} and not @{$fURLs})
	{
		die("No podcasts found in feed\n");
	}
	elsif(@{$URLs} > @{$fURLs} || @{$URLs} == @{$fURLs})
	{
		$download = shift(@{$URLs});
	}
	else
	{
		$download = shift(@{$fURLs});
	}
	if ($AlreadyDownloaded{$download})
	{
		print "\nGoldenPod has already downloaded the first podcast in this feed.\n";
		print "Nothing to do.\n";
		exit(0);
	}
	my $files = DownloadPodcasts([ $download ], true);
	if(scalar(@{$files}))
	{
		CreateCatalogue($files);
	}
	exit(0);
}

# Purpose: Load the list of already downloaded podcasts into %AlreadyDownloaded
# Usge: loadALreadyDownloaded();
sub loadAlreadyDownloaded
{
	# Load the %AlreadyDownloaded hash.
	if ( -e $PodcastLog)
	{
		# Open the logfile containing previously downloaded files
		open(my $LOGFILE, '<', $PodcastLog);
		# Add them to a hash
		%AlreadyDownloaded = map { chomp; $_=>1 } <$LOGFILE>;

		# Close the logfile
		close $LOGFILE;
	}
}

# Purpose: Fetch and parse the feeds
# Usage: FetchFeeds();
sub FetchFeeds
{
	# The list of podcasts to download
	my @DownloadQueue;

	# The list of podcasts available
	my @PodcastsAvailable;

	# The list of podcasts to download in first-only mode
	my @FirstOnly;

	loadAlreadyDownloaded();

	# Open the configuration file for reading
	my $config = ParseList();

	# Read the configuration file and fetch feeds
	foreach my $entry (@{$config})
	{
		my $podcast = $entry->{podcast};
		my $match = $entry->{match};

		# Download data
		my $Output = fetchURL($podcast);

		# Skip if we didn't recieve anything
		next if not $Output;

		my($URLs,$Title);
		# Parse the feed and get the URLs. Skip the feed if we didn't get any.
		if (defined $match)
		{
			($URLs, $Title) = FuzzyParseFeed($Output,$match,$podcast);
		}
		else
		{
			($URLs, $Title) = ParseFeed($Output);
		}

		# Push those URLs not already downloaded into @PodcastsAvailable,
		# queueing them for checking and possible downloading later
		my $newP = 0;
		foreach my $url (@{$URLs})
		{
			if(not $AlreadyDownloaded{$url})
			{
				push(@PodcastsAvailable, $url);
				if (not $match or $url =~ /$match/)
				{
					$newP++;
				}
			}
		}
		push(@FirstOnly, ${$URLs}[0]) if $newP;
		if ($newP == 0)
		{
			if(scalar(@{$URLs}) > 0)
			{
				printv("No new podcasts found.\n");
			}
			else
			{
				printv("No podcasts found in feed.\n");
			}
		}
		else
		{
			my $podcast = $newP == 1 ? 'podcast' : 'podcasts';
			print $newP." new $podcast found\n";
		}
	}

	# If the config is empty, die.
	if (not scalar(@{$config}))
	{
		die "The podcast list in $PodcastList is empty, nothing to do.\n";
	}

	# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	# Find out if we need to download anything
	# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


	if($FirstOnly)
	{
		@DownloadQueue = @FirstOnly;
	}
	else
	{
		@DownloadQueue = @PodcastsAvailable;
	}

	# If we're in NoDownload or FirstOnly mode, copy the contents of the URLs array into the
	# NoDownload hash.
	if($NoDownloadMode or $FirstOnly)
	{
		%NoDownload = map { $_ => 1 } @PodcastsAvailable;
		if($NoDownloadMode)
		{
			PerformNoDownload();
			exit(0);
		}
	}
	return(\@DownloadQueue);
}

# Purpose: Initialize goldenpod
# Usage: initialize($mode)
# $mode is one of
#   full: the default mode
#   util: any secondary utilities, will initialize as usual but skip logging
sub initialize
{
    state $initialized;
    my $mode = shift;
    if (!defined $mode || ($mode ne 'full' && $mode ne 'util'))
    {
        die('initialize() called without a proper $mode');
    }
    if ($initialized)
    {
        if ($initialized ne $mode)
        {
            die('attempted to re-initialize with a new mode');
        }
        return;
    }
    $initialized = $mode;
    # Set the date
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    # Make the year human-readable
    $year += 1900;
    # Make the month 01-12 instead of 0-11
    $mon++; $mon = PrefixZero($mon);
    # Make the day of the month always two digits
    $mday = PrefixZero($mday);
    # Finally, the date
    $date = "$year-$mon-$mday";
	# Load the config
	$UserConfigDir = $ENV{HOME}.'/.goldenpod';
	InitGlobalConfig();
	if(not defined $Config{WorkingDir})
	{
		$Config{WorkingDir} = $ENV{HOME}.'/Podcasts';
		warn('Failed to locate WorkingDir, falling back to '.$Config{WorkingDir});
	}

	# Do base initialization
    $PodcastLog = $UserConfigDir.'/podcasts.log';
    $PodcastList = $UserConfigDir.'/podcasts.conf';

	# Be verbose by default if the user wants to
	if ($Config{DefaultVerbosity})
	{
		Arg_Verbose();
	}
	# Create WorkingDir if it doesn't exist
	mkpath($Config{WorkingDir});
	# Require +w on WorkingDir
	if(not -w $Config{WorkingDir})
	{
		die("Unable to write to: $Config{WorkingDir}: Permission denied\n");
	}
	# Get the realpath to WorkingDir in case it is relative
	$Config{WorkingDir} = realpath($Config{WorkingDir}) or die("Unable to fix the path of $Config{WorkingDir}\n");
    # Prepare logging if needed
    if ($mode eq 'full')
    {
        PrepareLogging();
    }
    # Load our alredy downloaded files
	loadAlreadyDownloaded();
}

# Purpose: The main function
# Usage: main();
sub main
{
	# print \n if we're in verbose mode
	printv("\n");

	# Conflicting commandline arguments
	if ($FirstOnly and $NoDownloadMode)
	{
		die "Conflicting options: --first-only and --no-download. Please read --help\n";
	}
	if ($CopyFilesTo and $RemoveOldFiles)
	{
		die "Conflicting options: --copy and --rmold. You can't use both at the same time.\n";
	}
	# Useless usage of some options
	if ($CopyFiles_Delete and not $CopyFilesTo)
	{
		warn "Useless use of --delete without --copy\n";
	}
	if ($FileNumber and not $CopyFilesTo and not $RemoveOldFiles)
	{
		warn "Useless use of --files without --copy or --rmold\n";
	}
	if ($Verbose and $NoLog == 2)
	{
		warn "Useless use of --nolog in verbose mode\n";
	}

	# DeleteOldPodcasts() should never use $IgnorePattern from the config
	# file, so run it before initializing it from the conf file.
	if ($RemoveOldFiles)
	{
		DeleteOldPodcasts();
	}

	# if --ignore-pattern was not supplied but $IgnorePattern is set in the
	# config file.
	if (not $IgnorePattern)
	{
		if ($Config{IgnorePattern})
		{
			eval {
				qr/$Config{IgnorePattern}/
			} or die "The regexp IgnorePattern in the configuration file is invalid ($@)\n";
			$IgnorePattern = $Config{IgnorePattern};
		}
	}

    # Initialize
	initialize('full');

	# If we're copying then run the CopyFiles() subroutine
	if ($CopyFilesTo)
	{
		CopyFiles();
	}

	if(not -e $PodcastList)
	{
		die "The configuration file \"$PodcastList\" does not exist!\nPlease read the manpage included to get instructions on how to set one up.\n";
	}

	# Fetch and parse our feeds.
	my $DownloadQueue = FetchFeeds();
	if(scalar(@{$DownloadQueue}) == 0)
	{
		if(not $Verbose)
		{
			print "Nothing to download\n";
		}
		exit(0);
	}
	# Then download the podcasts
	my $Downloaded = DownloadPodcasts($DownloadQueue);
	if(scalar(@{$Downloaded}))
	{
		CreateCatalogue($Downloaded);
		# NoDownload if in --first-only
		if($FirstOnly)
		{
			PerformNoDownload();
		}
	}
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Initialize program
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Parse commandline arguments
GetOptions (
	'verbose|v' => sub {  Arg_Verbose() },
	'version' => sub { Version(); exit 0},
	'help|h' => sub { Help(); exit 0; },
	'help-all' => sub { Help(1); exit 0; },
	'no-download|nodownload|w' => sub { Arg_Verbose(); $NoDownloadMode = 1 },
	'dry-run|dryrun|u' => sub { Arg_Verbose(); $DryRun_Mode = 1},
	'first-only|firstonly|first|f' => \$FirstOnly,
	'nolog|l' => sub { $NoLog = 2},
	'copy|c=s'=> \$CopyFilesTo,
	'clean' => sub {
        initialize(),
		CleanupDirs();
		exit(0);
	},
	't|list|listfeeds' => \&listFeeds,
	'a|add|addfeed=s' => \&addFeed,
	'r|remove|rmfeed|removefeed=s' => \&removeFeed,
	'files|n=s' => \$FileNumber,
	'delete|d' => \$CopyFiles_Delete,
	'rmold|o' => \$RemoveOldFiles,
	'fuzzydump=s' => sub {
		shift; my $url = shift;
		my $Output = fetchURL($url);
		exit if not $Output;
		my ($URLs, $Title) = FuzzyParseFeed($Output,'.',$url);
		if (not @{$URLs})
		{
			print "Found no audio files\n";
			exit(0);
		}
		print "Page is '$Title', found the following audio files:\n";
		foreach my $f (@{$URLs})
		{
			print $f."\n";
		}
		exit(0);
	},
	'rssdump=s' => sub {
		shift; my $url = shift;
		my $Output = fetchURL($url);
		exit if not $Output;
		my ($URLs, $Title) = ParseFeed($Output,'.',$url);
		if (not @{$URLs})
		{
			print "Found no files\n";
			exit(0);
		}
		print "Page is '$Title', found the following files:\n";
		foreach my $f (@{$URLs})
		{
			print $f."\n";
		}
		exit(0);
	},
	'ping=s' => \&pingFeed,
	'silent|s' => sub
	{
		$Verbose = 0;
		if(not $NoLog == 2)
		{
			$NoLog = 0;
		}
	},
	'ignore-pattern|ignorepattern|i=s' => sub {
		shift;
		$IgnorePattern = shift;
		eval { qr/$IgnorePattern/ } or die "The regexp supplied to --ignore-pattern is invalid ($@)\n";
	},
	# Display some simple statistics
	'stats' => sub {
        initialize('util');
        die "The \"catalogue/All\" directory did not exist, are you sure you have downloaded anything?\n" if not -d "$Config{WorkingDir}/catalogue/All";
		my @PodcastFileList = SortedFileList($Config{WorkingDir}.'/catalogue/All');
		print "\nYou have ", scalar @PodcastFileList, " files\n";
		print 'The newest file is: ', basename($PodcastFileList[0]),"\n";
		print 'The oldest file is: ', basename($PodcastFileList[-1]),"\n";
		# Find filesizes
		my $USED_DISKSPACE = 0;
		foreach (glob($Config{WorkingDir}.'/catalogue/All/*')) {
			# Skip the file if -s doesn't return anything useful.
			if (-s $_) {
	        		$USED_DISKSPACE = $USED_DISKSPACE+-s $_;
			}
		}
		$USED_DISKSPACE = $USED_DISKSPACE/1024/1024;
		print 'The files are using ', sprintf ('%.0f', $USED_DISKSPACE), " MB of diskspace\n";
		exit 0
	},
	'quick=s' => \&quickDownload,
	# Display information about which config files and settings we would use
	'dumpinfo|debuginfo' => sub { DumpInfo(1); exit 0 },
	'prefer-curl|prefercurl' => sub { $downloader = 'curl' },
) or die 'Run ', basename($0), " --help for help\n";

main();
__END__
=encoding utf8

=head1 NAME

goldenpod - a command-line podcast client written in perl

=head1 SYNOPSIS

B<goldenpod> [I<OPTIONS>]

=head1 DESCRIPTION

B<GoldenPod> is a command-line podcast client (or podcast aggregator, or
podcatcher, feel free to pick whichever name you want) written in perl.

It reads from configuration files in ~/.goldenpod, and saves podcasts to
the directory defined there (by default ~/Podcasts/).

=head1 BASIC USE

=head2 Adding feeds

Adding podcast feeds to goldenpod is simple. Just run:

	goldenpod --add [URL]

And the URL supplied is added to goldenpod, and it will download podcasts
from it the next time it is started.

If the podcast does not have a proper feed, you can try to use the
goldenpod fuzzy parser (see the PARSERS section further down for information
about it). The syntax for that is:

	goldenpod --add [URL] /REGEX/

If you have added a feed using the fuzzy parser and want the standard parser, or
the other way around, simply use the --add parameter again, with the syntax you
want and any existing entries of that URL will be removed first.

If you are uncertain about which parser to choose, run:

	goldenpod --ping [URL]

It will then tell you which parser it recommends for the URL supplied.

=head2 Removing feeds

Removing a feed is just like --add, use:

	goldenpod --remove [URL]

This will remove all feeds (no matter which parser is used) at the URL
supplied.

=head2 Listing feeds

To get a list of all the feeds you have added, along with which parser
they are using, run:

	goldenpod --list

=head2 Downloading podcasts

To download podcasts from the feeds you have added, run goldenpod without
any parameters.

=head1 OPTIONS

=over

=item B<-h, --help>

Display the help screen

=item B<-v, --verbose>

Be verbose.

=item B<-s, --silent>

Be silent.

=item B<-l, --nolog>

Don't create a message logfile when in non-verbose mode. No effect unless in
B<--silent> mode.

=item B<-a, --add, --addfeed I<FEED> (I<REGEX>) >

Add the feed URL supplied to goldenpod's feed list. Optionally you may supply
a second parameter to this option, a regular expression. If this is present
then the feed will be added to use the fuzzy parser (see the PARSERS section)
with that regular expression.

=item B<-r, --remove, --removefeed, --rmfeed I<FEED> >

Removes the feed URL supplied from goldenpod's feed list.

=item B<-t, --list, --listfeeds>

Prints a list of feeds in goldenpod, along with which parser the feeds are
using.

=item B<--ping I<URL>>

This downloads URL and parses it once with each parser, then tells you
which parser it recommends that you to use. It will also attempt feed
autodiscovery if the URL is not an RSS feed.

=item B<--prefer-curl>

Prefer to use curl over LWP if present. GoldenPod uses LWP by default if it is
available, and falls back to curl if LWP is missing. This parameter reverses
this behaviour, using curl if it is available and falling back to LWP if curl
is missing.

=item B<--debuginfo>

Print the configuration and podcast list filenames that GoldenPod would read,
in addition to the logfiles it would use and write to. Additionally it includes
some information about versions of libraries and utilities that gpgpwd uses.

=item B<--stats>

Print some simple statistics: How many files you currently have in your
catalogue, which file is the latest, which file is the oldest and how much
space they are using.

=item B<-u, --dry-run>

Used along with --copy or --rmold. Just display what would be done, don't
actually copy or delete anything.  Implies B<--verbose>

=item B<-w, --no-download>

Mark all podcasts as downloaded.  Useful when you want to subscribe to a
podcast but not download all of the old issues. You can edit the logfile
afterwards and remove those you want to download.  Implies B<--verbose>.

=item B<-f, --first-only>

Download the first file in any feed, and then permanently ignore the others.
If you at any later point want to download older files, you will need to edit
the logfile. Unlike --no-download this does not imply --verbose.

=item B<--quick I<URL>>

Download the first podcast found in URL and then exit. This can be useful
for one-off downloads, or to just check out the latest episode of a podcast
before adding a full subscription. This will try both parsers, the one that
finds the most will be used.

=item B<-c, --copy I</path>>

Copy the last N downloaded files to /path/ and delete the other files in
/path/.  This is very useful for synchronizing the latest podcasts with your
MP3 player.  N is either 4 by default or optionally the value supplied to
--files.

=item B<-d, --delete>

For use with --copy, delete all files in /path/ unless they are one of the
files we are about to copy. It will not allow you to delete files directly in
your home directory (but all subdirectories except Documents) nor any files in
/usr /var /dev /etc /lib /sbin /sys /boot or /proc.

=item B<-n, --files I<N>>

For use with --copy or --rmold. Copy/delete N files instead of 4.

=item B<--fuzzydump I<URL>>

This uses the GoldenPod fuzzy parser to list audio files found in I<URL>.
The fuzzy parser is the one invoked when using the "/REGEX/ URL" syntax
in the podcasts.conf file (ie. to fetch podcasts from a non-RSS source).

You can use this to see if GoldenPod finds anything in the URL, and
to find out what your /REGEX/ for the URL should be.

=item B<--rssdump I<URL>>

This uses the GoldenPod standard/RSS parser to list files found in I<URL>.

You can use this to see if GoldenPod finds anything in the URL. It is mostly
useful to find out if GoldenPod has problems parsing a feed, or if a certain
feed needs the fuzzy parser to work properly.

=item B<-o, --rmold>

Delete N old podcasts, where N is either 4 or optionally the value supplied to
--files. Use this to free up some disk space taken up by old podcasts.  This
will obey --ignore-pattern but not the I<IgnorePattern> configuration option.
It will always leave at least the latest podcast.

=item B<-i, --ignore-pattern>

Ignore files matching the regular expression pattern supplied when downloading
or copying podcasts.

For example: "--ignore-pattern foo" would ignore any podcast containing the
word "foo" in its filename, or for a more advanced example: "--ignore-pattern
'(foo|bar|baz)'" would ignore all podcasts containing either of the words foo,
bar or baz in it's filename. Like everything else the --ignore-pattern
expression is case sensitive.  If you would like to match both Foo and foo you
could do: "--ignore-pattern [f|F]oo".  --ignore-pattern supports standard perl
regular expressions (will be executed within m//).

=item B<--clean>

Clean up the podcasts directory and catalogue. This is useful if you removed
files by hand. It will remove empty directories, remove orphaned symlinks in
the catalogue and rewrite playlists. This is also done after --rmold.

=back

=head1 PARSERS

GoldenPod comes with two different feed parsers.

=head2 STANDARD/RSS PARSER

This is the default parser. It parses any standard RSS feed used by podcasts.
This is the most commonly used parser, and is preferred whenever possible.
This is used unless the fuzzy parser is explicitly requested.

=head2 FUZZY PARSER

This is a much more liberal parser. It searches for URL-like strings in any
document that matches a set regular expression, allowing you to subscribe
to podcasts that does not have their own feed, or to subscribe to
audio-files found on a page regulary for download. This parser
allows you to subscribe to sites that has the links to the audio
files in a HTML, XML or other text-based format.

It has limitations however, it only finds audio files and it requires a regular
expression. It will only download files that match the regular expression that
you supply to it (if you want it to download all audio files it finds, make the
regular expression a single "." (without the quotes) to make it match them all).

To use the fuzzy parser, supply a regular expression as the second parameter
to I<--add> (or, if you edit the podcasts.conf file by hand, use the "/regex/
URL" syntax).

=head1 EXAMPLE podcasts.conf

	# Put your podcast feed URLs in this file seperated by newlines
	# All lines starting with # are ignored

	# Paranormal podcast
	http://paranormalpodcast.libsyn.com/rss

	# Perlcast (perl related podcast)
	http://www.perlcast.com/rss/current.xml

	# LUG Radio
	http://www.lugradio.org/episodes.rss

	# Jawbone radio
	http://feeds.feedburner.com/JawboneRadio

	# SOE podcast. Not using a feed, but extracted by GoldenPod from the
	# HTML, locating any audio file matching the perl regex /96/
	/96/ http://www.station.sony.com/en/podcasts.vm

=head1 HELP/SUPPORT

If you need additional help, please visit the website at
L<http://random.zerodogg.org/goldenpod>

=head1 DEPENDENCIES

Besides from perl it requires either LWP (preferred) or curl.

=head1 INCOMPATIBILITIES

The configuration syntax changed in 0.7, and GoldenPod versions older than that
will fail to read the current configuration file. 0.6 and older also did not
have support for fuzzy parsing (the "/REGEX/ URL" syntax) and will fail to
download those entries.

The directories created by 0.7 and older will always be YYYY-MM-DD, while 0.1
to 0.6 could be YYYY-M-D.

=head1 BUGS AND LIMITATIONS

If you find a bug, please report it at L<http://random.zerodogg.org/goldenpod/bugs>

=head1 AUTHOR

B<GoldenPod> is written by Eskild Hustvedt I<<code aatt zerodogg d0t org>>

=head1 FILES

=over

=item I<~/.goldenpod/podcasts.conf>

The file containing a list of podcast feeds.

=item I<~/.goldenpod/goldenpod.conf>

The configuration file for GoldenPod, which contains the location to save
streams to, your desired verbosity level, the default IgnorePattern and if you
want to use the PodcastFilter.

=item I<~/.goldenpod/podcasts.log>

The logfile containing the URLs for the podcasts already downloaded.

=item I<~/.goldenpod/goldenpod.log>

The logfile written to when in silent mode.

=item I</etc/goldenpod-podcasts.conf>

This is a file in the same syntax as podcasts.conf. It is copied to
~/.goldenpod/podcasts.conf the first time goldenpod is run if it exists. This
file is never read directly, and has no effect whatsoever after the first time
goldenpod is run.

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) Eskild Hustvedt 2005, 2006, 2007, 2009, 2010

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see L<http://www.gnu.org/licenses/>.
