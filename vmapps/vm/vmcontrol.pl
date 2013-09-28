#!/usr/bin/perl -w
#
# Copyright (c) 2007 VMware, Inc.  All rights reserved.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../";

use VMware::VIRuntime;
use AppUtil::VMUtil;

$Util::script_version = "1.0";

sub create_hash;

my %opts = (
   'operation' => {
      type => "=s",
      help => "The power operations to be performed on the VMs: " .
              "poweron, poweroff, suspend, reset, reboot, shutdown, standby",
      required => 1,
   }, 
   'vmname' => {
      type => "=s",
      help => "The name of the virtual machine",
      required => 0, 
   },
   'guestos' => {
      type => "=s",
      help => "The guest OS running on virtual machine",
      required => 0, 
   },
   'ipaddress' => {
      type => "=s",
      help => "The IP address of virtual machine",
      required => 0,
   },
   'datacenter' => {
      type     => "=s",
      variable => "datacenter",
      help     => "Name of the datacenter",
      required => 0,
   },
   'pool'  => {
      type     => "=s",
      variable => "pool",
      help     => "Name of the resource pool",
      required => 0,
   },
   'host' => {
      type      => "=s",
      variable  => "host",
      help      => "Name of the host" ,
      required => 0,
   },
   'folder' => {
      type      => "=s",
      variable  => "folder",
      help      => "Name of the folder" ,
      required => 0,
   },
);


my %operations = (
   "poweron", "",
   "poweroff", "" ,
   "reset", "" ,
   "suspend", "",
   "reboot", "",
   "standby", "",
   "shutdown", "",
);


Opts::add_options(%opts);
Opts::parse();
Opts::validate(\&validate);

Util::connect();

my $vm_name = Opts::get_option ('vmname');
my $datacenter = Opts::get_option ('datacenter');
my $folder = Opts::get_option ('folder');
my $pool = Opts::get_option ('pool');
my $host = Opts::get_option ('host');
my $resource = Opts::get_option ('resource');
my $ipaddress = Opts::get_option('ipaddress');
my $guestos = Opts::get_option('guestos');


my %filterHash = create_hash($ipaddress , $guestos );
my $vm_views = VMUtils::get_vms ('VirtualMachine', $vm_name,
                      $datacenter, $folder, $pool, $host, %filterHash);
                      
if($vm_views) {
   my $op = Opts::get_option('operation');
       
   if( $op eq "poweron" ) {
      poweron_vm();
   }
   elsif( $op eq "reset" ) {
      reset_vm();
   }
   elsif( $op eq "standby" ) {
      standby_guest();
   }
   elsif( $op eq "poweroff" ) {
      poweroff_vm();
   }
   elsif( $op eq "reboot" ) {
      reboot_guest();
   }
   elsif( $op eq "shutdown" ) {
      shutdown_guest();
   }
   elsif( $op eq "suspend" ) {
      suspend_vm();
   }
}

Util::disconnect();

sub poweron_vm {
   foreach (@$vm_views) {
      my $mor_host = $_->runtime->host;
      my $hostname = Vim::get_view(mo_ref => $mor_host)->name;
      eval {
         $_->PowerOnVM();
         Util::trace(0, "\nvirtual machine '" . $_->name .
                         "' under host $hostname powered on \n");
      };
      if ($@) { 
         if (ref($@) eq 'SoapFault') {
            Util::trace (0, "\nError in '" . $_->name . "' under host $hostname: ");
            if (ref($@->detail) eq 'NotSupported') {
               Util::trace(0,"Virtual machine is marked as a template ");
            }
            elsif (ref($@->detail) eq 'InvalidPowerState') {
                Util::trace(0, "The attempted operation".
                          " cannot be performed in the current state" );
            }
            elsif (ref($@->detail) eq 'InvalidState') {
               Util::trace(0,"Current State of the "
                      ." virtual machine is not supported for this operation");
            }
            else {
               Util::trace(0, "VM '"  .$_->name.
                  "' can't be powered on \n" . $@ . "" );
            }
         }
         else {
            Util::trace(0, "VM '"  .$_->name.
                           "' can't be powered on \n" . $@ . "" );
         }
      }
   }
}

