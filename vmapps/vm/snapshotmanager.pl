#!/usr/bin/perl -w
#
# Copyright (c) 2007 VMware, Inc.  All rights reserved.
#

## bug 299795 start all guestOS changed to guestos and IPaddress changed to ipaddress 
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../";

use VMware::VIRuntime;
use AppUtil::VMUtil;

$Util::script_version = "1.0";

sub usage;
sub validate;

my %opts = (
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

   vmname => {
      type      => "=s",
      variable  => "vmname",
      help       => "Name of the Virtual Machine",
      required => 0
   },

   ipaddress => {
      type => "=s",
      variable => "ipaddress",
      help => "IP address of the virtual machine",
      required => 0
   },

   powerstatus => {
      type => "=s",
      variable => "powerstatus",
      help => "State of the virtual machine: poweredOff, poweredOn",
      required => 0
   },

   guestos => {
      type => "=s",
      variable => "guestos",
      help => "Guest OS running on virtual machine",
      required => 0
   },
      
   operation => {
      type => "=s",
      help => "Operation to be performed: list, revert"
            . ", goto, rename, remove, removeall, create",
      required => 1
   },

   target => {
      type => "=s",
      help => "Name of the Target Host",
      required => 0
   },
   
   newname => {
      type => "=s",
      help => "New Name of the snapshot",
      required => 0
   },
   
   children => {
      type => "=i",
      help => "Binary Values to determine whether or not the children snapshot"
              ." to be deleted",
      required => 0
   },
   
   snapshotname => {
      type => "=s",
      help => "Name of the snapshot",
      required => 0
   },
);

