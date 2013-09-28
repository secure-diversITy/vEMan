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
      help => "Name of the virtual machine",
      required => 1,
   },
   targethost => {
      type => "=s",
      help => "Host name containing virtual machines to be migrated",
      required => 1,
   },
   sourcehost => {
      type => "=s",
      help => "Host name containing virtual machines to be migrated",
      required => 1,
   },
   targetdatastore => {
      type => "=s",
      help => "Name of the datastore",
      required => 1,
   },
   targetpool => {
      type => "=s",
      help => "Name of the pool",
      required => 1,
   },
   priority => {
      type => "=s",
      help => "The priority of the migration task: default, high, low",
      required => 0,
      default => 'defaultPriority',
   },
   state => {
      type => "=s",
      help => "State of the virtual machine: poweredOn, poweredOff, suspended",
      required => 0,
      default => 'poweredOff',
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate(\&validate);

my $vm_name = Opts::get_option ('vmname');
my $datacenter = Opts::get_option ('datacenter');
my $folder = Opts::get_option ('folder');
my $pool = Opts::get_option ('pool');
my $host = Opts::get_option ('sourcehost');
my $ipaddress = Opts::get_option('IPaddress');
my $powerstatus = Opts::get_option('powerstatus');
my $guest_os = Opts::get_option('guestOS');
my $operation = Opts::get_option('operation');

my %filter_hash = create_hash($ipaddress, $powerstatus, $guest_os);

Util::connect();
migrate_vm();
Util::disconnect();

sub migrate_vm {
   my $source_host_view = Vim::find_entity_view(view_type => 'HostSystem',
                               filter => {name => Opts::get_option('sourcehost')});
   my $target_host_view = Vim::find_entity_view(view_type => 'HostSystem',
                               filter => {name => Opts::get_option('targethost')});
                                                
   # If target host and source host both contains
   # the datastore, virtual machine needs to be migrated
   # If only target host contains the datastore, machine needs to be relocated
   my $result;
   if(defined $source_host_view && defined $target_host_view) {
      $result = HostUtils::get_migrate_option(source_host_view => $source_host_view,
                                target_host_view => $target_host_view,
                                datastore_name => Opts::get_option('targetdatastore'));
   }
   else {
      Util::trace(0, "Target or Source host not found");
      return;
   }
                                    
   my $ds_name = Opts::get_option('targetdatastore');
   my %ds_info = HostUtils::get_datastore(host_view => $target_host_view,
                                          datastore => $ds_name,
                                          disksize => 1024);

   # bug 299955
   if ($ds_info{mor} eq 0) {
      if ($ds_info{name} eq 'datastore_error') {
         Util::trace(0, "\nDatastore $ds_name not available.\n");
         return;
      }
      if ($ds_info{name} eq 'disksize_error') {
         Util::trace(0, "\nThe free space available is less than the"
                        . " specified disksize or the host"
                        . " is not accessible.\n");
         return;
      }
   }

   # To check wheather the resource pool belongs to target host or not.
   my %pool_check = HostUtils::check_pool(poolname => Opts::get_option('targetpool'),
                                          targethost => Opts::get_option('targethost'));
   if($pool_check{foundhost} ==0) {
      return;
   }
   if($result eq "migrate") {
      my $vm_views = VMUtils::get_vms ('VirtualMachine', $vm_name, $datacenter, $folder,
                                        $pool, $host, %filter_hash);
      foreach (@$vm_views) {
         VMUtils::migrate_virtualmachine(vm => $_,
                                         pool => $pool_check{mor},
                                         targethostview => $target_host_view,
                                         priority => Opts::get_option('priority'),
                                         state => Opts::get_option('state'));
      }
   }
   elsif($result eq "relocate") {
      my $vm_views = VMUtils::get_vms ('VirtualMachine', $vm_name, $datacenter, $folder,
                                        $pool, $host, %filter_hash);
      foreach (@$vm_views) {
         VMUtils::relocate_virtualmachine(vm => $_,
                                          pool => $pool_check{mor},
                                          targethostview => $target_host_view,
                                          sourcehostview => $source_host_view,
                                          datastore => $ds_info{mor});
      }
   }
   elsif($result eq "notfound") {
      Util::trace(0,"Datastore not found on target");
   }
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

# This subroutine is used for validating the values for
# the 'priority', 'State' options
# ------------------------------------------------------
sub validate {
   my $valid = 1;
   my $priority = Opts::get_option('priority');
   my $state = Opts::get_option('state');
   if ($priority && !($priority eq 'defaultPriority')
                 && !($priority eq 'highPriority') && !($priority eq 'lowPriority')) {
      Util::trace(0, "\nMust specify 'defaultPriority', 'highPriority'"
                   . " or 'lowPriority' for'priority' option\n");
      $valid = 0;
   }
   if ($state && !($state eq 'poweredOn')
              && !($state eq 'poweredOff') && !($state eq 'suspended')) {
      Util::trace(0, "\nMust specify 'poweredOn', 'poweredOff' or"
                   . " 'suspended' for 'state' option\n");
      $valid = 0;
   }
   return $valid;
}

__END__

## bug 217605

=head1 NAME

vmmigrate.pl - Migrates one or more virtual machines within the current host or
               from the current host to another host.

=head1 SYNOPSIS

 vmmigrate.pl [options]

=head1 DESCRIPTION

This VI Perl command-line utility provides an interface to migrate one
or more virtual machines within the current host or from the current
host to another host.

=head1 OPTIONS

=over

=item B<vmname>

Required. Name of the virtual machine.

=item B<sourcehost>

Required. Host name containing virtual machines to be evacuated.

=item B<targethost>

Required. Host name for transfer of the virtual machine.

=item B<targetdatastore>

Required. Datastore of target host to transfer virtual machine to.

=item B<targetpool>

Required. Resource pool to associate with the virtual machine.

=item B<priority>

Optional. The priority of the migration task: default, high, low.
Default is 'defaultPriority'.

=item B<state>

Optional. State of the virtual machine: poweredOn, poweredOff, or suspended.
If specified, the virtual machine migrates only if its state matches the
specified state.

=back

=head1 EXAMPLES

Migrate a virtual machine named VM1 from host 'ABC' to host 'XYZ'

 vmmigrate.pl --url https://<host>:<port>/sdk/vimService
                --username myuser --password mypassword
                --sourcehost ABC --targethost XYZ --targetdatastore storage1
                --targetpool Pool9 --vmname VM1

Migrate a virtual machine named VM1 within the current host to pool
'Pool123' and let the migration priority be 'low'.

 vmmigrate.pl --url https://<host>:<port>/sdk/vimService
              --username myuser --password mypassword
              --sourcehost ABC --targethost XYZ --targetdatastore storage1
              --targetpool Pool9 --piority lowPriority --vmname VM1

=head1 SUPPORTED PLATFORMS

All operations work with VMware VirtualCenter 2.0.1

No operation works when VMware ESX 3.0.1 is accessed directly.

