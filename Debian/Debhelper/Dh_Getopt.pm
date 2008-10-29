#!/usr/bin/perl -w
#
# Debhelper option processing library.
#
# Joey Hess GPL copyright 1998-2002

package Debian::Debhelper::Dh_Getopt;
use strict;

use Debian::Debhelper::Dh_Lib;
use Getopt::Long;

my %exclude_package;

sub showhelp {
	my $prog=basename($0);
	print "Usage: $prog [options]\n\n";
	print "  $prog is a part of debhelper. See debhelper(7)\n";
	print "  and $prog(1) for complete usage instructions.\n"; 
	exit(1);
}

# Passed an option name and an option value, adds packages to the list
# of packages. We need this so the list will be built up in the right
# order.
sub AddPackage { my($option,$value)=@_;
	if ($option eq 'i' or $option eq 'indep') {
		push @{$dh{DOPACKAGES}}, getpackages('indep');
		$dh{DOINDEP}=1;
	}
	elsif ($option eq 'a' or $option eq 'arch') {
		push @{$dh{DOPACKAGES}}, getpackages('arch');
		$dh{DOARCH}=1;
	}
	elsif ($option eq 'p' or $option eq 'package') {
		push @{$dh{DOPACKAGES}}, $value;
	}
	elsif ($option eq 's' or $option eq 'same-arch') {
		push @{$dh{DOPACKAGES}}, getpackages('same');
		$dh{DOSAME}=1;
	}
	else {
		error("bad option $option - should never happen!\n");
	}
}

# Adds packages to the list of debug packages.
sub AddDebugPackage { my($option,$value)=@_;
	push @{$dh{DEBUGPACKAGES}}, $value;
}

# Add a package to a list of packages that should not be acted on.
sub ExcludePackage { my($option,$value)=@_;
	$exclude_package{$value}=1;
}

# Add another item to the exclude list.
sub AddExclude { my($option,$value)=@_;
	push @{$dh{EXCLUDE}},$value;
}

# Add a file to the ignore list.
sub AddIgnore { my($option,$file)=@_;
	$dh{IGNORE}->{$file}=1;
}

# This collects non-options values.
sub NonOption {
	push @{$dh{ARGV}}, @_;
}

# Parse options and set %dh values.
sub parseopts {
	my %options=%{shift()} if ref $_[0];

	my $ret=GetOptions(
		"v" => \$dh{VERBOSE},
		"verbose" => \$dh{VERBOSE},

		"no-act" => \$dh{NO_ACT},
	
		"i" => \&AddPackage,
		"indep" => \&AddPackage,
	
		"a" => \&AddPackage,
		"arch" => \&AddPackage,
	
		"p=s" => \&AddPackage,
	        "package=s" => \&AddPackage,
		
		"N=s" => \&ExcludePackage,
		"no-package=s" => \&ExcludePackage,
	
		"dbg-package=s" => \&AddDebugPackage,
		
		"s" => \&AddPackage,
		"same-arch" => \&AddPackage,
	
		"n" => \$dh{NOSCRIPTS},
		"noscripts" => \$dh{NOSCRIPTS},
		"o" => \$dh{ONLYSCRIPTS},
		"onlyscripts" => \$dh{ONLYSCRIPTS},

		"X=s" => \&AddExclude,
		"exclude=s" => \&AddExclude,
		
		"d" => \$dh{D_FLAG},
	
		"k" => \$dh{K_FLAG},
		"keep" => \$dh{K_FLAG},

		"P=s" => \$dh{TMPDIR},
		"tmpdir=s" => \$dh{TMPDIR},

		"u=s", => \$dh{U_PARAMS},

		"V:s", => \$dh{V_FLAG},

		"A" => \$dh{PARAMS_ALL},
		"all" => \$dh{PARAMS_ALL},
	
		"sourcedir=s" => \$dh{SOURCEDIR},
		
		"destdir=s" => \$dh{DESTDIR},
		
		"priority=s" => \$dh{PRIORITY},
		
		"h|help" => \&showhelp,

		"mainpackage=s" => \$dh{MAINPACKAGE},

		"name=s" => \$dh{NAME},

		"error-handler=s" => \$dh{ERROR_HANDLER},
		
		"ignore=s" => \&AddIgnore,

		%options,

		"<>" => \&NonOption,
	);

	if (!$ret) {
		warning("warning: unknown options will be a fatal error in a future debhelper release");
		#error("unknown option; aborting");
	}
	
	# Check to see if -V was specified. If so, but no parameters were
	# passed, the variable will be defined but empty.
	if (defined($dh{V_FLAG})) {
		$dh{V_FLAG_SET}=1;
	}
	
	# If we have not been given any packages to act on, assume they
	# want us to act on them all. Note we have to do this before excluding
	# packages out, below.
	if (! defined $dh{DOPACKAGES} || ! @{$dh{DOPACKAGES}}) {
		if ($dh{DOINDEP} || $dh{DOARCH} || $dh{DOSAME}) {
			# User specified that all arch (in)dep package be
			# built, and there are none of that type.
			warning("I have no package to build");
			exit(0);
		}
		push @{$dh{DOPACKAGES}},getpackages();
	}

	# Remove excluded packages from the list of packages to act on.
	# Also unique the list, in case some options were specified that
	# added a package to it twice.
	my @package_list;
	my $package;
	my %packages_seen;
	foreach $package (@{$dh{DOPACKAGES}}) {
		if (! $exclude_package{$package}) {
			if (! exists $packages_seen{$package}) {
				$packages_seen{$package}=1;
				push @package_list, $package;	
			}
		}
	}
	@{$dh{DOPACKAGES}}=@package_list;

	# If there are no packages to act on now, it's an error.
	if (! defined $dh{DOPACKAGES} || ! @{$dh{DOPACKAGES}}) {
		error("I have no package to build");
	}

	if (defined $dh{U_PARAMS}) {
	        # Split the U_PARAMS up into an array.
        	my $u=$dh{U_PARAMS};
        	undef $dh{U_PARAMS};
                push @{$dh{U_PARAMS}}, split(/\s+/,$u);
        }

	# Anything left in @ARGV is options that appeared after a --
	# These options are added to the U_PARAMS array, while the
	# non-option values we collected replace them in @ARGV;
	push @{$dh{U_PARAMS}}, @ARGV;
	@ARGV=@{$dh{ARGV}} if exists $dh{ARGV};
}

sub import {
	# Enable bundling of short command line options.
	Getopt::Long::config("bundling");
}		

1