#!/usr/bin/perl -w
#
# Copyright (c) 2007 VMware, Inc.  All rights reserved.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../";

use VMware::VIRuntime;
use XML::LibXML;
use AppUtil::VMUtil;
use AppUtil::XMLInputUtil;

$Util::script_version = "1.0";

sub display;
sub customize;
sub validate;
sub check_missing_value;

# bug 222613
my %operations = (
   "display", "",
   "customize", "" ,
);

my %opts = (
   'vmname' => {
      type => "=s",
      help => "The name of the virtual machine",
      required => 1,
   },
   'operation' => {
      type => "=s",
      help => "Operation to be performed on the Guest: display, customize",
      required => 1,
   },
   'filename' => {
      type => "=s",
      help => "The xml configuration filename",
      required => 0,
      default => "../sampledata/guestinfo.xml",
   },
   'schema' => {
      type => "=s",
      help => "The location of the schema file",
      required => 0,
      default => "../schema/guestinfo.xsd",
   },
);


Opts::add_options(%opts);
Opts::parse();
Opts::validate(\&validate);

my $op = Opts::get_option('operation');
my $vmname = Opts::get_option('vmname');

# connect to the server
Util::connect();
if ($op eq "display") {
   display();
}
if ($op eq "customize") {
   customize();
}
Util::disconnect();

