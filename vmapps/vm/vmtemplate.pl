#!/usr/bin/perl -w
#
# Copyright (c) 2007 VMware, Inc.  All rights reserved.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../";

use VMware::VIRuntime;

$Util::script_version = "1.0";

sub convert_to_template;
sub convert_to_vm;
sub validate;
sub find_host;

# bug 222613
my %operations = (
   "T", "",
   "VM", "" ,
);

my %opts = (
   vmname => {
      type => "=s",
      help => "The name of the virtual machine",
      required => 1,
   },
   operation => {
      type => "=s",
      help => "Operation to be performed: T, VM ",
      required => 1,
   },
   pool => {
      type => "=s",
      help => "Resource pool to associate with the virtual machine",
      required => 0,
   },
   host => {
      type => "=s",
      help => "The target host on which the virtual machine is intended to run",
      required => 0,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate(\&validate);

Util::connect();

if (Opts::get_option('operation') eq 'T') {
   convert_to_template(Opts::get_option('vmname'));
} elsif (Opts::get_option('operation') eq 'VM') {
   convert_to_vm(Opts::get_option('vmname'));
}

Util::disconnect();


# This subroutine converts the virtual machine to a
# template for a particular virtual machine.
# The input parameter is the name of the virtual machine.
# ======================================================
sub convert_to_template {
   my $vmname = shift;
   my $vm_views = Vim::find_entity_views((view_type => 'VirtualMachine'),
                                         filter => { name => $vmname } );
   if (!@$vm_views) {
      Util::trace(0, "\nNo virtual machine found with name: $vmname\n");
      return;
   }
   if ($#{$vm_views} !=0) {
     Util::trace(0, "\n Multiple VM of name $vmname exists, specify unique name. \n");
         return;
   }

   my $vm_moref = shift @$vm_views;
   my $mor_host = $vm_moref->runtime->host;
   my $hostname = Vim::get_view(mo_ref => $mor_host)->name;
   eval {
      $vm_moref->MarkAsTemplate();
      Util::trace(0, "\nThe Virtual Machine '$vmname' "
                  . "under host $hostname is successfully "
                  . "marked as a template.\n");
   };
   if ($@) {
      if (ref($@) eq 'SoapFault') {
         if (ref($@->detail) eq 'InvalidPowerState') {
            Util::trace(0, "\nThe virtual machine should be".
                        "in 'Powered Off' state for this operation.".
                        "It is currently in "
                        . $vm_moref->runtime->powerState->val." state \n");
         }
         elsif (ref($@->detail) eq 'InvalidState') {
            Util::trace(0, "\nInvalid virtual machine state\n");
         }
         elsif (ref($@->detail) eq 'HostNotConnected') {
            Util::trace(0, "\nUnable to communicate with the remote host,"
                         . " since it is disconnected\n");
         }
         elsif (ref($@->detail) eq 'NotSupported') {
            Util::trace(0, "\nMaking a virtual machine"
                             ." as a template is not supported\n"
                             . "Verify the virtual machine state.\n");
         }
         else {
            Util::trace(0, "\nError occurred : \n" . $@ . "\n");
         }
      }
      else {
         Util::trace(0, "\nError occurred : \n" . $@ . "\n");
      }
   }
}

# Convert template to the virtual machine
# To convert template to virtual machine host and pool name are required,
# these two are retrieved and then passed in the MarkAsVirtualMachine spec
# -------------------------------------------------------------------------
sub convert_to_vm {
   my $vmname = shift;
   my $pool = Opts::get_option('pool');
   my $vm_views = Vim::find_entity_views((view_type => 'VirtualMachine'),
                                         filter => { name => $vmname} );
   if (!@$vm_views) {
      Util::trace(0, "\nNo virtual machine found with name: $vmname\n");
      return;
   }
   if ($#{$vm_views} !=0) {
     Util::trace(0, "\n Multiple VM of name $vmname exists, specify unique name \n");
         return;
   }

   my $host_moref = find_host();
   if (!$host_moref) {
      return;
   }

   my $pool_views = Vim::find_entity_views(view_type => 'ResourcePool',
                                          filter => { name => $pool});
   if (!@$pool_views) {
      Util::trace(0,"\nNo resource pool found with name: $pool\n");
      return;
   }
   if ($#{$pool_views} !=0) {
      Util::trace(0, "\nPool ". $pool." not unique \n");
      return;
   }
   my $rp_moref = shift (@$pool_views);
   my $vm_moref = shift (@$vm_views);

   eval {
      $vm_moref->MarkAsVirtualMachine(pool => $rp_moref, , host => $host_moref );
      Util::trace(0, "\nThe Virtual Machine '$vmname' is successfully associated with"
                    . " host '" . $host_moref->name . "'"
                    . " and resource pool '$pool'.\n");
   };
   if ($@) {
      if (ref($@) eq 'SoapFault') {
         if (ref($@->detail) eq 'FileFault') {
            Util::trace(0,"\nFailed to access the virtual machine files\n");
         }
         elsif (ref($@->detail) eq 'InvalidDatastore') {
            Util::trace(0,"\nOperation cannot be performed on the target datastores\n");
         }
         elsif (ref($@->detail) eq 'InaccessibleDatastore') {
            Util::trace(0,"\n Datastore of the virtual machine is not "
                        . "accessible due to mismatch.\n");
         }
         elsif (ref($@->detail) eq 'InvalidState') {
            Util::trace(0,"\nInvalid virtual machine state:"
                        . " Not marked as a template\n");
         }
         elsif (ref($@->detail) eq 'HostNotConnected') {
            Util::trace(0, "\nUnable to communicate with the remote host,"
                         . " since it is disconnected\n");
         }
         elsif (ref($@->detail) eq 'NotSupported') {
            Util::trace(0,"\nMarking a template as a virtual machine is not supported :"
                          . "Verify the virtual machine state.\n");
         }
         elsif (ref($@->detail) eq 'InvalidArgument') {
            Util::trace(0,"\n A specified parameter was not correct.\n");
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


# It gets the host view by filtering the hostname.
# This subroutine also returns the default host
# present if the user has not specified any host.
# ===============================================
sub find_host {
   my $host_moref;
   my $hostname = Opts::get_option('host');
   if (Opts::option_is_set('host')) {
      my $host = Opts::get_option('host');
      $host_moref = Vim::find_entity_view(view_type => 'HostSystem',
                                   filter => { name =>$host});
      if (!$host_moref) {
         Util::trace(0,"\nNo host found with name: $host\n");
      }
   } else {
      my $host_views = Vim::find_entity_views(view_type => 'HostSystem');
      my $length = @$host_views;
      if ($length > 1) {
         Util::trace(0,"\nMultiple hosts present. Please specify the host.\n");
      } else {
         $host_moref = shift @$host_views;
         Util::trace(0, "\nDefault host found: ". $host_moref->name . "\n");
      }
   } 
   return $host_moref;   
}


# This subroutine is used for validating the operation types 
# e.g. if operation convert template to virtual machine is specified
# then resource pool must be provided.
# -------------------------------------------------------------------
sub validate {
   my $valid = 1;
   my $operation = Opts::get_option('operation');
     # bug 222613
     if($operation) {
      if (!exists($operations{$operation})) {
         Util::trace(0, "Invalid operation: '$operation'\n");
         Util::trace(0, " List of valid operations:\n");
         map {print "  $_\n"; } sort keys %operations;
         $valid = 0;
      }
   if (($operation eq 'VM') && (!Opts::option_is_set('pool'))) {
      Util::trace(0, "\nMust specify the 'pool' parameter "
                   . "when 'operation' is VM\n");
      $valid = 0;
      }
   }
   return $valid;
}

__END__

=head1 NAME

vmtemplate.pl - Converts a  virtual machine to a template and
                template back to virtual machine.

=head1 SYNOPSIS

 vmtemplate.pl --operation <T|VM> [options]

=head1 DESCRIPTION

This VI Perl command-line utility provides an interface for 
converting an existing virtual machine to a template and vice versa.

=head1 OPTIONS

=over

=item B<operation>

Required. Operation to be performed.  Must be one of the following:

I<T> E<ndash> Convert virtual machine to template.

I<VM> E<ndash> Convert template to virtual machine.

=back

=head2 TEMPLATE OPTIONS

=over

=item B<vmname>

Required. The name of the virtual machine which is to be converted to a template.

=back

=head2 VIRTUAL MACHINE OPTIONS

=over

=item B<vmname>

Required. The name of the virtual machine which is to be re-associated
with a host and a resource pool.

=item B<pool>

Required. Resource pool to associate with the virtual machine.

=item B<host>

Optional. The target host on which the virtual machine is intended to run.

=back

=head1 EXAMPLES

Convert a virtual machine named 'VirtualABC' to a template :

 vmtemplate.pl --url https://<ipaddress>:<port>/sdk/webService
               --username administrator --password mypassword 
               --vmname VirtualABC --operation T

Convert a template to virtual machine named 'VirtualABC'. Let 'Poolxyz' 
be the resource pool to be associated with this virtual machine and 'BlueHost' 
be the host on which the virtual machine is intended to run:

 vmtemplate.pl --url https://<ipaddress>:<port>/sdk/webService
               --username administrator --password mypassword 
               --vmname VirtualABC --operation VM --pool Poolxyz
               --host BlueHost

Convert a template to virtual machine named 'VirtualABC'. Let 'Poolxyz' 
be the resource pool to be associated with this virtual machine and 
no host specified (default host will be selected in this case):

 vmtemplate.pl --url https://<ipaddress>:<port>/sdk/webService
               --username administrator --password mypassword 
               --vmname VirtualABC --operation VM --pool Poolxyz

=head1 SUPPORTED PLATFORMS

All operations work with VMware VirtualCenter 2.0.1

No operation works when VMware ESX 3.0.1 is accessed directly.

