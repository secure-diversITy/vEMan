#!/usr/bin/perl -w
#
# Copyright (c) 2007 VMware, Inc.  All rights reserved.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../";

use VMware::VIRuntime;
use AppUtil::HostUtil;
use AppUtil::VMUtil;

$Util::script_version = "1.0";

my %opts = (
   vmname => {
      type => "=s",
      help => "Name of the Virtual machine",
      required => 1
   },
   datacenter  => {
      type     => "=s",
      variable => "datacenter",
      help     => "Name of the datacenter",
      required => 0
   },
   pool  => {
      type     => "=s",
      variable => "pool",
      help     => "Name of the resource pool",
      required => 0
   },
   host => {
      type      => "=s",
      variable  => "host",
      help      => "Name of the host",
      required => 0
   },
   folder => {
      type      => "=s",
      variable  => "folder",
      help      => "Name of the folder",
      required => 0
   },
   filename => {
      type => "=s",
      help => "Name of the device",
      required => 1
   },
   disksize => {
      type => "=i",
      help => "Size in MB",
      required => 0,
      default  => 10
   },
   nopersist => {
      type => "",
      help => "Define whether device is non-persistent",
      required => 0
   },
   independent => {
      type => "",
      help => "Define whether device is independent",
      required => 0
   },
   backingtype => {
      type => "=s",
      help => "Type of backing required for virtual disk"
              ." either regular or rdm",
      default => 'regular',
      required => 0
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate(\&validate);

Util::connect();
create_virtualdisk();
Util::disconnect();

sub create_virtualdisk {
   my %filter_hash = create_hash(Opts::get_option('ipaddress'),
                                 Opts::get_option('powerstatus'),
                                 Opts::get_option('guestos'));

   my $vm_views = VMUtils::get_vms ('VirtualMachine',
                                    Opts::get_option ('vmname'),
                                    Opts::get_option ('datacenter'),
                                    Opts::get_option ('folder'),
                                    Opts::get_option ('pool'),
                                    Opts::get_option ('host'),
                                    %filter_hash);
   # bug 418090
   if ((defined $vm_views) && (@$vm_views > 1)) {
      my $vm = Opts::get_option ('vmname');
      Util::trace(0, "\nVirtual machine <$vm> not uniquely identified.\n");
      return;
   }

   foreach (@$vm_views) {
      my $hostname;
      if(defined $_->runtime->host) {
         my $host_view = Vim::get_view(mo_ref => $_->runtime->host);
         $hostname = $host_view->name;
      }
      # bug 418095
      my $controller = VMUtils::find_scsi_controller_device(vm => $_);
      my $controllerKey = $controller->key;
      my $unitNumber = $#{$controller->device} + 1;
      
      my $size = Opts::get_option ('disksize') * 1024;

      my $diskMode = VMUtils::get_diskmode(nopersist => Opts::get_option ('nopersist'),
                                  independent => Opts::get_option ('independent'));

      my $fileName = VMUtils::generate_filename(vm => $_,
                                       filename => Opts::get_option ('filename'));

      Util::trace(0,"\nAdding Virtual Disk on Virtual machine " . $_->name
                    . " in the host " . $hostname ."\n");

      my $devspec = VMUtils::get_vdisk_spec(vm => $_,
                             backingtype => Opts::get_option ('backingtype'),
                             diskMode => $diskMode,
                             fileName => $fileName,
                             controllerKey => $controllerKey,
                             unitNumber => $unitNumber,
                             size => $size);
                             
      VMUtils::add_virtualdisk(vm => $_,
                               devspec => $devspec);
   }
}

sub create_hash {
   my ($ipaddress, $powerstatus, $guestos) = @_;
   my %filter_hash;
   if ($ipaddress) {
      $filter_hash{'guest.ipAddress'} = $ipaddress;
   }
   if ($powerstatus) {
      $filter_hash{'runtime.powerState'} = $powerstatus;
   }
## Bug 299213 fix start
   if ($guestos) {
      $filter_hash{'config.guestFullName'} = qr/\Q$guestos/i;
   }
   return %filter_hash;
## Bug 299213 fix end
}

sub validate {
   my $valid = 1;
   my $backingtype = Opts::get_option('backingtype');
   if ($backingtype && !($backingtype eq 'regular')
                    && !($backingtype eq 'rdm') ) {
      Util::trace(0, "\nMust specify 'rdm' or 'regular'"
                   . " for'priority' option\n");
      $valid = 0;
   }
   return $valid;
}

__END__

## bug 217605

=head1 NAME

vdiskcreate.pl - Create a new virtual disk on a virtual machine.

=head1 SYNOPSIS

 vdiskcreate.pl [options]

=head1 DESCRIPTION

This VI Perl command-line utility provides an interface to create virtual
disk on a virtual machine. The virtual disk is composed of one or more files on
the host file system. Together, these files appear as a single hard disk
to the guest operating system.

=head1 OPTIONS

=over

=item B<vmname>

Required. The name of the virtual machine. It will be used to select the
virtual machine.

=item B<datacenter>

Optional. The name of the datacenter. It will be used to select the
virtual machine.

=item B<pool>

Optional. The name of the resource pool. It will be used to select the
virtual machine.

=item B<host>

Optional. The name of the host system. It will be used to select the
virtual machine.

=item B<folder>

Optional. The name of the folder. It will be used to select the
virtual machine.

=item B<filename>

Required. Name of the host file used as a backing for the virtual disk to be
created.

=item B<disksize>

Optional. Capacity of virtual disk in MB.

=item B<nopersist>

Optional. To specify whether the changes on the virtual disk retained after the
          virtual machine is powered off.

=item B<independent>

Optional. To specify whether disks gets affected by snapshots or not.

=item B<backingtype>

Optional. Information about a file backing for a device in a virtual machine.

=back

=head1 EXAMPLES

Create a new virtual disk on virtual machine myVM:

 vdiskcreate.pl --url https://<host>:<port>/sdk/vimService
                --username myuser --password mypassword --vmname myVM
                --filename filename

Create a new virtual disk on virtual machine myVM using
raw disk mapping option:

 vdiskcreate.pl --url https://<host>:<port>/sdk/vimService
                --username myuser --password mypassword --vmname myVM
                --filename filename -backingtype rdm

Create a new virtual disk on virtual machine myVM with
independent option:

 vdiskcreate.pl --url https://<host>:<port>/sdk/vimService
                --username myuser --password mypassword --vmname myVM
                --filename filename --independent

Create a new virtual disk on virtual machine myVM with
nopersistent option:

 vdiskcreate.pl --url https://<host>:<port>/sdk/vimService
                --username myuser --password mypassword --vmname myVM
                --filename filename --nopersistent

=head1 SUPPORTED PLATFORMS

All operations work with VMware VirtualCenter 2.0.1 or later.

All operations work with VMware ESX 3.0.1 or later.