my %operations = (
   "list",""
   ,"revert",""
   ,"goto", ""
   ,"rename", ""
   ,"remove",""
   ,"removeall",""
   ,"create", ""
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate(\&validate);

my $vm_name = Opts::get_option ('vmname');
my $datacenter = Opts::get_option ('datacenter');
my $folder = Opts::get_option ('folder');
my $pool = Opts::get_option ('pool');
my $host = Opts::get_option ('host');
my $ipaddress = Opts::get_option('ipaddress');
my $powerstatus = Opts::get_option('powerstatus');
my $guest_os = Opts::get_option('guestos');
my $operation = Opts::get_option('operation');

my %filter_hash = create_hash($ipaddress, $powerstatus, $guest_os);

Util::connect();

if ($operation eq 'list') {
  list_snapshot();
} if ($operation eq 'create') {
  create_snapshot();
} if ($operation eq 'revert') {
  revert_snapshot();
} if ($operation eq 'goto') {
  goto_snapshot();
} if ($operation eq 'rename') {
  rename_snapshot();
} if ($operation eq 'removeall') {
  remove_all_snapshot();
} if ($operation eq 'remove') {
  remove_snapshot();
}

Util::disconnect();

#This Subroutine List All the Snapshot for Virtual Machine.
#=========================================================
sub list_snapshot {
   my $vm_views = VMUtils::get_vms ('VirtualMachine', $vm_name, $datacenter, $folder,
                            $pool, $host, %filter_hash);
   foreach (@$vm_views) {
      my $mor_host = $_->runtime->host;
      my $hostname = Vim::get_view(mo_ref => $mor_host)->name;
      
      my $count = 0;
      my $snapshots = $_->snapshot;

      if(defined $snapshots) {
         Util::trace(0,"\nSnapshots for Virtual Machine ".$_->name
                       . " under host $hostname\n");
         printf "\n%-47s%-16s %s %s\n", "Name", "Date","State", "Quiesced";
         print_tree ($_->snapshot->currentSnapshot, " "
                     , $_->snapshot->rootSnapshotList);
      }
      else {
         Util::trace(0,"\nNo Snapshot of Virtual Machine ".$_->name
                       ." exists under host $hostname\n");
      }
   }
}

# Create: Creates a snapshot for one or more VMs.
#===========================================================
sub create_snapshot {
   my $vm_views = VMUtils::get_vms ('VirtualMachine', $vm_name, $datacenter, $folder,
                            $pool, $host, %filter_hash);
   my $snapshot_name = Opts::get_option('snapshotname');
   foreach (@$vm_views) {
   
      my $mor_host = $_->runtime->host;
      my $hostname = Vim::get_view(mo_ref => $mor_host)->name;
      eval {
         $_->CreateSnapshot(name => $snapshot_name,
                description => 'Snapshot created for Virtual Machine '.$_->name,
                memory => 0,
                quiesce => 0);

          Util::trace(0, "\nOperation :: Snapshot ".$snapshot_name
                         ." for virtual machine ". $_->name
                         ." created successfully under host ".$hostname
                         ."\n");
      };
      if ($@) {
        if (ref($@) eq 'SoapFault') {
           if(ref($@->detail) eq 'InvalidName') {
              Util::trace(0,"Snapshot name is invalid");
           }
           elsif(ref($@->detail) eq 'InvalidState') {
              Util::trace(0,"\nOperation cannot be performed in the current state
                             of the virtual machine");
           }
           elsif(ref($@->detail) eq 'NotSupported') {
              Util::trace(0,"\nHost product does not support snapshots.");
           }
           elsif(ref($@->detail) eq 'InvalidPowerState') {
              Util::trace(0,"\nOperation cannot be performed in the current power state
                            of the virtual machine.");
           }
           elsif(ref($@->detail) eq 'InsufficientResourcesFault') {
              Util::trace(0,"\nOperation would violate a resource usage policy.");
           }
           elsif(ref($@->detail) eq 'HostNotConnected') {
              Util::trace(0,"\nHost not connected.");
           }
           elsif(ref($@->detail) eq 'NotFound') {
              Util::trace(0,"\nVirtual machine does not have a current snapshot");
           }
           else {
              Util::trace(0, "\nFault: " . $@ . "\n\n");
           }
        }
        else {
           Util::trace(0, "\nFault: " . $@ . "\n\n");
        }
     }
   }
}


#Revert: Reverts to the current snapshot for a single VM.
#====================================================
sub revert_snapshot {
   my $vmname = Opts::get_option('vmname');
   my $vm_views = VMUtils::get_vms ('VirtualMachine', $vm_name, $datacenter, $folder,
                                       $pool, $host, %filter_hash);
                                       
   if ($#{$vm_views} != 0) {
      Util::trace(0, "Virtual machine <$vm_name> not unique.\n");
      return;
   }
      
   foreach (@$vm_views) {
   
     my $mor_host = $_->runtime->host;
     my $hostname = Vim::get_view(mo_ref => $mor_host)->name;
   
     eval {
        $_->RevertToCurrentSnapshot();
        Util::trace(0, "\nOperation :: Revert To Current Snapshot For Virtual "
                         . "Machine " . $_->name
                         ." completed successfully under host ".$hostname
                         . "\n");
     };
     if ($@) {
        if (ref($@) eq 'SoapFault') {
           if(ref($@->detail) eq 'InvalidState') {
              Util::trace(0,"\nOperation cannot be performed in the current state
                             of the virtual machine");
           }
           elsif(ref($@->detail) eq 'NotSupported') {
              Util::trace(0,"\nHost product does not support snapshots.");
           }
           elsif(ref($@->detail) eq 'InvalidPowerState') {
              Util::trace(0,"\nOperation cannot be performed in the current power state
                            of the virtual machine.");
           }
           elsif(ref($@->detail) eq 'InsufficientResourcesFault') {
              Util::trace(0,"\nOperation would violate a resource usage policy.");
           }
           elsif(ref($@->detail) eq 'HostNotConnected') {
              Util::trace(0,"\nHost not connected.");
           }
           elsif(ref($@->detail) eq 'NotFound') {
              Util::trace(0,"\nVirtual machine does not have a current snapshot");
           }
           else {
              Util::trace(0, "\nFault: " . $@ . "\n\n");
           }
        }
        else {
           Util::trace(0, "\nFault: " . $@ . "\n\n");
        }
     }
   }
}

# Goto: Reverts to the specified snapshot for a single VM.
# ========================================================
sub goto_snapshot {
   my $vmname = Opts::get_option('vmname');
   my $revert_snapshot = Opts::get_option('snapshotname');
    
   my $vm_views = VMUtils::get_vms ('VirtualMachine', $vm_name, $datacenter, $folder,
                                       $pool, $host, %filter_hash);
   if ($#{$vm_views} != 0) {
      Util::trace(0, "Virtual machine <$vm_name> not unique.\n");
      return;
   }
   foreach (@$vm_views) {
      my $mor_host = $_->runtime->host;
      my $hostname = Vim::get_view(mo_ref => $mor_host)->name;
      my $ref = undef;
      my $nRefs = 0;

      if(defined $_->snapshot) {
         ($ref, $nRefs) = find_snapshot_name ($_->snapshot->rootSnapshotList,
                                              $revert_snapshot);
      }
      if (defined $ref && $nRefs == 1) {
         my $snapshot = Vim::get_view (mo_ref =>$ref->snapshot);
         eval{
            $snapshot->RevertToSnapshot();
            Util::trace(0, "\nOperation :: Revert To Snapshot "
                           . $revert_snapshot
                           . " For Virtual Machine ". $_->name
                           . " completed successfully under host ".$hostname
                           . "\n");
         };
         if ($@) {
            if (ref($@) eq 'SoapFault') {
               if(ref($@->detail) eq 'InvalidState') {
                  Util::trace(0,"\nOperation cannot be performed in the current state
                                of the virtual machine");
               }
               elsif(ref($@->detail) eq 'NotSupported') {
                  Util::trace(0,"\nHost product does not support snapshots.");
               }
               elsif(ref($@->detail) eq 'InvalidPowerState') {
                  Util::trace(0,"\nOperation cannot be performed in the current power state
                                of the virtual machine.");
               }
               elsif(ref($@->detail) eq 'InsufficientResourcesFault') {
                  Util::trace(0,"\nOperation would violate a resource usage policy.");
               }
               elsif(ref($@->detail) eq 'HostNotConnected') {
                  Util::trace(0,"\nHost not connected.");
               }
               else {
                  Util::trace(0, "\nFault: " . $@ . "\n\n");
               }
            }
            else {
               Util::trace(0, "\nFault: " . $@ . "\n\n");
            }
         }
      }
      else {
         if ($nRefs > 1) {
            Util::trace(0,"\nMore than one snapshot exits with name"
                           ." $revert_snapshot in Virtual Machine ". $_->name
                           ." under host ". $hostname
                           ."\n");
         }
         if($nRefs == 0 ) {
            Util::trace(0,"\nSnapshot Not Found with name"
                           ." $revert_snapshot in Virtual Machine ". $_->name
                           ." under host ". $hostname
                           ."\n");
         }
      }
   }
}

# Rename: renames a named snapshot for a single VM.
# ================================================
sub rename_snapshot {
   my $vmname = Opts::get_option('vmname');
   my $name = Opts::get_option('newname');
   my $rename_snapshot = Opts::get_option('snapshotname');
    
   my $vm_views = VMUtils::get_vms ('VirtualMachine', $vm_name, $datacenter, $folder,
                                       $pool, $host, %filter_hash);
   if ($#{$vm_views} != 0) {
      Util::trace(0, "Virtual machine <$vm_name> not unique.\n");
      return;
   }
   foreach (@$vm_views) {
      my $mor_host = $_->runtime->host;
      my $hostname = Vim::get_view(mo_ref => $mor_host)->name;
      my $ref = undef;
      my $nRefs = 0;

      if(defined $_->snapshot) {
         ($ref, $nRefs) =
            find_snapshot_name ($_->snapshot->rootSnapshotList, $rename_snapshot);
      }
      if (defined $ref && $nRefs == 1) {
         my $snapshot = Vim::get_view (mo_ref =>$ref->snapshot);
         eval{
            $snapshot->RenameSnapshot (name => $name);
            Util::trace(0, "\nOperation:: Rename Snapshot ". $rename_snapshot . " for"
                         . " Virtual Machine ".$_->name
                         . " under host $hostname"
                         ." completed successfully\n");
         };
         if ($@) {
            if (ref($@) eq 'SoapFault') {
               if(ref($@->detail) eq 'InvalidName') {
                  Util::trace(0,"\nSpecified snapshot name is not valid");
               }
               elsif(ref($@->detail) eq 'NotSupported') {
                  Util::trace(0,"\nHost product does not support snapshot rename");
               }
               elsif(ref($@->detail) eq 'HostNotConnected') {
                  Util::trace(0,"\nHost not connected.");
               }
               else {
                  Util::trace(0, "\nFault: " . $@ . "\n");
               }
            }
            else {
               Util::trace(0, "\nFault: " . $@ . "\n\n");
            }
         }
      }
      else {
         if ($nRefs > 1) {
            Util::trace(0,"\nMore than one snapshot exits with name"
                           ." $rename_snapshot in Virtual Machine ". $_->name
                           ." under host ". $hostname
                           ."\n");
         }
         if($nRefs == 0 ) {
            Util::trace(0,"\nSnapshot Not Found with name"
                           ." $rename_snapshot in Virtual Machine ". $_->name
                           ." under host ". $hostname
                           ."\n");
         }
      }
   }
}

#Removeall: removes all snapshots for a single VM.
#==============================
sub remove_all_snapshot {
   my $vmname = Opts::get_option('vmname');
   my $vm_views = VMUtils::get_vms ('VirtualMachine', $vm_name, $datacenter, $folder,
                                       $pool, $host, %filter_hash);
   if ($#{$vm_views} != 0) {
      Util::trace(0, "Virtual machine <$vm_name> not unique.\n");
      return;
   }
   foreach (@$vm_views) {
      my $mor_host = $_->runtime->host;
      my $hostname = Vim::get_view(mo_ref => $mor_host)->name;
      
      my $snapshots = $_->snapshot;
      if(defined $snapshots) {
         eval {
            $_->RemoveAllSnapshots();
            Util::trace(0, "\n\nOperation :: Remove All Snapshot For Virtual Machine "
                         . $_->name
                         . " under host $hostname"
                         ." completed successfully\n");
         };
         if ($@) {
            if (ref($@) eq 'SoapFault') {
               if(ref($@->detail) eq 'InvalidState') {
                  Util::trace(0,"\nOperation cannot be performed in the current state
                                of the virtual machine");
               }
               elsif(ref($@->detail) eq 'NotSupported') {
                  Util::trace(0,"\nHost product does not support snapshots.");
               }
               elsif(ref($@->detail) eq 'InvalidPowerState') {
                  Util::trace(0,"\nOperation cannot be performed in the current
                                 power state of the virtual machine.");
               }
               elsif(ref($@->detail) eq 'HostNotConnected') {
                  Util::trace(0,"\nHost not connected.");
               }
               else {
                  Util::trace(0, "\nFault: " . $@ . "\n\n");
               }
            }
            else {
               Util::trace(0, "\nFault: " . $@ . "\n\n");
            }
         }
      }
      else {
         Util::trace(0,"\nNo Snapshot of Virtual Machine ".$_->name
                       ." under host $hostname"
                       ." exists\n");
      }
   }
}

# Remove: removes a named snapshot for one or more virtual machines.
# ==================================================================
sub remove_snapshot {
   my $children = Opts::get_option('children');
   my $remove_snapshot = Opts::get_option('snapshotname');
    
   my $vm_views =
      VMUtils::get_vms ('VirtualMachine', $vm_name, $datacenter, $folder,
               $pool, $host, %filter_hash);
   for (@$vm_views) {
      my $mor_host = $_->runtime->host;
      my $hostname = Vim::get_view(mo_ref => $mor_host)->name;
      my $ref = undef;
      my $nRefs = 0;
      
      if(defined $_->snapshot) {
         ($ref, $nRefs) =
            find_snapshot_name ($_->snapshot->rootSnapshotList, $remove_snapshot);
      }
      
      if (defined $ref && $nRefs == 1) {
         my $snapshot = Vim::get_view (mo_ref =>$ref->snapshot);
         eval {
            $snapshot->RemoveSnapshot (removeChildren => $children);
             Util::trace(0, "\nOperation :: Remove Snapshot ". $remove_snapshot .
                            " For Virtual Machine ". $_->name 
                            . " under host $hostname"
                            ." completed successfully\n");
         };
         if ($@) {
            if (ref($@) eq 'SoapFault') {
               if(ref($@->detail) eq 'InvalidState') {
                  Util::trace(0,"\nOperation cannot be performed in the current state
                                of the virtual machine");
               }
               elsif(ref($@->detail) eq 'HostNotConnected') {
                  Util::trace(0,"\nhost not connected.");
               }
               else {
                  Util::trace(0, "\nFault: " . $@ . "\n\n");
               }
            }
            else {
               Util::trace(0, "\nFault: " . $@ . "\n\n");
            }
         }
      }
      else {
         if ($nRefs > 1) {
            Util::trace(0,"\nMore than one snapshot exits with name"
                           ." $remove_snapshot in Virtual Machine ". $_->name
                           ." under host ". $hostname
                           ."\n");
         }
         if($nRefs == 0 ) {
            Util::trace(0,"\nSnapshot Not Found with name"
                           ." $remove_snapshot in Virtual Machine ". $_->name
                           ." under host ". $hostname
                           ."\n");
         }
      }
   }
}


# Print The Snapshot Tree For The Given Virtual Machine in tree format
# Because all snapshot for virtual machine are stored as per child 
# relationship structure.
# =====================================================
sub print_tree {
   my ($ref, $str, $tree) = @_;
   my $head = " ";
   foreach my $node (@$tree) {
      $head = ($ref->value eq $node->snapshot->value) ? " " : " " if (defined $ref);
      my $quiesced = ($node->quiesced) ? "Y" : "N";
      printf "%s%-48.48s%16.16s %s %s\n", $head, $str.$node->name,
             $node->createTime, $node->state->val, $quiesced;
      print_tree ($ref, $str . " ", $node->childSnapshotList);
   }
   return;
}


#  Find a snapshot with the name
#  This either returns: The reference to the snapshot
#  0 if not found & 1 if it's a duplicate
#  Duplicacy check is required for rename, remove and revert operations
#  For these operation specified snapshot name must be unique
# ==================================================
sub find_snapshot_name {
   my ($tree, $name) = @_;
   my $ref = undef;
   my $count = 0;
   foreach my $node (@$tree) {
      if ($node->name eq $name) {
         $ref = $node;
         $count++;
      }
      my ($subRef, $subCount) = find_snapshot_name($node->childSnapshotList, $name);
      $count = $count + $subCount;
      $ref = $subRef if ($subCount);
   }
   return ($ref, $count);
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
   # bug 299213
   if ($guest_os) {
      $filter_hash{'config.guestFullName'} = qr/\Q$guest_os/i;
   }
   return %filter_hash;
}



# This subroutine validates the arguemnt
# 1) snapshot argument is required for Create operation
# 2) vname argument is required for Revert operation
# 3) revert and vname arguement is required for Goto operation
# 4) rename and vname arguemnt is required for Rename operation
# 5) remove, children and vname arguemnt is required for Remove operation.
# ===============================
sub validate {
   my $valid = 1;
   my $operation = Opts::get_option('operation');
   if($operation) {
      if (!exists($operations{$operation})) {
         # bug 222613
         Util::trace(0, "Invalid operation: '$operation'\n");
         Util::trace(0, " List of valid operations:\n");
         map {print "  $_\n"; } sort keys %operations;
         $valid = 0;
      }
   }
   if ($operation && ($operation eq 'create')
      && (!Opts::option_is_set('snapshotname'))) {
      Util::trace(0, "\nMust specify snapshotname for operation create\n");
      $valid = 0;
   }
   if ($operation && ($operation eq 'revert') && (!Opts::option_is_set('vmname'))) {
      Util::trace(0, "\nMust specify vmname for operation revert\n");
     $valid = 0;
   }
   if ($operation && ($operation eq 'goto') && ((!Opts::option_is_set('vmname'))
      || (!Opts::option_is_set('snapshotname')))) {
      Util::trace(0, "\nMust specify vmname and snapshotname for operation goto\n");
      $valid = 0;
   }
   if ($operation && ($operation eq 'rename') && ((!Opts::option_is_set('vmname'))
      || (!Opts::option_is_set('snapshotname')) || (!Opts::option_is_set('newname')))) {
      Util::trace(0, "\nMust specify vmname, snapshotname, newname
                      for operation rename\n");
      $valid = 0;
   }
   if ($operation && ($operation eq 'rename') && ((Opts::option_is_set('vmname'))
      && (Opts::option_is_set('snapshotname')) && (Opts::option_is_set('newname')))) {
      if (Opts::get_option('snapshotname') eq Opts::get_option('newname')) {
         Util::trace(0, "\nThe value for option snapshotname is same as newname '"
                      . Opts::get_option('snapshotname'). "'\n");
         $valid = 0;
      }
   }
   if ($operation && ($operation eq 'removeall') && (!Opts::option_is_set('vmname'))) {
      Util::trace(0, "\nMust specify vmname for operation removeall\n");
      $valid = 0;
   }
   if ($operation && ($operation eq 'remove') && ((!Opts::option_is_set('snapshotname'))
      || (!Opts::option_is_set('children')))) {
      Util::trace(0, "\nMust specify snapshotname and children for operation remove\n");
      $valid = 0;
   }
   if (Opts::option_is_set('children')) {
      my $result = (Opts::get_option('children') =~ /^-?(?:\d+(?:\.\d*)?|\.\d+)$/);
      if($result){
         if ((Opts::get_option('children') !=0) && (Opts::get_option('children') !=1)) {
            Util::trace(0, "\nMust specify children parameter as either 0 or 1\n");
            $valid = 0;
         }
      }
      else {
         Util::trace(0, "\nMust specify children parameter as either 0 or 1\n");
         $valid = 0;
      }
   }
   if ($operation && ($operation eq 'remove') && ((Opts::option_is_set('children')))) {
      if(Opts::option_is_set('children') ne 1 && Opts::option_is_set('children') ne 0) {
         Util::trace(0, "\nChildren parameter must be either 1 or 0\n");
         $valid = 0;
      }
   }
   return $valid;
}

__END__

## bug 217605

=head1 NAME

snapshotmanager.pl - Allows you to list, revert, go to, rename, or remove one or more snapshots.

=head1 SYNOPSIS

 snapshotmanager.pl --operation <List|Create|Revert|Goto|Rename|Remove|RemoveAll> [options]

=head1 DESCRIPTION

This VI Perl command-line utility provides an interface for seven
basic operations for Snapshot:

=over

=item *

List all snapshots for one or more virtual machines.

=item *

Create a snapshot (memory dump is not included) for one or more virtual machines.

=item *

Revert to the current snapshot for a single virtual machine.

=item *

Revert to the specified snapshot for a single virtual machine.

=item *

Rename a named snapshot for a single virtual machine.

=item *

Remove all snapshots for a single virtual machine.

=item *

Remove a named snapshot for one or more virtual machines.

=back

=head1 OPTIONS

=over

=item B<operation>

Operation to be performed.  Must be one of the following:

I<list> E<ndash> List all snapshots for one or more virtual machines.

I<create> E<ndash> Create a snapshot for one or more virtual machines.

I<revert> E<ndash> Revert to the current snapshot for a single virtual machine.

I<goTo> E<ndash> Revert to the specified snapshot for a single virtual machine.

I<rename> E<ndash> Rename a named snapshot [and children] for a single virtual machine.

I<removeAll> E<ndash> Remove all snapshots for a single virtual machine.

I<remove> E<ndash> Remove a named snapshot for one or more virtual machines.

=back

=head2 LIST OPTIONS

=over

=item B<vmname>

Optional. The name of the source virtual machine.

=item B<datacenter>

Optional. Name of the datacenter for selection of virtual machines.

=item B<pool>

Optional. Name of the resource pool for selection of virtual machines.

=item B<host>

Optional. Name of the host for selection of virtual machines.

=item B<folder>

Optional. Name of the folder for selection of virtual machines.

=item B<ipaddress>

Optional. IP address of virtual machine.

=item B<powerstatus>

Optional. Power Status for selection of virtual machines.

=item B<guestos>

Optional. Guest OS for selection of virtual machines.

=back

=head2 CREATE OPTIONS

=over

=item B<vmname>

Optional. The name of the source virtual machine.

=item B<datacenter>

Optional. Name of the target datacenter for selection of virtual machines.

=item B<pool>

Optional. Name of the target resource pool for selection of virtual machines.

=item B<host>

Optional. Name of the target host for selection of virtual machines.

=item B<folder>

Optional. Name of the target folder for selection of virtual machines.

=item B<ipaddress>

Optional. IP address of target virtual machine.

=item B<powerstatus>

Optional. Power Status for selection of virtual machines.

=item B<guestos>

Optional. Guest OS for selection of virtual machines.

=item B<snapshotname>

Required. Name of the new snapshot for the Create operation.

=back

=head2 REVERT OPTIONS

=over

=item B<vmname>

Required. The name of the source virtual machine.

=back

=head2 GOTO OPTIONS

=over

=item B<vmname>

Required. The name of the source virtual machine.

=item B<snapshotname>

Required. Name of snapshot to revert to.

=back

=head2 RENAME OPTIONS

=over

=item B<vmname>

Required. The name of the source virtual machine.

=item B<snapshotname>

Required. Name of snapshot to be renamed.

=item B<newname>

Required. New name for the snapshot.

=back

=head2 REMOVEALL OPTIONS

=over

=item B<vmname>

Required. The name of the source virtual machine.

=back

=head2 REMOVE OPTIONS

=over

=item B<vmname>

Optional. The name of the source virtual machine.

=item B<datacenter>

Optional. Name of the target datacenter for selection of virtual machines.

=item B<pool>

Optional. Name of the target resource pool for selection of virtual machines.

=item B<host>

Optional. Name of the target host for selection of virtual machines.

=item B<folder>

Optional. Name of the target folder for selection of virtual machines.

=item B<ipaddress>

Optional. IP address of target virtual machine.

=item B<powerstatus>

Optional. Power Status for selection of virtual machines.

=item B<guestos>

Optional. Guest OS for selection of virtual machines.

=item B<snapshotname>

Required. Name of snapshot to be removed for operation I<Remove>

=item B<children>

Required. Binary value (0 or 1) that determines whether child snapshots 
are also removed (1) or not removed (0) for operation I <Remove>

=back

=head1 EXAMPLES

List all the snapshots for Virtual Machine with name "ABC":

 snapshotmanager.pl --url <https://<IP Address>:<Port>/sdk/vimService>
                    --username myuser --password mypassword --operation list
                    --vmname ABC

Create snapshot SN1 for the Virtual Machine "ABC":

 snapshotmanager.pl --url <https://<IP Address>:<Port>/sdk/vimService>
                    --username myuser --password mypassword --operation create
                    --vmname ABC --snapshotname SN1

Revert Virtual Machine "ABC" to Current Snapshot:

 snapshotmanager.pl --url <https://<IP Address>:<Port>/sdk/vimService>
                    --username myuser --password mypassword --operation revert
                    --vmname ABC

Revert Virtual Machine "ABC" to the snapshot "SN1" :

 snapshotmanager.pl --url <https://<IP Address>:<Port>/sdk/vimService>
                    --username myuser --password mypassword --operation goto
                    --vmname ABC --snapshotname SN1

Rename snapshot "SN1" of Virtual Machine "ABC" to "SN2":

 snapshotmanager.pl --url <https://<IP Address>:<Port>/sdk/vimService>
                    --username myuser --password mypassword --operation rename
                    --snapshotname SN1
                    --newname SN2 --vmname ABC

Remove all the snapshot for the Virtual Machine "ABC":

 snapshotmanager.pl --url <https://<IP Address>:<Port>/sdk/vimService>
                    --username myuser --password mypassword --operation removeAll
                    --vmname ABC

Remove the snapshot "SN1" of Virtual Machine "ABC" along with all the childrens:

 snapshotmanager.pl --url <https://<IP Address>:<Port>/sdk/vimService>
                    --username myuser --password mypassword --operation remove
                    --vmname ABC --snapshotname SN1
                    --children 1

=head1 KNOWN ISSUE

If you suspend a virtual machine and then take two successive snapshots,
the second snapshot operation fails with the error "Failure due to a malformed
request to the server". This error is expected and does not indicate a problem,
because suspended virtual machines do not change, the second snapshot would
overwrite the existing snapshot with identical data.

=head1 SUPPORTED PLATFORMS

All operations work with VMware VirtualCenter 2.0.1.

All operations work with VMware ESX 3.0.1.