sub reset_vm {
   foreach (@$vm_views) {
      my $mor_host = $_->runtime->host;
      my $hostname = Vim::get_view(mo_ref => $mor_host)->name;
      eval {
        $_->ResetVM();
        Util::trace(0, "\nvirtual machine '" . $_->name . "' under host".
                                  " $hostname reset successfully ");
      };
      if ($@) {
         if (ref($@) eq 'SoapFault') {
            Util::trace (0, "\nError in '" . $_->name . "' under host $hostname: ");
            if (ref($@->detail) eq 'InvalidState') {
               Util::trace(0,"Host is in maintenance mode");
            }
            elsif (ref($@->detail) eq 'InvalidPowerState') {
                Util::trace(0, "The attempted operation".
                          " cannot be performed in the current state" );
            }
            elsif (ref($@->detail) eq 'NotSupported') {
               Util::trace(0,"Virtual machine is marked as a template ");
            }
            else {
               Util::trace(0, "VM '"  .$_->name. "' can't be reset \n" . $@ . "");
            }
         }
         else {
            Util::trace(0, "VM '"  .$_->name. "' can't be reset \n" . $@ . "");
         }
      }
   }
}

sub standby_guest {
   foreach (@$vm_views) {
      my $mor_host = $_->runtime->host;
      my $hostname = Vim::get_view(mo_ref => $mor_host)->name;
      eval {
         $_->StandbyGuest();
         Util::trace(0, "\nGuest  '". $_->name .
                    "' under host $hostname put into standby mode");
      };
      if ($@) {
         if (ref($@) eq 'SoapFault') {
            Util::trace (0, "\nError in '" . $_->name . "' under host $hostname: ");
            if (ref($@->detail) eq 'InvalidState') {
               Util::trace(0,"Current State of the"
                     ." virtual machine is not supported for this operation \n");
            }
            elsif (ref($@->detail) eq 'InvalidPowerState') {
                Util::trace(0, "The attempted operation".
                          " cannot be performed in the current state" );
            }
            elsif (ref($@->detail) eq 'NotSupported') {
                Util::trace(0, "The operation is not supported on the object");
            }
            elsif(ref($@->detail) eq 'ToolsUnavailable') {
               Util::trace(0,"VMTools are not running in this virtual machine \n");
            }
            else {
               Util::trace(0,"Guest '"  .$_->name.
               "' can't be set on standby mode \n" . $@ . "" );
            }
         }
         else {
            Util::trace(0,"Guest '"  .$_->name.
                          "' can't be set on standby mode \n" . $@ . "" );
         }
      }
   }
}

sub poweroff_vm {
   foreach (@$vm_views) {
      my $mor_host = $_->runtime->host;
      my $hostname = Vim::get_view(mo_ref => $mor_host)->name;
      eval {
      $_->PowerOffVM();
      Util::trace (0, "\nvirtual machine '" . $_->name .
                       "' under host $hostname powered off ");
      };
    
      if ($@) { 
          if (ref($@) eq 'SoapFault') {
             Util::trace (0, "\nError in '" . $_->name . "' under host $hostname: ");
             if (ref($@->detail) eq 'InvalidPowerState') {
                Util::trace(0, "The attempted operation".
                          " cannot be performed in the current state" );
            }
             elsif (ref($@->detail) eq 'InvalidState') {
                Util::trace(0,"Current State of the".
                      " virtual machine is not supported for this operation");
             }
             elsif(ref($@->detail) eq 'NotSupported') {
                Util::trace(0,"Virtual machine is marked as template");
             }
             else {
               Util::trace(0, "VM '"  .$_->name. "' can't be powered off \n"
                      . $@ . "" );
            }
         }
         else {
            Util::trace(0, "VM '"  .$_->name. "' can't be powered off \n" . $@ . "" );
         }
      }
   }
}


