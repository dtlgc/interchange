# Vend::SessionFile - Stores Interchange session information in files
#
# $Id: SessionFile.pm,v 1.3.4.2 2003-01-25 22:21:28 racke Exp $
#
# Copyright (C) 1996-2002 Red Hat, Inc. <interchange@redhat.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA  02111-1307  USA.

package Vend::SessionFile;
require Tie::Hash;
@ISA = qw(Tie::Hash);

use Symbol;
use strict;
use Vend::Util;

use vars qw($VERSION);
$VERSION = substr(q$Revision: 1.3.4.2 $, 10);

my $SessionDir;
my $CommDir;
my $CommLock;
my $SessionFile;
my $SessionLock;
my %Unlinks;
my %HaveLock;
my $Lh;
my $Last;
my @Each;

sub TIEHASH {
	my($self, $dir, $nfs) = @_;
	die "Vend::SessionFile: directory name\n"
		unless $dir;
	$SessionDir = $dir;
	%HaveLock = ();
	if($nfs) {
		*lockfile = \*Vend::Util::fcntl_lock;
		*unlockfile = \*Vend::Util::fcntl_unlock;
	}
	bless {}, $self;
}

sub keyname {
	return Vend::Util::get_filename(shift, 2, 1, $SessionDir);
}

sub FETCH {
	my($self, $key) = @_;
	$SessionFile = keyname($key);
	$SessionLock = $SessionFile . ".lock";
	return undef unless -f $SessionFile;
	my $str;
#::logDebug("fetch session=$key HaveLock=$HaveLock{$SessionFile}");
	unless ($HaveLock{$SessionFile}) {
		$Lh = gensym();
		open($Lh, "+>>$SessionLock")
			or die "Can't open '$SessionLock': $!\n";
		lockfile($Lh, 1, 1)
			or die "lock $SessionLock: $!\n";
		$HaveLock{$SessionFile} = 1;
	}
	my $ref = Vend::Util::eval_file($SessionFile);
#::logDebug("retrieving from $SessionFile: " . ::uneval($ref));
	return $ref;
}

sub FIRSTKEY {
	my ($self) = @_;
	require File::Find
		or die "No standard Perl library File::Find!\n";
	@Each = ();
	File::Find::find( sub {
						return if ! -f $File::Find::name;
						return if $File::Find::name =~ /\.lock$/;
						push @Each, $File::Find::name;
					},
					$SessionDir,
	);
	&NEXTKEY;
}

sub NEXTKEY {
	my $key = shift @Each;
	my $last = $Last;
	$Last = $key;
	return $key;
}

sub EXISTS {
#::logDebug("check existance $_[1]");
	return Vend::Util::exists_filename($_[1], 2, 1, $SessionDir);
}

# IPC not handled yet
sub DELETE {
	my($self,$key) = @_;
	my $filename = keyname($key);
	unlink $filename;
	return 1 if $Global::Windows;
	my $lockname = $filename . ".lock";
	unlink $lockname;
}

sub STORE {
	my($self, $key, $ref) = @_;
#::logDebug("store $key");
	$SessionFile = keyname($key);
	$SessionLock = $SessionFile . ".lock";
	unlink $SessionFile;
#::logDebug("store session=$key HaveLock=$HaveLock{$SessionFile}");
	unless ($HaveLock{$SessionFile}) {
		$Lh = gensym();
		open($Lh, "+>>$SessionLock")
			or die "Can't open '$SessionLock': $!\n";
		lockfile($Lh, 1, 1)
			or die "lock $SessionLock: $!\n";
		$HaveLock{$SessionFile} = 1;
#::logDebug("locked $SessionFile");
	}
#::logDebug("storing in $SessionFile: " . ::uneval($ref));
	Vend::Util::uneval_file($ref,$SessionFile);
}
	
sub DESTROY {
	my($self) = @_;
#::logDebug("Destroy, have_lock=$HaveLock{$SessionFile}");
	if($HaveLock{$SessionFile}) {
		unlockfile($Lh)
			or die "cannot unlock file: $!";
#::logDebug("Destroy unlocked $SessionFile");
		delete $HaveLock{$SessionFile};
	}
	close($Lh);
	undef $self;
}

1;
__END__
