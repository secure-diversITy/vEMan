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
   targethost => {
      type => "=s",
      help => "Host name of the host to transfer virtual machines to",
      required => 1,
   },
   sourcehost => {
      type => "=s",
      help => "Host name of the host containing virtual machines to be evacuated",
      required => 1,
   },
   targetdatastore => {
      type => "=s",
      help => "Name of the datastore",
      required => 1,
   },
   targetpool => {
      type => "=s",
      help => "Name of the resource pool",
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

Util::connect();
evacuate_host();
Util::disconnect();


# This subroutine evacuates a host by migrating
# all the virtual machines to another host.
# =============================================
sub evacuate_host {
   my $source_host_view = Vim::find_entity_view(view_type => 'HostSystem',
                               filter => {name => Opts::get_option('sourcehost')});
   my $target_host_view = Vim::find_entity_view(view_type => 'HostSystem',
                               filter => {name => Opts::get_option('targethost')});
   # If target host and source host both contains the datastore, machine nneds to be
   # migrated
   # If only target host contains the datastore, machine nneds to be relocated
   my $result;
   if(defined $source_host_view && defined $target_host_view) {
      if($source_host_view->name eq $target_host_view->name) {
         Util::trace(0,"Both Host System and Source System are same");
         return;
      }
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
   
   my $vm_views = Vim::find_entity_views(view_type => 'VirtualMachine',
                                         begin_entity => $source_host_view);
   if($result eq "migrate") {
      foreach (@$vm_views) {
         VMUtils::migrate_virtualmachine(vm => $_,
                                         pool => $pool_check{mor},
                                         targethostview => $target_host_view,
                                         priority => Opts::get_option('priority'),
                                         state => Opts::get_option('state'));
      }
   }
   elsif($result eq "relocate") {
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

hostevacuate.pl - Migrates all virtual machines from one host to another.

=head1 SYNOPSIS

 hostevacuate.pl [options]

=head1 DESCRIPTION

This VI Perl command-line utility provides an interface to evacuate a
host by migrating all virtual machines from one host to another
in preparation for maintenance actions on that host.

=head1 OPTIONS

=over

=item B<sourcehost>

Required. Name of the host that contains the virtual machines to be evacuated.

=item B<targethost>

Required. Name of the host to transfer virtual machines to.

=item B<targetdatastore>

Required. Datastore of target host to transfer virtual machines to.

=item B<targetpool>

Required. Resource pool to associate with the virtual machine.

=item B<priority>

Optional. The priority of the migration task: default, high, low.
Default is 'defaultPriority'.

=item B<state>

Optional. State of the virtual machine: poweredOn, poweredOff, suspended.
If specified, the virtual machine migrates only if its state matches the
specified state.

=back

=head1 EXAMPLES

Evacuate host 'ABC' by migrating all virtual machines from 'ABC' to
another host 'XYZ':

 hostevacuate.pl --url https://<host>:<port>/sdk/vimService
                --username myuser --password mypassword
                --sourcehost ABC --targethost XYZ --targetdatastore storage1
                --targetpool Pool9

Evacuate host 'Host1' by migrating all virtual machines from 'Host1' to
another host 'Host2'. Let the priority of the migration task be 'high':

 hostevacuate.pl --url https://<host>:<port>/sdk/vimService
                --username myuser --password mypassword
                --sourcehost ABC --targethost XYZ --targetdatastore storage1
                --targetpool Pool9 --piority highPriority

=head1 SUPPORTED PLATFORMS

All operations work with VMware VirtualCenter 2.0.1

No operation works when VMware ESX 3.0.1 is accessed directly.