sub suspend_vm {
   foreach (@$vm_views) {
      my $mor_host = $_->runtime->host;
      my $hostname = Vim::get_view(mo_ref => $mor_host)->name;
      eval {
        $_->SuspendVM();
        Util::trace (0, "\n virtual machine '" . $_->name .
                  "' under host $hostname suspended ");
      };
      if ($@) {
          if (ref($@) eq 'SoapFault') {  
             Util::trace (0, "\nError in '" . $_->name . "' under host $hostname: ");
             if (ref($@->detail) eq 'NotSupported') {
                Util::trace(0,"Virtual machine is marked as a template ");
             }
             elsif (ref($@->detail) eq 'InvalidState') {
                Util::trace(0,"Current State of the "
                      ." virtual machine is not supported for this operation");
             }
             elsif (ref($@->detail) eq 'InvalidPowerState') {
                Util::trace(0, "The attempted operation".
                          " cannot be performed in the current state" );
             }
             else {
                Util::trace(0, "VM '"  .$_->name.
                   "' can't be suspended \n" . $@ . "");
             }
          }
         else {
            Util::trace(0, "VM '"  .$_->name.
                    "' can't be suspended \n" . $@ . "");
         }
      }
   }
}


sub shutdown_guest {
   foreach (@$vm_views) {
      my $mor_host = $_->runtime->host;
      my $hostname = Vim::get_view(mo_ref => $mor_host)->name;
      eval {
          $_->ShutdownGuest();
          Util::trace (0,  "\nGuest '" . $_->name . "' under host $hostname shutdown ");
      };
      if ($@) {
         if (ref($@) eq 'SoapFault') {
            Util::trace (0, "\nError in '" . $_->name . "' under host $hostname: ");
            if (ref($@->detail) eq 'InvalidState') {
               Util::trace(0,"Current State of the "
                      ." virtual machine is not supported for this operation");
            }
            elsif (ref($@->detail) eq 'InvalidPowerState') {
               Util::trace(0, "The attempted operation".
                          " cannot be performed in the current state" );
            }
            elsif (ref($@->detail) eq 'NotSupported') {
               Util::trace(0, "The operation is not supported on the object");
            }
            elsif(ref($@->detail) eq 'ToolsUnavailable') {
               Util::trace(0,"VMTools are not running in this VM");
            }
            else {
               Util::trace(0, "VM '"  .$_->name. "' can't be shutdown \n"
                      . $@ . "" );
            }
         }
         else {
            Util::trace(0, "VM '"  .$_->name. "' can't be shutdown \n"
                      . $@ . "" );
         }
      }
   }
}


sub reboot_guest {
   foreach (@$vm_views) {
      my $mor_host = $_->runtime->host;
      my $hostname = Vim::get_view(mo_ref => $mor_host)->name;
      eval {
         $_->RebootGuest();
         Util::trace (0, "\nGuest on '" . $_->name .
                "' under host $hostname rebooted successfuly");
      };
      if ($@) { 
         if (ref($@) eq 'SoapFault') {
            Util::trace (0, "\nError in '" . $_->name . "' under host $hostname: ");
            if (ref($@->detail) eq 'InvalidState') {
               Util::trace(0,"Current State of the VM"
                       ." is not supported for this operation");
            }
            elsif (ref($@->detail) eq 'NotSupported') {
               Util::trace(0,"The operation is not supported on the object ");
            }
            elsif (ref($@->detail) eq 'InvalidPowerState') {
                Util::trace(0, " The attempted operation".
                          " cannot be performed in the current state" );
            }
            elsif(ref($@->detail) eq 'ToolsUnavailable') {
               Util::trace(0,"VMTools are not running in this virtual machine");
            }
            else {
               Util::trace(0,"VM '"  .$_->name. "' can't reboot \n"
                    . $@ . ""   );
            }
         }
         else {
           Util::trace(0,"VM '"  .$_->name. "' can't reboot \n" . $@ . ""  );
         }
         exit 1;
      }
   }
}

