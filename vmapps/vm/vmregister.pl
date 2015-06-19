#!/usr/bin/perl -w
#
# Copyright (c) 2007 VMware, Inc.  All rights reserved.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../";

use VMware::VIRuntime;

$Util::script_version = "1.0";

sub register;
sub unregister;
sub validate;

# Bug 222613
my %operations = (
   "register", "",
   "unregister", "" ,
);

my %opts = (
   'operation' => {
      type => "=s",
      help => "Operation to be performed: register, unregister",
      required => 1,
   },
   'vmname' => {
      type => "=s",
      help => "Name of the virtual machine",
      required => 1,
   },
   'vmxpath' => {
      type => "=s",
      help => "Path of the vmx location of the virtual machine",
      required => 0,
   },
   'datacenter' => {
      type => "=s",
      help => "Name of the datacenter",
      required => 0,
   },
   'pool' => {
      type => "=s",
      help => "Name of the resource pool",
      required => 0,
   },
   'hostname' => {
      type => "=s",
      help => "Name of the host",
      required => 0,
   },
   'cluster' => {
      type => "=s",
      help => "Name of the cluster",
      required => 0,
   },
);


Opts::add_options(%opts);
Opts::parse();
Opts::validate(\&validate);

my $op = Opts::get_option('operation');
Util::connect();

if ($op eq "register") {
   register();
} elsif ($op eq "unregister") {
   unregister();
}

Util::disconnect();

# Handles the register request for registering the VM
sub register() {

   my $hostname = Opts::get_option('hostname');
   my $resourcepool = Opts::get_option('pool');
   my $vmxpath = Opts::get_option('vmxpath');
   my $vmname = Opts::get_option('vmname');
   my $datacenter = Opts::get_option('datacenter');
   my $cluster = Opts::get_option('cluster');
   my $cluster_view;
   my $pool_views;

   my $host_view = Vim::find_entity_view(view_type => 'HostSystem',
                                      filter => { 'name' => $hostname});
   if(!$host_view) {
      Util::trace(0,"\nNo host found with name $hostname.\n");
      return;
   }

   my $begin = Vim::find_entity_view (view_type => 'Datacenter',
                                         filter => {name => $datacenter});
   if (!$begin) {
      Util::trace(0, "\nNo data center found with name: $datacenter\n");
      return;
   }

   my $folder_view = Vim::get_view(mo_ref => $begin->vmFolder);

   if(defined $cluster)
   {
      $cluster_view =  Vim::find_entity_view(view_type =>'ClusterComputeResource',
                                             begin_entity => $begin,
                                             filter => { 'name' => $cluster} );
   
      if (!$cluster_view) {
         Util::trace(0, "\nNo cluster found with name: $cluster\n");
         return;
      }
       $pool_views = Vim::find_entity_views(view_type => 'ResourcePool',
                                             begin_entity => $cluster_view,
                                             filter => { 'name' => $resourcepool} );
   }
   else
   {
      $pool_views = Vim::find_entity_views(view_type => 'ResourcePool',
                                          begin_entity => $host_view->parent,
                                          filter => { 'name' => $resourcepool} );
   }
   unless (@$pool_views) {
      Util::trace(0, "Resource pool <$resourcepool> not found.\n");
      return;
   }
   if ($#{$pool_views} != 0) {
      Util::trace(0, "Resource pool <$resourcepool> not unique.\n");
      return;
   }
   my $pool = shift (@$pool_views);
   eval {
      $folder_view->RegisterVM(path => $vmxpath,
                               name => $vmname,
                               asTemplate => 'false',
                               pool => $pool,
                               host => $host_view);
      Util::trace(0,"\nRegister of VM '$vmname' successfully completed"
                   . " under host " . $host_view->name . "\n");
   };
   if ($@) {
      if (ref($@) eq 'SoapFault') {
         if (ref($@->detail) eq 'AlreadyExists') {
            Util::trace(0,"\nThe specified key, name, or identifier already exists\n");
         }
         elsif (ref($@->detail) eq 'OutOfBounds') {
            Util::trace(0,"\nMaximum Number of Virtual Machines has been exceeded\n");
         }
         elsif (ref($@->detail) eq 'InvalidArgument') {
            Util::trace(0,"\nA specified parameter was not correct.\n");
         }
         elsif (ref($@->detail) eq 'DatacenterMismatch') {
            Util::trace(0,"\nDatacenter Mismatch: The input arguments had entities "
                         . "that did not belong to the same datacenter.\n");
         }
         elsif (ref($@->detail) eq "InvalidDatastore") {
            Util::trace(0,"\nInvalid datastore path: $vmxpath\n");
         }
         elsif (ref($@->detail) eq 'NotSupported') {
            Util::trace(0,"\nOperation is not supported\n");
         }
         elsif (ref($@->detail) eq 'InvalidState') {
            Util::trace(0,"\nThe operation is not allowed in the current state\n");
         }
         else {
            Util::trace(0, $@ . "\n");
         }
      }
      else {
         Util::trace(0, $@ . "\n");
      }
   }
}