sub display() {

   my %toolsStatus = (
   'toolsOk' => 'VMware Tools is running and the version is current.',
   'toolsNotRunning' => 'VMware Tools is not running',
   'toolsNotInstalled'  =>
   'VMware Tools has never been installed or has not run in the virtual machine',
   'toolsOld' => 'VMware Tools is running, but the version is not current',
   );
   my $vm_views;

   $vm_views = Vim::find_entity_views(view_type => 'VirtualMachine',
                            filter => {"config.name" => $vmname});
   if(defined @$vm_views) {
      foreach(@$vm_views) {
      
         my $mor_host = $_->runtime->host;
         my $hostname = Vim::get_view(mo_ref => $mor_host)->name;
         
         $vmname = $_->name;
         my $vm_view = $_;
         if (($_->runtime->powerState->val eq 'poweredOff')
              || ($_->runtime->powerState->val eq 'suspended')){
            Util::trace(0, "For display, Virtual Machine '$vmname' under host $hostname"
                           ." should be powered ON\n");
         }
         elsif (!defined $_->guest) {
            Util::trace(0, "Guest is not defined for $vmname\n");
         }
         else {
            Util::trace(0,"\n\nGuest Info for the Virtual Machine '$vmname' "
                           ."under host $hostname\n\n");
            if (defined $vm_view->guest->guestFamily) {
               Util::trace(0, $vm_view->name ." guestFamily: "
                              . $vm_view->guest->guestFamily . "\n");
            }
            else {
               Util::trace(0, $vm_view->name ." guestFamily: Not Known\n");
            }
            if (defined $vm_view->guest->guestFullName) {
               Util::trace(0, $vm_view->name . " guestFullName: "
                              . $vm_view->guest->guestFullName. "\n");
            }
            else {
               Util::trace(0, $vm_view->name ." guestFullName: Not Known\n");
            }
            if (defined $vm_view->guest->guestId) {
               Util::trace(0, $vm_view->name . " guestId: "
                              . $vm_view->guest->guestId . "\n");
            }
            else {
               Util::trace(0, $vm_view->name ." guestId: Not Known\n");
            }
            Util::trace(0, $vm_view->name . " guestState: "
                           . $vm_view->guest->guestState . "\n");

            if (defined $vm_view->guest->hostName) {
               Util::trace(0, $vm_view->name . " hostName: "
                              . $vm_view->guest->hostName . "\n");
            }
            else {
               Util::trace(0, $vm_view->name ." hostName: Not Known\n");
            }
            if (defined $vm_view->guest->ipAddress) {
               Util::trace(0, $vm_view->name . " ipAddress: "
                              . $vm_view->guest->ipAddress . "\n");
            }
            else {
               Util::trace(0, $vm_view->name ." ipAddress: Not Known\n");
            }
            if (defined $vm_view->guest->toolsStatus) {
               Util::trace(0, $vm_view->name . " toolsStatus: "
                               . $toolsStatus{$vm_view->guest->toolsStatus->val}."\n");
            }
            else {
               Util::trace(0, $vm_view->name ." toolsStatus: Not Known\n");
            }
            if (defined $vm_view->guest->toolsVersion) {
               Util::trace(0, $vm_view->name . " toolsVersion: "
                              . $vm_view->guest->toolsVersion . "\n");
            }
            else {
               Util::trace(0, $vm_view->name ." toolsVersion: Not Known\n");
            }
            if (defined $vm_view->guest->screen) {
               Util::trace(0, $vm_view->name . " Screen - Height: "
                             . $vm_view->guest->screen->height . "\n");
               Util::trace(0, $vm_view->name . " Screen - Width: "
                              . $vm_view->guest->screen->width . "\n");
            }
            else {
               Util::trace(0, $vm_view->name ." guest - Screen: Not Known\n");
            }
            if (defined $vm_view->guest->disk) {
               my $disk_len = @{$vm_view->guest->disk};
               my $cnt = 0;
               while ($cnt < $disk_len) {
                  if (defined $vm_view->guest->disk->[$cnt]->capacity) {
                     Util::trace(0, $vm_view->name . " Disk[". $cnt ."]: Capacity "
                                    . $vm_view->guest->disk->[$cnt]->capacity . "\n");
                  }
                  else {
                     Util::trace(0, $vm_view->name ." Disk[". $cnt ."]: "
                                    ."Capacity: Not Known\n");
                  }
                  if (defined $vm_view->guest->disk->[$cnt]->diskPath) {
                     Util::trace(0, $vm_view->name . " Disk[". $cnt ."]: Path : "
                                    . $vm_view->guest->disk->[$cnt]->diskPath . "\n");
                  }
                  else {
                     Util::trace(0, $vm_view->name ." Disk Path[". $cnt ."]: "
                                    ."Not Known\n");
                  }
                  if (defined $vm_view->guest->disk->[$cnt]->freeSpace) {
                     Util::trace(0, $vm_view->name . " Disk[". $cnt ."]: freespace : "
                                    . $vm_view->guest->disk->[$cnt]->freeSpace . "\n");
                  }
                  else {
                     Util::trace(0, $vm_view->name ." Disk[".$cnt."]freespace: "
                                    ."Not Known\n");
                  }
                  $cnt++;
               }
            }
            else {
               Util::trace(0, $vm_view->name ." guest - Disk: Not Known\n");
            }
            if (defined $vm_view->guest->net) {
               my $net_len = @{$vm_view->guest->net};
               my $cnt = 0;
               while ($cnt < $net_len) {
                  Util::trace(0, $vm_view->name . " net[".$cnt."] - connected : "
                                 . $vm_view->guest->net->[$cnt]->connected . "\n");
                  Util::trace(0, $vm_view->name . " net[".$cnt."] - deviceConfigId : "
                                 . $vm_view->guest->net->[$cnt]->deviceConfigId . "\n");
                  if (defined $vm_view->guest->net->[$cnt]->macAddress) {
                     Util::trace(0, $vm_view->name . " net[".$cnt."] - macAddress : "
                                    . $vm_view->guest->net->[$cnt]->macAddress . "\n");
                  }
                  else {
                     Util::trace(0, $vm_view->name ." net[".$cnt."] - macAddress: "
                                    ."Not Known\n");
                  }
                  if (defined $vm_view->guest->net->[$cnt]->network) {
                     Util::trace(0, $vm_view->name . " net[".$cnt."] - network : "
                                    . $vm_view->guest->net->[$cnt]->network . "\n");
                  }
                  else {
                     Util::trace(0, $vm_view->name ." net[".$cnt."] - network : "
                                    ."Not Known\n");
                  }
                  if (defined $vm_view->guest->net->[$cnt]->ipAddress) {
                     my $ip_len = @{$vm_view->guest->net->[$cnt]->ipAddress};
                     my $cnt_ip = 0;
                     while ($cnt_ip < $ip_len) {
                        Util::trace(0, $vm_view->name . " net[".$cnt."] - ipAddress : "
                                     .$vm_view->guest->net->[$cnt]->ipAddress->[$cnt_ip]
                                     ."\n");
                        $cnt_ip++;
                     }
                  }
                  else {
                     Util::trace(0, $vm_view->name ." net[".$cnt."] - ipAddress : "
                                    ."Not Known\n");
                  }
                  $cnt++;
               }
            }
            else {
               Util::trace(0, $vm_view->name ." guest - Net : Not Known\n");
            }
         }
      }
   }
   else {
      Util::trace(0, "No Virtual Machine Found With Name '$vmname'\n");
   }
}