sub validate {
  my $valid = 1;
  my $operation = Opts::get_option('operation');
   
  if($operation) {
      if (!exists($operations{$operation})) {
         Util::trace(0, "Invalid operation: '$operation'\n");
         Util::trace(0, " List of valid operations:\n");
         # bug 222613
         map {print "  $_\n"; } sort keys %operations;
         $valid = 0;
      }
   }
   return $valid;
}


sub create_hash {
   my ($ipaddress, $guestos) = @_;
   my %filterHash;
   if ($ipaddress) {
      $filterHash{'guest.ipAddress'} = $ipaddress;
   }
   # bug 299213
   if ($guestos) {
      $filterHash{'config.guestFullName'} = qr/\Q$guestos/i;
   }
   return %filterHash;
}


__END__

## bug 217605

=head1 NAME

vmcontrol.pl - Perform poweron, poweroff, suspend, reset, reboot,
               shutdown and standby operations on virtual machines.

=head1 SYNOPSIS

 vmcontrol.pl --operation <poweron|poweroff|suspend|reset|reboot|shutdown|standby> [options]

=head1 DESCRIPTION

This VI Perl command-line utility provides an interface for 
seven common provisioning operations on one or more virtual 
machines: powering on, powering off, resetting, rebooting, 
shutting down, suspending and setting into standby mode.

=head1 OPTIONS

=head2  OPERATION OPTIONS

=over

=item B<operation>

Operation to be performed.  One of the following:

I<poweron> E<ndash> Power on one or more virtual machines.

I<poweroff> E<ndash> Power off one  or more virtual machines.

I<suspend> E<ndash> Suspend one or more virtual machines.

I<reboot> E<ndash> Reboot one or more guests.

I<reset> E<ndash> Reset one or more virtual machines.

I<shutdown> E<ndash> Shutdown one or more guests.

I<standby> E<ndash> Set to standby mode one or more guests.

=back

=head2 POWER OFF OPTIONS

=over

=item B<url> 

URL of the VirtualCenter server's web service,
for example, --url https://<ipaddress>:<port>/sdk/webService

=item B<vmname>

Optional. Name of the virtual machine on which the
operation is to be performed. 

=item B<guestos>

Optional. Name of the virtual machine's guest operating system.
For example, if you specify Windows, the operation is performed
on all virtual machines running Windows

=item B<ipaddress>

Optional. IP address of the virtual machine. You cannot use ipaddress
to power on a virtual machine because a powered off virtual machine does
not have an active IP address.

=item B<datacenter>

Optional. Name of the  datacenter for the virtual machine(s).
Operations will be performed on all the virtual machines under the given datacenter.

=item B<pool>

Optional. Name of the  resource pool of the virtual machine(s).
Operations will be performed on all the virtual machines under the given pool.

=item B<folder>

Optional. Name of the folder which contains the virtual machines

=item B<host>

Optional. Name of the host which contains the virtual machines. 
Operation will be performed on all the vms under a host.

=back

=head2 POWER ON OPTIONS

=over

=item B<vmname>

Optional. Name of the virtual machine on which the
operation is to be performed.

=item B<guestos>

Optional. Name of the virtual machine's guest operating system.
For example, if you specify Windows, the operation is performed
on all virtual machines running Windows

=item B<host>

Name of the host for the virtual machine(s).

=item B<datacenter>

Optional. Name of the datacenter for the virtual machine(s).
Operations will be performed on all the virtual machines under the
given datacenter.

=item B<pool>

Optional. Name of the resource pool of the virtual machine(s).
Operations will be performed on all the virtual machines under the
given pool

=item B<folder>

Optional. Name of the folder which contains the virtual machines

=item B<host>

Optional. Name of the host which contains the virtual machines. 
Operation will be performed on all the vms under a host.

=back

=head2 REBOOT OPTIONS

=over

=item B<vmname>

Optional. Name of the virtual machine on which
the operation is to be performed.

