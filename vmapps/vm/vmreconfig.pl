#!/usr/bin/perl -w
#
# Copyright (c) 2007 VMware, Inc.  All rights reserved.
#

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../";

use VMware::VIRuntime;
use XML::LibXML;
use AppUtil::XMLInputUtil;
use AppUtil::HostUtil;
use AppUtil::VMUtil;

$Util::script_version = "1.0";

sub parse_xml;

my %opts = (
   filename => {
      type => "=s",
      help => "The location of the input xml file",
      required => 0,
      default => "../sampledata/vmreconfig.xml",
   },
   schema => {
      type => "=s",
      help => "The location of the schema file",
      required => 0,
      default => "../schema/vmreconfig.xsd",
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate(\&validate);

Util::connect();
my %reconfig_hash = parse_xml();
my %filterhash = ();
my @device_config_specs;
my ($resourceAllocationMem, $resourceAllocationCpu);

my $vm_views = VMUtils::get_vms('VirtualMachine',
                                   $reconfig_hash{Name},
                                   undef,
                                   undef,
                                   undef,
                                   $reconfig_hash{Host},
                                   %filterhash);
my $vm_view = shift (@$vm_views);

if($vm_view) {
   @device_config_specs = get_device_config_specs();
   ($resourceAllocationMem, $resourceAllocationCpu) = get_shares_info();
   reconfig_vm();
}

Util::disconnect();


# This subroutine reconfigures a virtual machine as per the devices'
# configurations specs present in the @device_config_specs,
# $resourceAllocationCpu and $resourceAllocationMem objects.
# ===================================================================
sub reconfig_vm {
   my $vmspec;
   if(@device_config_specs && $resourceAllocationCpu && $resourceAllocationMem) {
      $vmspec = VirtualMachineConfigSpec->new(deviceChange => \@device_config_specs,
                                              cpuAllocation => $resourceAllocationCpu,
                                              memoryAllocation=>$resourceAllocationMem);
   }
   elsif(@device_config_specs && $resourceAllocationCpu && !($resourceAllocationMem)) {
      $vmspec = VirtualMachineConfigSpec->new(deviceChange => \@device_config_specs,
                                              cpuAllocation => $resourceAllocationCpu);
   }
   elsif(@device_config_specs && $resourceAllocationMem && !($resourceAllocationCpu)) {
      $vmspec = VirtualMachineConfigSpec->new(deviceChange => \@device_config_specs,
                                              memoryAllocation=>$resourceAllocationMem);
   }
   elsif(!(@device_config_specs) && $resourceAllocationCpu && $resourceAllocationMem) {
      $vmspec = VirtualMachineConfigSpec->new(cpuAllocation => $resourceAllocationCpu,
                                              memoryAllocation=>$resourceAllocationMem);
   }
   elsif($resourceAllocationMem) {
      $vmspec = VirtualMachineConfigSpec->new(memoryAllocation=>$resourceAllocationMem);
   }
   elsif($resourceAllocationCpu) {
      $vmspec = VirtualMachineConfigSpec->new(cpuAllocation => $resourceAllocationCpu);
   }
   elsif(@device_config_specs) {
      $vmspec = VirtualMachineConfigSpec->new(deviceChange => \@device_config_specs);
   }
   else {
      Util::trace(0,"\nNo reconfiguration performed as there "
                  . "is no device config spec created.\n");
      return;
   }

   eval {
      $vm_view->ReconfigVM( spec => $vmspec );
      Util::trace(0,"\nVirtual machine '" . $vm_view->name
                  . "' is reconfigured successfully.\n");
   };
   if ($@) {
       Util::trace(0, "\nReconfiguration failed: ");
       if (ref($@) eq 'SoapFault') {
          if (ref($@->detail) eq 'TooManyDevices') {
             Util::trace(0, "\nNumber of virtual devices exceeds "
                          . "the maximum for a given controller.\n");
          }
          elsif (ref($@->detail) eq 'InvalidDeviceSpec') {
             Util::trace(0, "The Device configuration is not valid\n");
             Util::trace(0, "\nFollowing is the detailed error: \n\n$@");
          }
          elsif (ref($@->detail) eq 'FileAlreadyExists') {
             Util::trace(0, "\nOperation failed because file already exists");
          }
          else {
             Util::trace(0, "\n" . $@ . "\n");
          }
       }
       else {
          Util::trace(0, "\n" . $@ . "\n");
       }
   }
}


# This subroutine creates the various devices' configurations specs
# based on the parameters specified in the input XML file.
# =================================================================
sub get_device_config_specs {
   my @device_config_specs = ();
   
   # Add device
   # ----------
   if($reconfig_hash{'Add-Device'}{'Network-Adapter'}{'Name'}) {
      my $device_spec
         = VMUtils::create_network_spec($vm_view,
              $reconfig_hash{'Add-Device'}{'Network-Adapter'}{'Name'}, 'add', undef);
      if ($device_spec) {
         @device_config_specs = (@device_config_specs, $device_spec);
      }
   }
   if($reconfig_hash{'Add-Device'}{'Hard-Disk'}{'Name'}) {
       my $device_spec
          = add_disk_spec($vm_view, $reconfig_hash{'Add-Device'}{'Hard-Disk'}{'Name'},
                         $reconfig_hash{'Add-Device'}{'Hard-Disk'}{'Persistent-Mode'},
                         $reconfig_hash{'Add-Device'}{'Hard-Disk'}{'Size'});
                         
      if ($device_spec) {
         @device_config_specs = (@device_config_specs, $device_spec);
      }
   }
   if($reconfig_hash{'Add-Device'}{'Floppy-Drive'}{'Name'}) {
      my $device_spec
         = VMUtils::create_floppy_spec($vm_view,
              $reconfig_hash{'Add-Device'}{'Floppy-Drive'}{'Name'}, 'add', undef);
      if ($device_spec) {
         @device_config_specs = (@device_config_specs, $device_spec);
      }
   }
   if($reconfig_hash{'Add-Device'}{'CD-DVD-Drive'}{'Name'}) {
      my $device_spec
         = VMUtils::create_cd_spec($vm_view,
              $reconfig_hash{'Add-Device'}{'CD-DVD-Drive'}{'Name'}, 'add', undef);
      if ($device_spec) {
         @device_config_specs = (@device_config_specs, $device_spec);
      }
   }
   
   
   # Remove device
   # -------------
   if($reconfig_hash{'Remove-Device'}{'Network-Adapter'}{'Name'}) {
      my $device_spec
         = VMUtils::create_network_spec($vm_view,
            $reconfig_hash{'Remove-Device'}{'Network-Adapter'}{'Name'},'remove',undef);
      if ($device_spec) {
         @device_config_specs = (@device_config_specs, $device_spec);
      }
   }
   if($reconfig_hash{'Remove-Device'}{'Hard-Disk'}{'Name'}) {
      my $device_spec
         = remove_disk_spec($vm_view,
              $reconfig_hash{'Remove-Device'}{'Hard-Disk'}{'Name'});
      if ($device_spec) {
         @device_config_specs = (@device_config_specs, $device_spec);
      }
   }
   if($reconfig_hash{'Remove-Device'}{'CD-DVD-Drive'}{'Name'}) {
      my $device_spec
         = VMUtils::create_cd_spec($vm_view,
              $reconfig_hash{'Remove-Device'}{'CD-DVD-Drive'}{'Name'},'remove', undef);
      if ($device_spec) {
         @device_config_specs = (@device_config_specs, $device_spec);
      }
   }
   if($reconfig_hash{'Remove-Device'}{'Floppy-Drive'}{'Name'}) {
      my $device_spec
         = VMUtils::create_floppy_spec($vm_view,
             $reconfig_hash{'Remove-Device'}{'Floppy-Drive'}{'Name'},'remove', undef);
      if ($device_spec) {
         @device_config_specs = (@device_config_specs, $device_spec);
      }
   }


   # Connect device
   # -------------
   if($reconfig_hash{'Connect-Device'}{'Network-Adapter'}{'Name'}) {
      my $device_spec
         = VMUtils::create_network_spec($vm_view,
           $reconfig_hash{'Connect-Device'}{'Network-Adapter'}{'Name'},'connect',undef);
      if ($device_spec) {
         @device_config_specs = (@device_config_specs, $device_spec);
      }
   }
   
   if($reconfig_hash{'Connect-Device'}{'CD-DVD-Drive'}{'Name'}) {
      my $device_spec
         = VMUtils::create_cd_spec($vm_view,
          $reconfig_hash{'Connect-Device'}{'CD-DVD-Drive'}{'Name'},'connect', undef);
      if ($device_spec) {
         @device_config_specs = (@device_config_specs, $device_spec);
      }
   }
   
   if($reconfig_hash{'Connect-Device'}{'Floppy-Drive'}{'Name'}) {
      my $device_spec
         = VMUtils::create_floppy_spec($vm_view,
            $reconfig_hash{'Connect-Device'}{'Floppy-Drive'}{'Name'},'connect', undef);
      if ($device_spec) {
         @device_config_specs = (@device_config_specs, $device_spec);
      }
   }


   # Disconnect device
   # -----------------
   if($reconfig_hash{'Disconnect-Device'}{'Floppy-Drive'}{'Name'}) {
      my $device_spec
         = VMUtils::create_floppy_spec($vm_view,
            $reconfig_hash{'Disconnect-Device'}{'Floppy-Drive'}{'Name'},
            'disconnect',undef);
      if ($device_spec) {
         @device_config_specs = (@device_config_specs, $device_spec);
      }
   }
   
   if($reconfig_hash{'Disconnect-Device'}{'Network-Adapter'}{'Name'}) {
      my $device_spec
         = VMUtils::create_network_spec($vm_view,
            $reconfig_hash{'Disconnect-Device'}{'Network-Adapter'}{'Name'},
            'disconnect', undef);
      if ($device_spec) {
         @device_config_specs = (@device_config_specs, $device_spec);
      }
   }


   if($reconfig_hash{'Disconnect-Device'}{'CD-DVD-Drive'}{'Name'}) {
      my $device_spec
         = VMUtils::create_cd_spec($vm_view,
            $reconfig_hash{'Disconnect-Device'}{'CD-DVD-Drive'}{'Name'},
            'disconnect', undef);
      if ($device_spec) {
         @device_config_specs = (@device_config_specs, $device_spec);
      }
   }


   # Set Power On Flag
   # -----------------
    if($reconfig_hash{'PowerOn-Flag'}{'Network-Adapter'}{'Name'}) {
      my $device_spec
         = VMUtils::create_network_spec($vm_view,
              $reconfig_hash{'PowerOn-Flag'}{'Network-Adapter'}{'Name'},
              'setflag', $reconfig_hash{'PowerOn-Flag'}{'Network-Adapter'}{'PowerOn'});
      if ($device_spec) {
         @device_config_specs = (@device_config_specs, $device_spec);
      }
    }
    
    if($reconfig_hash{'PowerOn-Flag'}{'Floppy-Drive'}{'Name'}) {
      my $device_spec
         = VMUtils::create_floppy_spec($vm_view,
              $reconfig_hash{'PowerOn-Flag'}{'Floppy-Drive'}{'Name'},
              'setflag', $reconfig_hash{'PowerOn-Flag'}{'Floppy-Drive'}{'PowerOn'});
      if ($device_spec) {
         @device_config_specs = (@device_config_specs, $device_spec);
      }
    }
    
    if($reconfig_hash{'PowerOn-Flag'}{'CD-DVD-Drive'}{'Name'}) {
      my $device_spec
         = VMUtils::create_cd_spec($vm_view,
              $reconfig_hash{'PowerOn-Flag'}{'CD-DVD-Drive'}{'Name'},
              'setflag', $reconfig_hash{'PowerOn-Flag'}{'CD-DVD-Drive'}{'PowerOn'});
      if ($device_spec) {
         @device_config_specs = (@device_config_specs, $device_spec);
      }
    }

   return @device_config_specs;
}


sub parse_xml() {
   my %reconfig_hash = ();
   my $filename = Opts::get_option('filename');
   my $parser = XML::LibXML->new();
   my $tree = $parser->parse_file($filename);
   my $xc = XML::LibXML::XPathContext->new($tree);
   my $root = 'Reconfigure-Virtual-Machine';

   $reconfig_hash{Name} = ($xc->find("/$root/Name"))->string_value();
   $reconfig_hash{Host} = ($xc->find("/$root/Host"))->string_value();

   # Devices to add
   $reconfig_hash{'Add-Device'}{'Network-Adapter'}{'Name'}
      = ($xc->find("/$root/Add-Device/Network-Adapter/Name"))->string_value();
   $reconfig_hash{'Add-Device'}{'Floppy-Drive'}{'Name'}
      = ($xc->find("/$root/Add-Device/Floppy-Drive/Name"))->string_value();
   $reconfig_hash{'Add-Device'}{'CD-DVD-Drive'}{'Name'}
      = ($xc->find("/$root/Add-Device/CD-DVD-Drive/Name"))->string_value();
   $reconfig_hash{'Add-Device'}{'Hard-Disk'}{'Name'}
      = ($xc->find("/$root/Add-Device/Hard-Disk/Name"))->string_value();
   $reconfig_hash{'Add-Device'}{'Hard-Disk'}{'Size'}
      = ($xc->find("/$root/Add-Device/Hard-Disk/Size"))->string_value();
   $reconfig_hash{'Add-Device'}{'Hard-Disk'}{'Persistent-Mode'}
      = ($xc->find("/$root/Add-Device/Hard-Disk/Persistent-Mode"))->string_value();

   # Devices to remove
   $reconfig_hash{'Remove-Device'}{'Network-Adapter'}{'Name'}
      = ($xc->find("/$root/Remove-Device/Network-Adapter/Name"))->string_value();
   $reconfig_hash{'Remove-Device'}{'Floppy-Drive'}{'Name'}
      = ($xc->find("/$root/Remove-Device/Floppy-Drive/Name"))->string_value();
   $reconfig_hash{'Remove-Device'}{'CD-DVD-Drive'}{'Name'}
      = ($xc->find("/$root/Remove-Device/CD-DVD-Drive/Name"))->string_value();
   $reconfig_hash{'Remove-Device'}{'Hard-Disk'}{'Name'}
      = ($xc->find("/$root/Remove-Device/Hard-Disk/Name"))->string_value();

   # Devices to connect
   $reconfig_hash{'Connect-Device'}{'Network-Adapter'}{'Name'}
      = ($xc->find("/$root/Connect-Device/Network-Adapter/Name"))->string_value();
   $reconfig_hash{'Connect-Device'}{'Floppy-Drive'}{'Name'}
      = ($xc->find("/$root/Connect-Device/Floppy-Drive/Name"))->string_value();
   $reconfig_hash{'Connect-Device'}{'CD-DVD-Drive'}{'Name'}
      = ($xc->find("/$root/Connect-Device/CD-DVD-Drive/Name"))->string_value();

   # Devices to disconnect
   $reconfig_hash{'Disconnect-Device'}{'Network-Adapter'}{'Name'}
      = ($xc->find("/$root/Disconnect-Device/Network-Adapter/Name"))->string_value();
   $reconfig_hash{'Disconnect-Device'}{'Floppy-Drive'}{'Name'}
      = ($xc->find("/$root/Disconnect-Device/Floppy-Drive/Name"))->string_value();
   $reconfig_hash{'Disconnect-Device'}{'CD-DVD-Drive'}{'Name'}
      = ($xc->find("/$root/Disconnect-Device/CD-DVD-Drive/Name"))->string_value();

   # PowerOn flag
   $reconfig_hash{'PowerOn-Flag'}{'Network-Adapter'}{'Name'}
      = ($xc->find("/$root/PowerOn-Flag/Network-Adapter/Name"))->string_value();
   $reconfig_hash{'PowerOn-Flag'}{'Network-Adapter'}{'PowerOn'}
      = ($xc->find("/$root/PowerOn-Flag/Network-Adapter/PowerOn"))->string_value();
   $reconfig_hash{'PowerOn-Flag'}{'Floppy-Drive'}{'Name'}
      = ($xc->find("/$root/PowerOn-Flag/Floppy-Drive/Name"))->string_value();
   $reconfig_hash{'PowerOn-Flag'}{'Floppy-Drive'}{'PowerOn'}
      = ($xc->find("/$root/PowerOn-Flag/Floppy-Drive/PowerOn"))->string_value();
   $reconfig_hash{'PowerOn-Flag'}{'CD-DVD-Drive'}{'Name'}
      = ($xc->find("/$root/PowerOn-Flag/CD-DVD-Drive/Name"))->string_value();
   $reconfig_hash{'PowerOn-Flag'}{'CD-DVD-Drive'}{'PowerOn'}
      = ($xc->find("/$root/PowerOn-Flag/CD-DVD-Drive/PowerOn"))->string_value();

   # Shares to be updated
   $reconfig_hash{'Shares'}{'CPU'}
      = ($xc->find("/$root/Shares/CPU"))->string_value();
   $reconfig_hash{'Shares'}{'Memory'}
      = ($xc->find("/$root/Shares/Memory"))->string_value();

   return %reconfig_hash;
}


sub get_shares_info {
   my $resourceAllocationMemory;
   my $resourceAllocationCPU;

   if($reconfig_hash{'Shares'}{'CPU'}) {
      my $shares = $reconfig_hash{'Shares'}{'CPU'};
      my $level
         = (isNumber ($shares)) ? 'custom' : $shares;

      if ($level eq 'custom') {
         $shares = $reconfig_hash{'Shares'}{'CPU'};
         # Bug 297612 
          if($shares <= 0){
           die "\nCPU shares value must be positive.\n";
          }
         # Bug 297612
      }
      else {
         $shares = undef;
      }
      my $shares_cpu = SharesInfo->new (shares => $shares,
                                       level => SharesLevel->new($level));
      $resourceAllocationCPU = ResourceAllocationInfo->new (shares=>$shares_cpu);
      Util::trace(0, "\nUpdating CPU shares . . .\n");
   }

   if($reconfig_hash{'Shares'}{'Memory'}) {
      my $shares = $reconfig_hash{'Shares'}{'Memory'};
      my $level
         = (isNumber ($shares)) ? 'custom' : $shares;

      if ($level eq 'custom') {
         $shares = $reconfig_hash{'Shares'}{'Memory'};
         # Bug 297612
         if($shares <= 0){
           die "\nMemory shares value must be positive.\n";           
         }
         # Bug 297612
      }
      else {
         $shares = undef;
      }
      my $shares_memory = SharesInfo->new (shares => $shares,
                                       level => SharesLevel->new($level));
      $resourceAllocationMemory = ResourceAllocationInfo->new (shares=>$shares_memory);
      Util::trace(0, "\nUpdating Memory shares . . .\n");
   }

   return ($resourceAllocationMemory, $resourceAllocationCPU);
}



sub add_disk_spec {
   my ($vm_view, $name, $diskMode, $disksize) = @_;
   my ($config_spec_operation, $config_file_operation);
   my $disk;
   # bug 418095
   my $controller = VMUtils::find_scsi_controller_device(vm => $vm_view);
   my $controllerKey = $controller->key;
   my $unitNumber = $#{$controller->device} + 1;

   my $size = $disksize * 1024;
   my $fileName = VMUtils::generate_filename(vm => $vm_view,
                                    filename => $name);

   Util::trace(0,"\nAdding new hard disk with file name $fileName . . .");

   my $devspec = VMUtils::get_vdisk_spec(vm => $_,
                             backingtype => 'regular',
                             diskMode => $diskMode,
                             fileName => $fileName,
                             controllerKey => $controllerKey,
                             unitNumber => $unitNumber,
                             size => $size);
   return $devspec;
}


sub remove_disk_spec {
   my ($vm_view, $name, $diskMode, $disksize) = @_;
   my ($config_spec_operation, $config_file_operation);
   my $disk;
   $config_spec_operation = VirtualDeviceConfigSpecOperation->new('remove');
   $config_file_operation = VirtualDeviceConfigSpecFileOperation->new('destroy');

   $disk = VMUtils::find_device(vm => $vm_view,
                                controller => $name);

   if($disk) {
      Util::trace(0,"\nRemoving hard disk with the backing filename '"
                  . $disk->backing->fileName . "' . . .");
      my $devspec =
         VirtualDeviceConfigSpec->new(operation => $config_spec_operation,
                                      device => $disk,
                                      fileOperation => $config_file_operation);
      return $devspec;
   }

   return undef;
}


#Sub routine to check wheather value is Numeric
sub isNumber {
   my ($val) = @_;
   my $result = ($val =~ /^-?(?:\d+(?:\.\d*)?|\.\d+)$/);
   return $result;
}


# check the XML file
# =====================
sub validate {
   my $valid = XMLValidation::validate_format(Opts::get_option('filename'));
   if ($valid == 1) {
      $valid = XMLValidation::validate_schema(Opts::get_option('filename'),
                                             Opts::get_option('schema'));
   }
   return $valid;
}

__END__

## bug 217605

=head1 NAME

vmreconfig.pl - Reconfigure a virtual machine.

=head1 SYNOPSIS

 vmreconfig.pl [options]

=head1 DESCRIPTION

This VI Perl command-line utility provides an interface to reconfigure a virtual
machine based on the parameters specified in the valid XML file. The syntax
of the XML file is validated against the specified schema file.. Reconfiguring a
virtual machine involves the following operations:

=over

=item *

Add or Remove NetworkAdapter, Floppy, CD, Disk.

=item *

Connect or Disconnect NetworkAdapter, Floppy, CD

=item *

Connect the NIC, Floppy, CD when the virtual machine starts.

=item *

Increase or Decrease CPU and memory shares.

=back

The user can perform multiple operation at a time. For e.g a user can add a hard
disk, remove a floppy and change the memory shares in a single run. Suppose a user
wants to remove a hard disk which is not present and also remove a floppy which
exists, then the reconfigure operation will be completed successfully for the
floppy but it will ignore the settings for invalid hard disk name because the script
will create the device config spec for floppy only. If the XML file only contains
the parameters for removing a non-existent disk then the device config spec will not
be created and no reconfiguration will be performed.

=head1 OPTIONS

=over

=item B<filename>

Optional. The location of the XML file which contains the reconfiguration parameters.
If this option is not specified, then the default file 'vmreconfig.xml' will be used
from the "../sampledata" directory. The user can use this file as a reference to
create there own input XML files and specify the file's location using the <filename>
option.

=item B<schema>

Optional. The location of the schema file against which the input XML file is
validated. If this option is not specified, then the file 'vmreconfig.xsd' will
be used from the "../schema" directory. This file need not be modified by the user.

=back

=head1 XML INPUT

The parameters for creating the virtual machine are specified in an XML file.
Choose input parameters for the XML file from the following:

=head2 VIRTUAL MACHINE PARAMETERS

=over

=item B<Name>

Required. Name of the virtual machine.

=item B<Host>

Required. Name of the host.

=back

=head2 ADD-DEVICE PARAMETERS

=over

=item B<Name>

Optional. Name of the device. Each of the NetworkAdapter, Floppy, CD
and Disk device has different <Name> element in the XML file.

=item B<Size>

Optional. Size of the hard disk.

=item B<Persistent-Mode>

Optional. Mode of the hard disk. The mode must be one of the following:

   persistent
   nonpersistent
   undoable
   independent_persistent
   independent_nonpersistent
   append

=back

=head2 REMOVE-DEVICE PARAMETER

=over

=item B<Name>

Optional. Name of the device. Each of the NetworkAdapter, Floppy, CD
and Disk device has different <Name> element in the XML file.

=back

=head2 CONNECT-DEVICE PARAMETER

=over

=item B<Name>

Optional. Name of the device. Each of the NetworkAdapter, Floppy and CD
device has different <Name> element in the XML file.

=back

=head2 DISCONNECT-DEVICE PARAMETER

=over

=item B<Name>

Optional. Name of the device. Each of the NetworkAdapter, Floppy and CD
device has different <Name> element in the XML file.

=back

=head2 POWERON-FLAG PARAMETERS

=over

=item B<Name>

Optional. Name of the device. Each of the NetworkAdapter, Floppy and CD
device has different <Name> element in the XML file.

=item B<PowerOn>

Optional. Flag to specify whether or not to connect the device when the
virtual machine starts. Each of the NetworkAdapter, Floppy and CD
device has different <Name> and <PowerOn> element in the XML file.
Value must be 'true' or 'false'.

=back

=head2 SHARES PARAMETERS

=over

=item B<CPU>

Optional. Value of the CPU share [Integral Value|low|normal|high].

=item B<Memory>

Optional. Value of memory share [Integral Value|low|normal|high].

=back

=head1 SAMPLE INPUT XML FILE

 <?xml version="1.0"?>
 <Reconfigure-Virtual-Machine>
  <Name>VMName</Name>
  <Host>HostName</Host>
  <Add-Device>
   <Network-Adapter>
    <Name>VM Network</Name>
   </Network-Adapter>
   <Floppy-Drive>
    <Name>Floppy1</Name>
   </Floppy-Drive>
   <CD-DVD-Drive>
    <Name>Drive22</Name>
   </CD-DVD-Drive>
   <Hard-Disk>
    <Name>Hard Disk12</Name>
    <Size>10</Size>
    <Persistent-Mode>persistent</Persistent-Mode>
   </Hard-Disk>
  </Add-Device>
  <Remove-Device>
   <Network-Adapter>
    <Name>VM Network</Name>
   </Network-Adapter>
   <Floppy-Drive>
    <Name>F1</Name>
   </Floppy-Drive>
   <CD-DVD-Drive>
    <Name>CD2</Name>
   </CD-DVD-Drive>
   <Hard-Disk>
    <Name>Disk22</Name>
   </Hard-Disk>
  </Remove-Device>
  <Connect-Device>
   <Network-Adapter>
    <Name>VM Network</Name>
   </Network-Adapter>
   <Floppy-Drive>
    <Name>Floppy</Name>
   </Floppy-Drive>
   <CD-DVD-Drive>
    <Name>CD2</Name>
   </CD-DVD-Drive>
  </Connect-Device>
  <Disconnect-Device>
   <Network-Adapter>
    <Name>VM Network</Name>
   </Network-Adapter>
   <Floppy-Drive>
    <Name>Floppy</Name>
   </Floppy-Drive>
   <CD-DVD-Drive>
    <Name>CD2</Name>
   </CD-DVD-Drive>
  </Disconnect-Device>
  <PowerOn-Flag>
   <Network-Adapter>
    <Name>VM Network</Name>
    <PowerOn>true</PowerOn>
   </Network-Adapter>
   <Floppy-Drive>
    <Name>Floppy1</Name>
    <PowerOn>false</PowerOn>
   </Floppy-Drive>
   <CD-DVD-Drive>
    <Name>CD 1</Name>
    <PowerOn>false</PowerOn>
   </CD-DVD-Drive>
  </PowerOn-Flag>
  <Shares>
   <CPU></CPU>
   <Memory></Memory>
  </Shares>
 </Reconfigure-Virtual-Machine>

=head1 EXAMPLES

Add a virtual disk with <Name> 'HardDisk 1', <Size> '10' MB and
<Persistent-Mode> 'persistent'

 vmreconfig.pl --url https://<host>:<port>/sdk/vimService
               --username myuser --password mypassword
               --filename vmreconfig.xml --schema vmreconfig.xsd

=head1 SUPPORTED PLATFORMS

All operations work with VMware VirtualCenter 2.0.1 or later.

All operations work with VMware ESX 3.0.1 or later.

