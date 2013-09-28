#!/usr/bin/perl -w
#
# Copyright (c) 2007 VMware, Inc.  All rights reserved.
#

use strict;
use warnings;
use Getopt::Long;

use FindBin;
use lib "$FindBin::Bin/../";

use VMware::VIRuntime;

$Util::script_version = "1.0";

sub validate;

my %opts = (
   'vmname' => {
      type => "=s",
      help => "Name of the virtual machine",
      required => 1,
   },
   'cpu' => {
      type => "=s",
      help => "Share for CPU Allocation [Integral value|high|medium|low]",
      required => 0,
   },
   'memory' => {
      type => "=s",
      help => "Share for Memory Allocation [Integral value|high|medium|low]",
      required => 0,
   },
   'diskvalue' => {
      type => "=s",
      help => "Share for Disk Allocation [Integral value|high|medium|low]",
      required => 0,
   },
   'diskname' => {
      type => "=s",
      help => "Name of the disk",
      required => 0,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate(\&validate);
Util::connect();

my $valid = 1;
my $vmname = Opts::get_option('vmname');

my $vm_views = Vim::find_entity_views(view_type => 'VirtualMachine',
                                    filter => {"config.name" => $vmname});
unless (@$vm_views) {
   Util::trace(0, "Virtual machine $vmname not found.\n");
   $valid = 0;
}

if($valid ==1) {
   display_shares();
   if(Opts::option_is_set('cpu')) {
      update_cpu_shares();
   }
   if(Opts::option_is_set('memory')) {
      update_memory_shares();
   }
   if(Opts::option_is_set('diskvalue')) {
      update_disk_shares();
   }
}

Util::disconnect();

# This subroutine parses the input parameter
# Accordingly display and update the Shares for Memory, CPU and Disk
# ==================================================================
sub display_shares {
   foreach(@$vm_views) {
      my $mor_host = $_->runtime->host;
      my $hostname = Vim::get_view(mo_ref => $mor_host)->name;
      
      if(defined $_->resourceConfig) {
         my $current_mem_share_level =
            $_->resourceConfig->memoryAllocation->shares->level->val;
         my $current_mem_share =
            $_->resourceConfig->memoryAllocation->shares->shares;
         my $current_cpu_share_level =
            $_->resourceConfig->cpuAllocation->shares->level->val;
         my $current_cpu_share =
            $_->resourceConfig->cpuAllocation->shares->shares;
         Util::trace(0, "\nCurrent Shares for Virtual Machine "
                        . $_->name. " under host $hostname\n\n");
         Util::trace(0,"CPU Shares [". $current_cpu_share_level ."]: "
                        . $current_cpu_share."\n");
         Util::trace(0,"Memory Shares [".$current_mem_share_level. "]: "
                        . $current_mem_share."\n");
      }
      else {
         Util::trace(0, "\nCurrent Shares for Virtual Machine "
                        . $_->name. " under host $hostname\n\n");
         Util::trace(0,"CPU Shares [Not Defined]: "
                        . "Not Defined\n");
         Util::trace(0,"Memory Shares [Not Defined]: "
                        . "Not Defined\n");
      }
      if(Opts::get_option('diskname')) {
         my @disks = find_disk ($_, Opts::get_option('diskname'));
         if(@disks) {
            my $disk = shift @disks;
            Util::trace(0,"Disk Shares for ".Opts::get_option('diskname')
                          ." [".$disk->shares->level->val."]: "
                          .$disk->shares->shares."\n");
         }
         else {
            Util::trace(0,"Invalid Disk Name\n\n");
            return;
         }
      }
   }
}

#Update The CPU Share
#===========================================
sub update_cpu_shares {
   foreach(@$vm_views) {
      my $mor_host = $_->runtime->host;
      my $hostname = Vim::get_view(mo_ref => $mor_host)->name;
      
      if(defined $_->resourceConfig) {
         my ($cpu_shares, $level_cpu) =
            get_shares (Opts::get_option('cpu'),
            $_->resourceConfig->cpuAllocation->shares);

         my $shares_cpu =
            SharesInfo->new (shares=>$cpu_shares,level=>SharesLevel->new($level_cpu));
         my $resourceAllocationCpu = ResourceAllocationInfo->new(shares=>$shares_cpu);

         # Virtual Machine Config Spec is required for reconfiguring the Shares
         my $vmConfig =
            VirtualMachineConfigSpec->new (cpuAllocation => $resourceAllocationCpu);

         eval {
            Util::trace(0,"Updating cpu shares...");
            $_->ReconfigVM (spec => $vmConfig);
            $_->update_view_data();
            $cpu_shares = $_->resourceConfig->cpuAllocation->shares->shares;
            my $resource = $_->resourceConfig;
            Util::trace(0,"\nUpdated CPU Shares of Virtual Machine $vmname under host "
                          ."$hostname ["
                          . $resource->cpuAllocation->shares->level->val. "]: "
                          . $resource->cpuAllocation->shares->shares."\n");

         };
         if ($@) {
            if (ref($@) eq 'SoapFault') {
               if (ref($@->detail) eq 'InvalidRequest') {
                  Util::trace(0, "\nCPU parameter is Invalid. Valid values: "
                                 ."[Integral Value|high|normal|low]. \n\n");
               }
               elsif (ref($@->detail) eq 'InvalidPowerState') {
                  Util::trace(0, "\nVirtual Machine $vmname under host $hostname".
                                 " is poweredOn and the virtual".
                                 " hardware cannot support the configuration".
                                 " changes. \n\n");
               }
               elsif (ref($@->detail) eq 'InvalidState') {
                  Util::trace(0, "\nOperation is not allowed in the "
                                 ." current state. \n\n");
               }
               elsif (ref($@->detail) eq 'NotSupported') {
                  Util::trace(0, "\nOperation not suuported on object. \n\n");
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
          Util::trace(0, "\nReconfig Operation not allowed in "
                         ."Virtual Machine $vmname under host $hostname"
                         ." is poweredOn and the virtual"
                         ." hardware cannot support the configuration changes. \n\n");
      }
   }
}

#Update The Memory Share
#===========================================
sub update_memory_shares {
   foreach(@$vm_views) {
      my $mor_host = $_->runtime->host;
      my $hostname = Vim::get_view(mo_ref => $mor_host)->name;
      
      if(defined $_->resourceConfig) {
         my ($mem_shares, $level_mem) =
         get_shares (Opts::get_option('memory'),
            $_->resourceConfig->memoryAllocation->shares);

         my $shares_mem = SharesInfo->new (shares => $mem_shares,
                                           level => SharesLevel->new($level_mem));
         my $resourceAllocationMem = ResourceAllocationInfo->new (shares=>$shares_mem);

         # Virtual Machine Config Spec is required for reconfiguring the Shares
         my $vmConfig =
            VirtualMachineConfigSpec->new (memoryAllocation=>$resourceAllocationMem);

         eval {
            Util::trace(0,"Updating memory shares...");
            $_->ReconfigVM (spec => $vmConfig);
            $_->update_view_data();
            $mem_shares = $_->resourceConfig->memoryAllocation->shares->shares;
            my $resource = $_->resourceConfig;
            Util::trace(0,"\nUpdated Memory Shares of Virtual Machine $vmname under host "
                           . " $hostname ["
                           . $resource->memoryAllocation->shares->level->val. "]: "
                           . $resource->memoryAllocation->shares->shares."\n");
         };
         if ($@) {
            if (ref($@) eq 'SoapFault') {
               if (ref($@->detail) eq 'InvalidRequest') {
                  Util::trace(0, "\nThe Memory parameter is Invalid. Valid values: "
                                 ."[Integral Value|high|normal|low]. \n\n");
               }
               elsif (ref($@->detail) eq 'InvalidPowerState') {
                  Util::trace(0, "\nVirtual Machine $vmname under host $hostname".
                                 " is poweredOn and the virtual".
                                 " hardware cannot support the configuration changes"
                                 . "\n\n");
               }
               elsif (ref($@->detail) eq 'InvalidState') {
                  Util::trace(0, "\nOperation is not allowed in the "
                                 ." current state. \n\n");
               }
               elsif (ref($@->detail) eq 'NotSupported') {
                  Util::trace(0, "\nOperation not suuported on object. \n\n");
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
          Util::trace(0, "\nReconfig Operation not allowed in "
                         ."Virtual Machine $vmname under host $hostname"
                         ." is poweredOn and the virtual"
                         ." hardware cannot support the configuration changes. \n\n");
      }
   }
}

#Update The Disk Share
#===========================================
sub update_disk_shares {
   foreach(@$vm_views) {
      my $mor_host = $_->runtime->host;
      my $hostname = Vim::get_view(mo_ref => $mor_host)->name;
      
      if (defined Opts::get_option('diskname')) {
         my @disks = find_disk ($_, Opts::get_option('diskname'));
         if (@disks) {
            my $device = shift @disks;
            my $level =
               (isNumber (Opts::get_option('diskvalue'))) ?
               'custom' : lc(Opts::get_option('diskvalue'));

            my $shares =
               (isNumber (Opts::get_option('diskvalue'))) ?
                Opts::get_option('diskvalue') : 0;
                   
            my $sharesInfo =
               SharesInfo->new (shares=>$shares,level=>SharesLevel->new($level));
               $device->shares ($sharesInfo);

            # Creates Virtual Device spec to add the device in Virtual Machine
            my $virtualDeviceConfigSpec =
               VirtualDeviceConfigSpec->new (device => $device,
                  operation => VirtualDeviceConfigSpecOperation->new('edit'));

            # Virtual Machine Config Spec is required for reconfiguring the Shares
            my $vmConfig =
               VirtualMachineConfigSpec->new (
                  deviceChange => [$virtualDeviceConfigSpec]);

            eval {
               Util::trace(0,"Updating disk shares...");
               $_->ReconfigVM (spec => $vmConfig);
               $_->update_view_data();

               my @newdisk = find_disk ($_, Opts::get_option('diskname'));
               my $newdevice = shift @newdisk;
               Util::trace(0,"\nUpdated Disk Shares of Virtual Machine under host "
                            ."$hostname ". $vmname
                            ." for ".Opts::get_option('diskname')
                            ." [".$newdevice->shares->level->val."]: "
                            . $newdevice->shares->shares."\n");
            };
            if ($@) {
               if (ref($@) eq 'SoapFault') {
                  if (ref($@->detail) eq 'InvalidRequest') {
                     Util::trace(0, "\nThe Diskvalue parameter is Invalid. Valid values: "
                                    ."[Integral Value|high|normal|low]. \n\n");
                  }
                  elsif (ref($@->detail) eq 'InvalidPowerState') {
                     Util::trace(0, "\nVirtual Machine $vmname under host $hostname".
                              " is poweredOn and the virtual".
                              " hardware cannot support the configuration changes. \n\n");
                  }
                  elsif (ref($@->detail) eq 'InvalidState') {
                     Util::trace(0, "\nOperation is not allowed "
                                    ."in the current state. \n\n");
                  }
                  elsif (ref($@->detail) eq 'NotSupported') {
                     Util::trace(0, "\nOperation not suuported on object. \n\n");
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
            Util::trace(0,"\nInvalid Disk Name\n\n");
         }
      }
   }
}

#Sub routine to check wheather value is Numeric
sub isNumber {
   my ($val) = @_;
   my $result = ($val =~ /^-?(?:\d+(?:\.\d*)?|\.\d+)$/);
   return $result;
}

sub get_shares {
   my ($share, $shareObject) = @_;
   my ($level, $value);
   if (defined $share) {
      $level = (isNumber ($share)) ? 'custom' : $share;
      $value = (isNumber ($share)) ? $share : 0;
   }
   else {
      $level = $shareObject->level;
      $value = $shareObject->shares;
   }
   return ($value, $level);
}

sub find_disk {
   my ($vm, $name) = @_;
   my @array;
   my $devices = $vm->config->hardware->device;
   foreach my $device (@$devices) {
      my $deviceName = $device->deviceInfo->label;
      push (@array, $device) if ((! defined $name) || ($name eq $deviceName));
   }
   return @array;
}

# This subroutine is used for validating the Arguemnts 
# 1) VMName is mandotary argument
# 2) diskname attribute is required for updating the Disk resource.
# ================================================================
sub validate {
   my $valid = 1;
   if (Opts::option_is_set('diskvalue')) {
      if (!Opts::option_is_set('diskname')) {
         Util::trace(0, "\nMust specify parameter diskname for updating disk share \n");
         $valid = 0;
      }
      if(isNumber (Opts::get_option('diskvalue'))) {
         if(Opts::get_option('diskvalue') <= 0) {
            Util::trace(0, "\nDisk Share must be a poistive non zero number \n");
            $valid = 0;
         }
      }
   }
   if (Opts::option_is_set('cpu')) {
      if(isNumber (Opts::get_option('cpu'))) {
         if(Opts::get_option('cpu') <= 0) {
            Util::trace(0, "\nCPU Share must be a poistive non zero number \n");
            $valid = 0;
         }
      }
   }
   if (Opts::option_is_set('memory')) {
      if(isNumber (Opts::get_option('memory'))) {
         if(Opts::get_option('memory') <= 0) {
            Util::trace(0, "\nMemory Share must be a poistive non zero number \n");
            $valid = 0;
         }
      }
   }
   
   return $valid;
}

__END__

## bug 217605

=head1 NAME

sharesmanager.pl - Display or modify shares for memory, CPU, and
            disk for specified virtual machines.

=head1 SYNOPSIS

 sharesmanager.pl --vmname <name of virtual machine> [options]

=head1 DESCRIPTION

This VI Perl command-line utility provides an interface for modifying
shares for memory, CPU, and disk for specified virtual machine.

=head1 OPTIONS

=over

=item B<vmname>

Required. The name of the source virtual machine.
The shares of the specified virtual machine will be displayed and updated
for different resources.

=item B<memory>

Optional. Value of memory share [Integral Value|low|normal|high]. The memory allocation
share will be updated accordingly.

=item B<cpu>

Optional. Value of CPU share [Integral Value|low|normal|high]. The CPU allocation
share will be updated accordingly.

=item B<diskvalue>

Optional. Value of disk share [Integral Value|low|normal|high]

=item B<diskname>

Required if <diskvalue> option is specified. Name of disk whose shares need to be updated.

=back

=head1 EXAMPLES

Display Memory and CPU Share of virtual machine:

 sharesmanager.pl --url <https://<IP Address>:<Port>/sdk/vimService>
                  --username user --password mypassword
                  --vmname VM123

Display Disk Share of virtual machine:

 sharesmanager.pl --url <https://<IP Address>:<Port>/sdk/vimService>
                  --username user --password mypassword
                  --vmname VM123 --diskname "Hard Disk 1"

Update Memory Share of a virtual machine to low:

 sharesmanager.pl --url <https://<IP Address>:<Port>/sdk/vimService>
                  --username user --password mypassword
                  --vmname VM123 --memory low

Update CPU Share of a virtual machine to high:

 sharesmanager.pl --url <https://<IP Address>:<Port>>/sdk/vimService>
                  --username user --password mypassword
                  --vmname VM123 --cpu high

Update Disk Share of a virtual machine to 100:

 sharesmanager.pl --url <https://<IP Address>:<Port>/sdk/vimService>
                  --username user --password mypassword
                  --vmname VM123 --diskvalue 100
                  --diskname "Hard Disk 1"

=head1 SUPPORTED PLATFORMS

All operations work with VMware VirtualCenter 2.0 or later.

All operations work with VMware ESX 3.0 or later.