# This is required to unregister the VM
sub unregister() {
   my $vmname = Opts::get_option('vmname');
   my $vm_views = Vim::find_entity_views(view_type => 'VirtualMachine',
                                         filter => {'config.name' => $vmname});
   if (!@$vm_views) {
      Util::trace(0, "\nThere is no virtual machine with name '$vmname' registered\n");
      return;
   }
   foreach (@$vm_views){
      my $mor_host = $_->runtime->host;
      my $hostname = Vim::get_view(mo_ref => $mor_host)->name;
      eval {
         $_->UnregisterVM();
         Util::trace(0,"\nUnregister of VM '$vmname' successfully"
                      . " completed under host $hostname\n");
      };
      if ($@) {
         if (ref($@) eq 'SoapFault') {
            if (ref($@->detail) eq 'InvalidPowerState') {
               Util::trace(0,"\nVM '$vmname' under host $hostname must be powered off"
                            ." for this operation\n");
            }
            elsif (ref($@->detail) eq 'HostNotConnected') {
               Util::trace(0,"\nUnable to communicate with the remote host,"
                            . " since it is disconnected\n");
            }
            else {
               Util::trace(0,"\nFault: " . $@ . "\n");
            }
         }
         else {
            Util::trace(0,"\nFault: " . $@ . "\n");
         }
      }
   }
}

sub validate {
   my $valid = 1;
   # bug 222613
   my $operation = Opts::get_option('operation');
   if ($operation) {
         if (!exists($operations{$operation})) {
         Util::trace(0, "Invalid operation: '$operation'\n");
         Util::trace(0, " List of valid operations:\n");
         map {print "  $_\n"; } sort keys %operations;
         $valid = 0;
      }
      if (($operation eq 'register')) {
         if (!Opts::option_is_set('pool')) {
            Util::trace(0, "\nMust specify parameter pool"
                         . " for register operation\n");
            $valid = 0;
         }
         if (!Opts::option_is_set('vmxpath')) {
            Util::trace(0, "\nMust specify parameter vmxpath"
                         . " for register operation\n");
            $valid = 0;
         }
         if (!Opts::option_is_set('hostname')) {
            Util::trace(0, "\nMust specify parameter hostname"
                         . " for register operation\n");
            $valid = 0;
         }
         if (!Opts::option_is_set('datacenter')) {
            Util::trace(0, "\nMust specify parameter datacenter"
                         . " for register operation\n");
            $valid = 0;
         }
      }
   }
   return $valid;
}

__END__

=head1 NAME

vmregister.pl - Registers or unregisters a virtual machine.

=head1 SYNOPSIS

 vmregister.pl  --operation <register/unregister> [options]

=head1 DESCRIPTION

This VI Perl command-line utility allows users to perform registration
operations on a virtual machine. You can register a virtual machine to
a host or unregister it from a host.

=head1 OPTIONS

=head2 GENERAL OPTIONS

=over

=item B<operation>

Required. Operation to be performed. Must be one of the following:

  <register> (register a virtual machine)
  <unregister> (unregister an already registered virtual machine)

=back

=head2 REGISTER OPTIONS

=over

=item B<vmname>

Required. Name of the virtual machine to register.

=item B<pool>

Required. Resource Pool to register virtual machine.

=item B<hostname>

Required. Host to register the virtual machine.

=item B<vmxpath>

Required. Path of the vmx location of the virtual machine. There should not be
any space between the datastore and the virtual machine name. For e.g if the
actual path of the virtual machine ABC is "[datastore] ABC/ABC.vmx". The vmxpath path
should be "[datastore]ABC/ABC.vmx".

=item B<datacenter>

Required. Name of the datacenter.

=back

=head2 UNREGISTER OPTIONS

=over

=item B<vmname>

Required. Name of the virtual machine to unregister.

=back

=head1 EXAMPLES

Registering a virtual machine

 vmregister.pl  --url https://<ipaddress>:<port>/sdk/webService --username administrator
                --password mypassword --operation register --vmname FC5
                --hostname <host_name> --vmxpath [lazy_100gb]FC/FC.vmx
                --pool PoolABC

Unregistering a virtual machine

 vmregister.pl --url https://<ipaddress>:<port>/sdk/webService
               --username administrator --password mypassword
               --operation unregister --vmname FC5
               --hostname <host_name>

=head1 SUPPORTED PLATFORMS

All operations work with VMware VirtualCenter 2.0 or later.

All operations work with VMware ESX Server 3.0 or later.