sub customize() {
   my $vm_views = Vim::find_entity_views(view_type => 'VirtualMachine',
                                       filter => {"config.name" => $vmname});
   if(defined @$vm_views) {
      foreach(@$vm_views) {
         my $mor_host = $_->runtime->host;
         my $hostname = Vim::get_view(mo_ref => $mor_host)->name;
         
         if ($_->runtime->powerState->val eq 'poweredOn'){
            Util::trace(0, "\nFor customize, VM '$vmname' should be powered off"
                         ." under host $hostname\n");
         }
         else {
            my $customization_spec = VMUtils::get_customization_spec
                                              (Opts::get_option('filename'));
            eval {
               $_->CustomizeVM(spec => $customization_spec);
               Util::trace(0, "\nCustomization Successful for the VM ". $_->name
                              . " under host $hostname\n");
            };
            if ($@) {
               if (ref($@) eq 'SoapFault') {
                  if (ref($@->detail) eq 'CustomizationFault') {
                     Util::trace(0, "\n Cannot Perfrom this operation"
                                    ." System Error" . "\n");
                  }
                  elsif (ref($@->detail) eq 'NotSupported') {
                     Util::trace(0, "\nThe operation is not supported"
                                    ." on the object" . "\n");
                  }
                  elsif (ref($@->detail) eq 'NoDisksToCustomize') {
                     Util::trace(0, "\nThe virtual machine has no virtual disks that"
                                  . " are suitable for customization or no guest"
                                  . " is present on given virtual machine" . "\n");
                  }
                  elsif (ref($@->detail) eq 'HostNotConnected') {
                     Util::trace(0, "\nUnable to communicate with the remote host, "
                                    ."since it is disconnected" . "\n");
                  }
                  elsif (ref($@->detail) eq 'InvalidState') {
                     Util::trace(0, "\nThe operation is not allowed in the"
                                    ." current state" . "\n");
                  }
                  elsif (ref($@->detail) eq 'InvalidPowerState') {
                     Util::trace(0, "\nThe attempted operation cannot be"
                                    ." performed in the current state" . "\n");
                  }
                  elsif (ref($@->detail) eq 'UncustomizableGuest') {
                     Util::trace(0, "\nCustomization is not supported for"
                                    ." the guest operating system" . "\n");
                  }
                  else {
                     Util::trace(0, "\n". $@ . "\n\n");
                  }
               }
               else {
                  Util::trace(0, "\n". $@ . "\n\n");
               }
            }
         }
      }
   }
   else {
      Util::trace(0, "No Virtual Machine Found With Name '$vmname'\n");
   }
}

sub validate {
   my $operation = Opts::get_option('operation');
   my $valid = 1;
     # bug 222613
     if($operation) {
      if (!exists($operations{$operation})) {
         Util::trace(0, "Invalid operation: '$operation'\n");
         Util::trace(0, " List of valid operations:\n");
         map {print "  $_\n"; } sort keys %operations;
         $valid = 0;
      }
      if ($operation eq 'customize') {
         $valid = XMLValidation::validate_format(Opts::get_option('filename'));
         if ($valid == 1) {
            $valid = XMLValidation::validate_schema(Opts::get_option('filename'),
                                                    Opts::get_option('schema'));
            if ($valid == 1) {
               $valid = check_missing_value();
            }
         }
      }
   }
   return $valid;
}


# check missing values of mandatory fields
# ========================================
sub check_missing_value {
   my $valid= 1;
   my $filename = Opts::get_option('filename');
   my $parser = XML::LibXML->new();
   my $tree = $parser->parse_file($filename);
   my $root = $tree->getDocumentElement;
   my @cust_spec = $root->findnodes('Customization-Spec');
   my $total = @cust_spec;
   if (!$cust_spec[0]->findvalue('Auto-Logon')) {
      Util::trace(0,"\nERROR in '$filename':\n autologon value missing ");
      $valid = 0;
   }
   if (!$cust_spec[0]->findvalue('Virtual-Machine-Name')) {
      Util::trace(0,"\nERROR in '$filename':\n Virtual Machine Name value missing ");
      $valid = 0;
   }
   if (!$cust_spec[0]->findvalue('Timezone')) {
      Util::trace(0,"\nERROR in '$filename':\n timezone value missing ");
      $valid = 0;
   }
   if (!$cust_spec[0]->findvalue('Domain')) {
      Util::trace(0,"\nERROR in '$filename':\n domain value missing ");
      $valid = 0;
   }
   if (!$cust_spec[0]->findvalue('Domain-User-Name')) {
      Util::trace(0,"\nERROR in '$filename':\n domain user name value missing ");
      $valid = 0;
   }
   if (!$cust_spec[0]->findvalue('Domain-User-Password')) {
      Util::trace(0,"\nERROR in '$filename':\n domain user password value missing ");
      $valid = 0;
   }
   if (!$cust_spec[0]->findvalue('Full-Name')) {
      Util::trace(0,"\nERROR in '$filename':\n fullname value missing ");
      $valid = 0;
   }
   if (!$cust_spec[0]->findvalue('Organization-Name')) {
      Util::trace(0,"\nERROR in '$filename':\n orgname value missing ");
      $valid = 0;
   }
   return $valid;
}

__END__

## bug 217605

=head1 NAME

guestinfo.pl - Lists  the attributes of the guest OS on a virtual machine.

=head1 SYNOPSIS

 guestinfo.pl --operation <display|customize> [options]

=head1 DESCRIPTION

This VI Perl command-line utility provides an interface for displaying guest attributes.

=head1 OPTIONS

=over

=item B<operation>

Required. Operation to be performed. Must be
I<display> (displays the attributes of guest).

=back

=head2 DISPLAY OPTIONS

=over

=item B<vmname>

Optional. The name of the virtual machine. It will be used to select the
virtual machine. For display operation the virtual machine must be
powered on and the user must be logged in. 

=back

=head1 EXAMPLES

Displays the attributes of guest OS on virtual machines with name "VirtualABC":

   guestinfo.pl --url https://<ipaddress>:<port>/sdk/webService
            --username administrator --password mypassword
            --vmname VirtualABC --operation display


=head1 SUPPORTED PLATFORMS

All operations work with VMware VirtualCenter 2.0.1.
With versions earlier than VirtualCenter 3.0.1, a customize operation was also supported. 
This operation is no longer available. 

