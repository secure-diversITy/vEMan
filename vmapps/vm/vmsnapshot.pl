#!/usr/bin/perl -w
#
# Copyright (c) 2007 VMware, Inc.  All rights reserved.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../";

use Getopt::Long;
use VMware::VIRuntime;
use AppUtil::VMUtil;

$Util::script_version = "1.0";

sub get_virtual_machines;
sub create_hash;
sub create_snapshots;

my %opts = (
   sname  => {
      type     => "=s",
      variable => "sname",
      help     => "Snapshot name",
      required => 1,
   },
   datacenter  => {
      type     => "=s",
      variable => "datacenter",
      help     => "Name of the datacenter",
   },
   pool  => {
      type     => "=s",
      variable => "pool",
      help     => "Name of the resource pool",
   },
   host => {
      type     => "=s",
      variable => "host",
      help     => "Name of the host",
   },
   folder => {
      type     => "=s",
      variable => "folder",
      help     => "Name of the folder",
   },
   vmname => {
      type     => "=s",
      variable => "vmname",
      help     => "Name of the Virtual Machine",
   },
   ipaddress   => {
      type     => "=s",
      variable => "ipaddress",
      help     => "IP address of the virtual machine",
   },
   powerstatus => {
      type     => "=s",
      variable => "  powerstatus",
      help     => "State of the virtual machine: poweredOn or poweredOff",
   },
   guest_os    => {
      type     => "=s",
      variable => "guest_os",
      help     => "Guest OS running on virtual machine",
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate(\&validate);

my %filter_hash = create_hash(Opts::get_option('ipaddress'),
                              Opts::get_option('powerstatus'),
                              Opts::get_option('guest_os'));
Util::connect();

my $vm_views = VMUtils::get_vms ('VirtualMachine',
                                      Opts::get_option ('vmname'),
                                      Opts::get_option ('datacenter'),
                                      Opts::get_option ('folder'),
                                      Opts::get_option ('pool'),
                                      Opts::get_option ('host'),
                                      %filter_hash);

create_snapshots($vm_views);

Util::disconnect();

# Snapshots of all the vm's extracted from get_vms methode are created
# by calling the CreateSnapshot method and passing name of the snapshot and description
# as parameters.
# =====================================================================================
sub create_snapshots {
   my $vm_views = shift;
   my $sname = Opts::get_option ('sname');
   foreach (@$vm_views) {
   
      my $mor_host = $_->runtime->host;
      my $hostname = Vim::get_view(mo_ref => $mor_host)->name;
      
      eval {
         $_->CreateSnapshot(name => $sname,
                            description => 'Snapshot created for virtual machine: '
                                           . $_->name ,
                            memory => 0,
                            quiesce => 0);
         Util::trace(0, "\nSnapshot '" . $sname
                      . "' completed for VM " . $_->name
                      . " under host $hostname");
      };
      if ($@) {
         Util::trace(0, "\nError creating snapshot of virtual Machine: " . $_->name);
         if (ref($@) eq 'SoapFault') {
            if (ref($@->detail) eq 'InvalidName') {
                Util::trace(0,"\nSpecified snapshot name is invalid\n");
            }
            elsif (ref($@->detail) eq 'InvalidState') {
                Util::trace(0,"\nThe operation is not allowed in the current state.\n");
            }
            elsif (ref($@->detail) eq 'InvalidPowerState') {
                Util::trace(0,"\nCurrent power state of the virtual machine '"
                             . $_->name . "' is invalid\n");
            }
            elsif (ref($@->detail) eq 'HostNotConnected') {
                Util::trace(0,"\nUnable to communicate with the remote host, "
                            . "since it is disconnected\n");
            }
            elsif (ref($@->detail) eq 'NotSupported') {
                Util::trace(0,"\nHost does not support snapshots \n");
            }
            else {
             Util::trace(0,"\nError occurred : \n" . $@ . "\n");
            }
         }
         else {
             Util::trace(0,"\nError occurred : \n" . $@ . "\n");
         }
      }
   }
   Util::trace(0, "\n");
}

sub create_hash {   
   my ($ipaddress, $powerstatus, $guest_os) = @_;
   my %filter_hash;
   if ($ipaddress) {
      $filter_hash{'guest.ipAddress'} = $ipaddress;
   }
   if ($powerstatus) {
      $filter_hash{'runtime.powerState'} = $powerstatus;
   }
## Bug 299213 fix start
   if ($guest_os) {
      $filter_hash{'config.guestFullName'} = qr/\Q$guest_os/i;
   }
   return %filter_hash;
## Bug 299213 fix end
}

sub validate {
   my $valid = 1;
   my $powerstatus = Opts::get_option('powerstatus');
   if ($powerstatus && !($powerstatus eq 'poweredOn') && !($powerstatus eq 'poweredOff')) {
      Util::trace(0, "\nMust specify poweredOn"
              ."or poweredOff for 'powerstatus' parameter\n");
      $valid = 0;
   }
   return $valid;
}

__END__

## bug 217605

=head1 NAME

vmsnapshot.pl - Creates snapshots of virtual machines.

=head1 SYNOPSIS

 vmsnapshot.pl [options]

=head1 DESCRIPTION

This VI Perl command-line utility creates snapshots of virtual machines
(memory dump is not included) based on the filter criteria. A snapshot 
captures the entire state of a virtual machine at the time the user take 
the snapshot.

=head1 OPTIONS

=over

=item B<sname>

Required. The name of the snapshot to be created.

=back

=head2 VIRTUAL MACHINE OPTIONS

=over

=item B<vmname>

Optional. Name of the virtual machine whose snapshot is to be created. If
this option is not specified, then the CreateSnapshot operation will be performed
on a set of virtual machines based on the other parameters.

=item B<powerstatus>

Optional. Power state of the virtual machine. poweredOn or poweredOff.

=item B<ipaddress>

Optional. IP address of the virtual machine.

=item B<guest_os>

Optional. Guest operating system running on the virtual machine.

=back

=head2 INVENTORY OPTIONS

=over

=item B<host>

Optional. Name of the host.

=item B<datacenter>

Optional. Name of the datacenter.

=item B<folder>

Optional. Folder name.

=item B<pool>

Optional. Name of the resource pool.

=back

=head1 EXAMPLES

Create snapshots for all the virtual machines which are in resource pool 'PoolA'
and whose power status is 'ON'. Let the name of the snapshot be 'Snap14May':

 vmsnapshot.pl --url https://<ipaddress>:<port>/sdk/webService
      --username administrator --password mypassword
      --sname Snap14May --pool PoolA --powerstatus poweredOn

Create snapshots for all the virtual machines which are in datacenter 'CenterABC',
resource pool 'PoolA' and whose power status is 'ON'. Let the name of the
snapshot be 'Snap14May':

 vmsnapshot.pl --url https://<ipaddress>:<port>/sdk/webService
      --username administrator --password mypassword
      --sname Snap14May  --datacenter CenterABC --pool PoolA
      --powerstatus poweredOn

Create snapshots for all the virtual machines which are in folder 'Team2'
and whose guest OS is linux. Let the name of the snapshot be 'Snap14May':

 vmsnapshot.pl --url https://<ipaddress>:<port>/sdk/webService
      --username administrator --password mypassword
      --sname Snap14May --folder Team2 --geustOS linux

Create snapshots for all the virtual machines whoose name is 'VM2'.
Let the name of the snapshot be 'Snap14May':

 vmsnapshot.pl --url https://<ipaddress>:<port>/sdk/webService
      --username administrator --password mypassword
      --sname Snap14May --vmname VM2

=head1 KNOWN ISSUE

If you suspend a virtual machine and then take two successive snapshots,
the second snapshot operation fails with the error "Failure due to a malformed
request to the server". This error is expected and does not indicate a problem,
because suspended virtual machines do not change, the second snapshot would
overwrite the existing snapshot with identical data.

=head1 SUPPORTED PLATFORMS

All operations work with VMware VirtualCenter 2.0.1

All operations work with VMware ESX 3.0.1.

