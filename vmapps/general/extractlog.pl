#!/usr/bin/perl -w
#
# Copyright (c) 2007 VMware, Inc.  All rights reserved.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../";

use VMware::VIRuntime;
use VMware::VIExt;
use XML::LibXML;
use AppUtil::VMUtil;
use AppUtil::XMLInputUtil;

sub do_browse;
sub get_logfile;
sub do_put;

$Util::script_version = "1.0";

my %opts = (
   'vmname' => {
      type => "=s",
      help => "Name of the virtual machine",
      required => 1,
   },
   'localpath' => {
      type => "=s",
      help => "localpath",
      required => 1,
   },
   'datacenter'  => {
      type     => "=s",
      variable => "datacenter",
      help     => "Name of the datacenter",
   },
   'pool'  => {
      type     => "=s",
      variable => "pool",
      help     => "Name of the resource pool",
   },
   'host' => {
      type     => "=s",
      variable => "host",
      help     => "Name of the host",
   },
);

sub extract_log;

Opts::add_options(%opts);
Opts::parse();
Opts::validate();

Util::connect();
extract_log();
Util::disconnect();

sub extract_log() {
   # bug 392274
   my %filter_hash;
   $filter_hash{'name'} = Opts::get_option ('vmname');
   my $vmname = Opts::get_option('vmname');

   my $vm_views = VMUtils::get_vms ('VirtualMachine',
                                    undef,
                                    Opts::get_option ('datacenter'),
                                    undef,
                                    Opts::get_option ('pool'),
                                    Opts::get_option ('host'),
                                    %filter_hash);
   if(!defined $vm_views) {
      return;
   }
   if (@$vm_views > 1) {
      print("Virtual Machine " . Opts::get_option('vmname') . " not unique.\n");
      return;
   }
   my $vm = shift (@$vm_views);
   my $logdirectory = $vm->config->files->logDirectory;
   my $remotepath = get_remote_path($logdirectory);
   my $dsname = get_datastore_name($logdirectory);

   # bug 392259
   my $sc = Vim::get_service_content();
   my $dcname = "ha-datacenter";
   if($sc->about->apiType eq "VirtualCenter") {
      $dcname = get_datacenter_name($vm);   
   }

   $remotepath = $remotepath . "/vmware.log";
   get_log($remotepath,$dsname,$dcname); 
}

sub get_log() {
   my ($remotepath,$dsname,$dcname) = @_;
   print "\nExtracting vmware.log file \n";
   my $resp = VIExt::http_get_file("folder",
                                   $remotepath,
                                   $dsname,
                                   $dcname,
                                   Opts::get_option('localpath'));
   check_response($resp);
}

sub get_remote_path() {
   my ($localpath) = @_;
   my $ind = index($localpath, "]");
   my $remotepath = substr($localpath,$ind+1);
   return $remotepath;
}

sub get_datastore_name() {
   my ($localpath) = @_;
   my $ind = index($localpath, "]");
   my $dsname = substr($localpath,1,$ind-1);
   return $dsname;
}

# bug 392259
sub get_datacenter_name() {
   my ($vmmor) = @_;
   my $parent = $vmmor->parent;
   my $parent_view = Vim::get_view(mo_ref => $parent);
   while(!($parent_view->{mo_ref}->type eq 'Datacenter')) {
      $parent = $parent_view->parent;
      $parent_view = Vim::get_view(mo_ref => $parent);
   }
   my $dc_name = $parent_view->name;
   $parent = $parent_view->parent;
   $parent_view = Vim::get_view(mo_ref => $parent);
   while($parent_view->name ne 'Datacenters') {
      $dc_name = $parent_view->name . "/" . $dc_name; 
      $parent = $parent_view->parent;
      $parent_view = Vim::get_view(mo_ref => $parent);
   }
   return $dc_name;
}

sub check_response {
   my ($resp) = @_;
   if ($resp) {
      if (!$resp->is_success) {
         my $ind = index($resp->status_line,'404 Not Found');
         if($ind != -1) {
            print "\nvmware.log not found.\n";
         }
      }
      else {
         print "\nGet operation completed successfully\n";
      }
   }
   else {
      print STDERR "\nGET unsuccessful : failed to get response\n";
   }
}

__END__

## bug 217605

=head1 NAME

extractlog.pl - Allows extract of the vmware.log for any virtual machine.

=head1 SYNOPSIS

 extractlog.pl [options]

=head1 DESCRIPTION

This VI Perl command-line utility provides an interface to extract the vmware.log
for any virtual machine.

=head1 OPTIONS

=over

=item B<vmname>

Name of the Virtual Machine.

=item B<localpath>

Local path to save the extracted log.

=item B<datacenter>

Optional. Specify the name of the datacenter inside which the virtual machine is present.

=item B<pool>

Optional. Specify the name of the resource pool inside which the virtual machine is present.

=item B<host>

Optional. Specify the name of the ESX server inside which the virtual machine is present.

=back

=head1 EXAMPLES

To extract the vmware.log of Virtual Machine "ABC" at location "C:/tmp.txt":

   extractlog.pl --url <https://<IP Address>:<Port>/sdk/vimService>
                 --username myuser --password mypassword --localpath "C:/tmp.txt"
                 --vmname ABC

To extract the vmware.log of Virtual Machine "ABC" under specific datacenter at location "C:/tmp.txt":

   extractlog.pl --url <https://<IP Address>:<Port>/sdk/vimService>
                 --username myuser --password mypassword --localpath "C:/tmp.txt"
                 --vmname ABC --datacenter <datacenter name>

To extract the vmware.log of Virtual Machine "ABC" under specific host at location "C:/tmp.txt":

   extractlog.pl --url <https://<IP Address>:<Port>/sdk/vimService>
                 --username myuser --password mypassword --localpath "C:/tmp.txt"
                 --vmname ABC --host <ESX Server>

To extract the vmware.log of Virtual Machine "ABC" under specific resourcepool at location "C:/tmp.txt":

   extractlog.pl --url <https://<IP Address>:<Port>/sdk/vimService>
                 --username myuser --password mypassword --localpath "C:/tmp.txt"
                 --vmname ABC --pool <resource pool name>

=head1 SUPPORTED PLATFORMS

All operations work with VMware VirtualCenter 2.5, 4.0.

All operations work with VMware ESX 3.5, 4.0.
