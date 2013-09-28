#!/usr/bin/perl -w
#
# Copyright (c) 2007 VMware, Inc.  All rights reserved.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../";

use VMware::VIRuntime;

$Util::script_version = "1.0";

Opts::parse();
Opts::validate();
Util::connect();
display_servertime();
Util::disconnect();

sub display_servertime {
   Util::trace(0, "\nConnection Successful\n");
   
   my $si_moref = ManagedObjectReference->new(type => 'ServiceInstance',
                                              value => 'ServiceInstance');
   my $si_view = Vim::get_view(mo_ref => $si_moref);
   Util::trace(0, "Server Time : ". $si_view->CurrentTime()."\n");
}

__END__

=head1 NAME

connect.pl - Connects to and disconnects from either an ESX host or a VirtualCenter server.

=head1 SYNOPSIS

 connect.pl [options]

=head1 DESCRIPTION

This VI Perl command-line utility connects to an ESX host or a VirtualCenter server, retrieves the server
host time, and disconnects.

=head1 EXAMPLES

 connect.pl --url https://<host>:<port>/sdk/vimService
                --username myuser --password mypassword

=head1 SUPPORTED PLATFORMS

All operations work with VMware VirtualCenter 2.0.1 or later.

All operations work with VMware ESX 3.0.1 or later.