=item B<guestos>

Optional. Name of the virtual machine's guest operating system.
For example, if you specify Windows, the operation is performed
on all virtual machines running Windows

=item B<ipaddress>

Optional. ipaddress of the virtual machine. 

=item B<datacenter>

Optional. Name of the  datacenter for the virtual machine(s).
Operations will be performed on all the virtual machines under the given datacenter.

=item B<pool>

Optional. Name of the  resource pool of the virtual machine(s).
Operations will be performed on all the virtual machines under the given pool.

=item B<folder>

Optional. Name of the folder which contains the virtual machines

=item B<host>

Optional. Name of the host which contains the virtual machines.
Operation will be performed on all the vms under a host.

=back

=head2 SHUTDOWN OPTIONS

=over

=item B<vmname>

Optional. Name of the virtual machine on which the
operation is to be performed.

=item B<guestos>

Optional. Name of the virtual machine's guest operating system.
For example, if you specify Windows, the operation is performed
on all virtual machines running Windows

=item B<ipaddress>

Optional. ipaddress of the virtual machine. 

=item B<datacenter>

Optional. Name of the  datacenter for the virtual machine(s).
Operations will be performed on all the virtual machines under the given datacenter.

=item B<pool>

Optional. Name of the  resource pool of the virtual machine(s).
Operations will be performed on all the virtual machines under the given pool.

=item B<folder>

Optional. Name of the folder which contains the virtual machines

=item B<host>

Optional. Name of the host which contains the virtual machines.
Operation will be performed on all the vms under a host.

=back

=head2 STANDBY OPTIONS

=over

=item B<vmname>

Optional. Name of the virtual machine on which the
operation is to be performed.

=item B<guestos>

Optional. Name of the virtual machine's guest operating system.
For example, if you specify Windows, the operation is performed
on all virtual machines running Windows

=item B<ipaddress>

Optional. ipaddress of the virtual machine. 

=item B<datacenter>

Optional. Name of the  datacenter for the virtual machine(s).
Operations will be performed on all the virtual machines under the given datacenter.

=item B<pool>

Optional. Name of the  resource pool of the virtual machine(s).
Operations will be performed on all the virtual machines under the given pool.

=item B<folder>

Optional. Name of the folder which contains the virtual machines

=item B<host>

Optional. Name of the host which contains the virtual machines.
Operation will be performed on all the vms under a host.

At least one criteria for selecting the virtual machines should be specified

=back

=head2 SUSPEND OPTIONS

=over

=item B<vmname>

Optional. Name of the virtual machine on which
operation is to be performed.

=item B<guestos>

Optional. Name of the virtual machine's guest operating system.
For example, if you specify Windows, the operation is performed
on all virtual machines running Windows

=item B<datacenter>

Optional. Name of the  datacenter for the virtual machine(s).
Operations will be performed on all the virtual machines under the given datacenter.

=item B<pool>

Optional. Name of the  resource pool of the virtual machine(s).
Operations will be performed on all the virtual machines under the given pool.

=item B<folder>

Optional. Name of the folder which contain the virtual machines

=item B<host>

Optional. Name of the host which contains the virtual machines.
Operation will be performed on all the vms under a host.

=back

=head2 RESET OPTIONS

=over

=item B<vmname>

Optional. Name of the virtual machine on which the
operation is to be performed.

=item B<guestos>

Optional. Name of the virtual machine's guest operating system.
For example, if you specify Windows, the operation is performed
on all virtual machines running Windows

=item B<datacenter>

Optional. Name of the  datacenter for the virtual machine(s).
Operations will be performed on all the virtual machines under the given datacenter.

=item B<pool>

Optional. Name of the  resource pool of the virtual machine(s).
Operations will be performed on all the virtual machines under the given pool.

=item B<folder>

Optional. Name of the folder which contains the virtual machines

=item B<host>

Optional. Name of the host which contains the virtual machines.
Operation will be performed on all the vms under a host.

=back

=head1 EXAMPLES

Power on a virtual machine

   vmcontrol.pl --username root --password esxadmin --operation poweron
                --vmname VM3 --url https://<ipaddress>:<port>/sdk/webService

   vmcontrol.pl --username root --password esxadmin
                --operation poweron --guestos Windows
                --url https://<ipaddress>:<port>/sdk/webService

   vmcontrol.pl --username root --password esxadmin
                --vmname VM1 --guestos Windows --operation poweron
                --https://<ipaddress>:<port>/sdk/webService

   vmcontrol.pl --username root --password esxadmin --operation poweron
                --pool poolName --url https://<ipaddress>:<port>/sdk/webService

   vmcontrol.pl --username root --password esxadmin
                --url https://<ipaddress>:<port>/sdk/webService
                --operation poweron --folder folderName

   vmcontrol.pl --username user --password mypassword --operation poweron
                --url https://<ipaddress>:<port>/sdk/webService  --pool Zod

   vmcontrol.pl --username user --password mypassword
                --operation poweron --url https://<ipaddress>:<port>/sdk/webService
                --datacenter Dracula

   vmcontrol.pl --username user --password mypassword
                --operation poweron --url https://<ipaddress>:<port>/sdk/webService
                --host ABC.BCD.XXX.XXX

   vmcontrol.pl --username user --password mypassword
                --operation poweron --url https://<ipaddress>:<port>/sdk/webService
                --folder folderName

Power off a virtual machine

    vmcontrol.pl --username root --password esxadmin --operation poweroff
                 --vmname VM3 --url https://<ipaddress>:<port>/sdk/webService

    vmcontrol.pl --username root --password esxadmin --operation poweroff
                 --guestos Windows --url https://<ipaddress>:<port>/sdk/webService

    vmcontrol.pl --username root --password esxadmin --vmname VM1 
                 --guestos Windows --operation poweroff
                 --url https://<ipaddress>:<port>/sdk/webService

    vmcontrol.pl --username root --password esxadmin --operation poweroff
                 --pool poolName --url https://<ipaddress>:<port>/sdk/webService

    vmcontrol.pl --username root --password esxadmin --operation poweroff 
                 --folder folderName --url https://<ipaddress>:<port>/sdk/webService

    vmcontrol.pl --username root --password esxadmin
                 --url https://<ipaddress>:<port>/sdk/webService
                 --operation poweroff --ipaddress IP

    vmcontrol.pl --username user --password mypassword --vmname VM2
                 --operation poweroff --url https://<ipaddress>:<port>/sdk/webService

    vmcontrol.pl --username root --password esxadmin
                 --url https://<ipaddress>:<port>/sdk/webService
                 --operation poweroff --host ABC.BCD.XXX.XXX

Reboot

    vmcontrol.pl --username root --password esxadmin --operation reboot --vmname VM3
                 --url https://<ipaddress>:<port>/sdk/webService

Shutdown

    vmcontrol.pl --username root --password esxadmin --operation shutdown
                 --vmname VM3 --url https://<ipaddress>:<port>/sdk/webService

Reset

    vmcontrol.pl --username root --password esxadmin --operation reset --vmname VM3

    vmcontrol.pl --username user --password mypassword --vmname VM2
                 --operation reset --url https://<ipaddress>:<port>/sdk/webService

Standby

    vmcontrol.pl --username root --password esxadmin --operation standby
                 --vmname VM3 --url https://<ipaddress>:<port>/sdk/webService

Suspend

    vmcontrol.pl --username root --password esxadmin --operation suspend
                 --vmname VM3 --url https://<ipaddress>:<port>/sdk/webService

    vmcontrol.pl --username user --password mypassword --vmname VM2
                 --operation suspend --url https://<ipaddress>:<port>/sdk/webService

Follow the same pattern for other operations:
reset, shutdown, reboot, standby, suspend like in poweron and poweroff.

=head1 SUPPORTED PLATFORMS

All operations supported on ESX 3.0.1

All operations supported on VirtualCenter 2.0.1

