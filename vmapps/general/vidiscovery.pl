#!/usr/bin/perl -w
#
# Copyright (c) 2007 VMware, Inc.  All rights reserved.

use strict;
use warnings;
use Getopt::Long;

use FindBin;
use lib "$FindBin::Bin/../";

use VMware::VIRuntime;

$Util::script_version = "1.0";

sub discover;
sub discover_folder;

my %opts = (
   'managedentity' => {
      type => "=s",
      help => "Type of virtual items.",
      required => 1,
   },
   'entityname' => {
      type => "=s",
      help => "Name of the managed entity mentioned in the managedentity option.",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate(\&validate);

Util::connect();
discover();
Util::disconnect();

my %discovered_hosts;
my %discovered_folders;
my %discovered_vms;

sub discover() {
   my $type = Opts::get_option('managedentity');
   my $level = 0;
   if($type eq 'datacenter') {
      my $name = Opts::get_option('entityname');
      my $datacenter_views = Vim::find_entity_views (view_type => 'Datacenter',
                                                 filter => {name => $name});
      unless (@$datacenter_views) {
         Util::trace(0, "Datacenter $name not found.\n");
         return;
      }
      foreach(@$datacenter_views) {
         Util::trace(0,"\n***************Datacenter $name***************\n");
         display(name=>"DataCenter :",value=>$_->name,level=>$level);
         discover_datacenter(datacenter => $_,level=>$level+1);
      }
   }
   elsif($type eq 'folder') {
      my $name = Opts::get_option('entityname');
      my $folder_views = Vim::find_entity_views (view_type => 'Folder',
                                                 filter => {name => $name});
      unless (@$folder_views) {
         Util::trace(0, "Folder $name not found.\n");
         return;
      }
      foreach(@$folder_views) {
         Util::trace(0,"\n*******************Folder $name***************\n");
         display(name=>"Folder :",value=>$_->name,level=>$level);
         discover_folder(folder => $_,level=>$level+1);
      }
   }
   elsif($type eq 'resourcepool') {
      my $name = Opts::get_option('entityname');
      my $rp_views = Vim::find_entity_views (view_type => 'ResourcePool',
                                                 filter => {name => $name});
      unless (@$rp_views) {
         Util::trace(0, "Resource pool $name not found.\n");
         return;
      }
      foreach(@$rp_views) {
         Util::trace(0,"\n*******************Resourcepool $name**********\n");
         display(name=>"Resource Pool :",value=>$_->name,level=>$level);
         discover_resourcepool(resourcepool => $_,level=>$level+1);
      }
   }
   elsif($type eq 'host') {
      my $name = Opts::get_option('entityname');
      my $host_views = Vim::find_entity_views (view_type => 'HostSystem',
                                                 filter => {name => $name});
      unless (@$host_views) {
         Util::trace(0, "Host system $name not found.\n");
         return;
      }
      foreach(@$host_views) {
         Util::trace(0,"\n***************Host System $name***************\n");
         display(name=>"Host :",value=>$_->name,level=>$level);
         discover_host(host => $_,level=>$level+1);
      }
   }
}

sub discover_datacenter() {
   my %args = @_;
   my $datacenter = $args{datacenter};
   my $level = $args{level};
   
   my $result = get_entities(view_type => 'Folder',
                             obj => $datacenter);
   foreach (@$result) {
      my $obj_content = $_;
      my $mob = $obj_content->obj;
      my $obj = Vim::get_view(mo_ref=>$mob);
      my $pobj = Vim::get_view(mo_ref=>$obj->parent);
      if(!(($obj->name eq "host") || ($obj->name eq "vm") || 
          ($obj->name eq "Discovered Virtual Machine"))) {
         if (!exists($discovered_folders{$obj->name})) {
            display(name=>"Folder :",value=>$obj->name,level=>$level);
            discover_folder(folder => $obj,level=>$level+1);
         }
      }
   }
   
   $result = get_entities(view_type => 'HostSystem',
                             obj => $datacenter);
   foreach (@$result) {
      my $obj_content = $_;
      my $mob = $obj_content->obj;
      my $obj = Vim::get_view(mo_ref=>$mob);
      if (!exists($discovered_hosts{$obj->name})) {
         display(name=>"Host :",value=>$obj->name,level=>$level);
         discover_host(host => $obj,level=>$level+1);
      }
   }
}

sub discover_folder() {
   my %args = @_;
   my $folder = $args{folder};
   my $level = $args{level};

   my $result = get_entities(view_type => 'Folder',
                             obj => $folder);
   foreach (@$result) {
      my $obj_content = $_;
      my $mob = $obj_content->obj;
      my $obj = Vim::get_view(mo_ref=>$mob);
      if(!($obj->name eq $folder->name)) {
         display(name=>"Folder :",value=>$obj->name,level=>$level);
         discover_folder(folder => $obj,level=>$level+1);
         $discovered_folders{$obj->name} = $obj->name;
      }
   }
   
   
   $result = get_entities(view_type => 'HostSystem',
                          obj => $folder);
   foreach (@$result) {
      my $obj_content = $_;
      my $mob = $obj_content->obj;
      my $obj = Vim::get_view(mo_ref=>$mob);
      display(name=>"Host :",value=>$obj->name,level=>$level);
      discover_host(host => $obj,level=>$level+1);
      $discovered_hosts{$obj->name} = $obj->name;
   }
   
   $result = get_entities(view_type => 'ResourcePool',
                          obj => $folder);
   foreach (@$result) {
      my $obj_content = $_;
      my $mob = $obj_content->obj;
      my $obj = Vim::get_view(mo_ref=>$mob);
      if(!($obj->name eq "Resources")) {
         display(name=>"Resource Pool :",value=>$obj->name,level=>$level);
         discover_resourcepool(resourcepool => $obj,level=>$level+1);
      }
   }

   
}

sub discover_resourcepool() {
   my %args = @_;
   my $rp = $args{resourcepool};
   my $level = $args{level};
    
   my $result = get_entities(view_type => 'VirtualMachine',
                             obj => $rp);
   foreach (@$result) {
      my $obj_content = $_;
      my $mob = $obj_content->obj;
      my $obj = Vim::get_view(mo_ref=>$mob);
      display(name=>"VM :",value=>$obj->name,level=>$level);
      $discovered_vms{$obj->name} = $obj->name;
   }
}

sub discover_host() {
   my %args = @_;
   my $host = $args{host};
   my $level = $args{level};

   my $result = get_entities(view_type => 'VirtualMachine',
                             obj => $host);
   foreach (@$result) {
      my $obj_content = $_;
      my $mob = $obj_content->obj;
      my $obj = Vim::get_view(mo_ref=>$mob);
      my $pobj = Vim::get_view(mo_ref=>$obj->parent);
      display(name=>"VM :",value=>$obj->name,level=>$level);
   }
}

sub get_entities {
   my %args = @_;
   my $view_type = $args{view_type};
   my $obj = $args{obj};
   
   my $sc = Vim::get_service_content();
   my $service = Vim::get_vim_service();

   my $property_spec = PropertySpec->new(all => 0,
                                         type => $view_type->get_backing_type());
   my $property_filter_spec = $view_type->get_search_filter_spec($obj,[$property_spec]);
   my $obj_contents = $service->RetrieveProperties(_this => $sc->propertyCollector,
                                                   specSet => $property_filter_spec);
   my $result = Util::check_fault($obj_contents);
   return $result;
}

sub display {
   my %args = @_;
   my $name = $args{name};
   my $value = $args{value};
   my $level = $args{level};
   while ($level > 0) {
      Util::trace(0,"   ");
      $level = $level - 1;
   }
   Util::trace(0,$name . " " . $value . "\n");
}

sub get_search_filter_spec {
   my ($class, $moref, $property_spec) = @_;
   my $resourcePoolTraversalSpec =
      TraversalSpec->new(name => 'resourcePoolTraversalSpec',
                         type => 'ResourcePool',
                         path => 'resourcePool',
                         skip => 1,
                         selectSet => [SelectionSpec->new(name => 'resourcePoolTraversalSpec'),
                           SelectionSpec->new(name => 'resourcePoolVmTraversalSpec'),]);

   my $resourcePoolVmTraversalSpec =
      TraversalSpec->new(name => 'resourcePoolVmTraversalSpec',
                         type => 'ResourcePool',
                         path => 'vm',
                         skip => 1);

   my $computeResourceRpTraversalSpec =
      TraversalSpec->new(name => 'computeResourceRpTraversalSpec',
                type => 'ComputeResource',
                path => 'resourcePool',
                skip => 1,
                selectSet => [SelectionSpec->new(name => 'resourcePoolTraversalSpec')]);


   my $computeResourceHostTraversalSpec =
      TraversalSpec->new(name => 'computeResourceHostTraversalSpec',
                         type => 'ComputeResource',
                         path => 'host',
                         skip => 1);

   my $datacenterHostTraversalSpec =
      TraversalSpec->new(name => 'datacenterHostTraversalSpec',
                     type => 'Datacenter',
                     path => 'hostFolder',
                     skip => 1,
                     selectSet => [SelectionSpec->new(name => "folderTraversalSpec")]);

   my $datacenterVmTraversalSpec =
      TraversalSpec->new(name => 'datacenterVmTraversalSpec',
                     type => 'Datacenter',
                     path => 'vmFolder',
                     skip => 1,
                     selectSet => [SelectionSpec->new(name => "folderTraversalSpec")]);

   my $hostVmTraversalSpec =
      TraversalSpec->new(name => 'hostVmTraversalSpec',
                     type => 'HostSystem',
                     path => 'vm',
                     skip => 1,
                     selectSet => [SelectionSpec->new(name => "folderTraversalSpec")]);

   my $folderTraversalSpec =
      TraversalSpec->new(name => 'folderTraversalSpec',
                       type => 'Folder',
                       path => 'childEntity',
                       skip => 1,
                       selectSet => [SelectionSpec->new(name => 'folderTraversalSpec'),
                       SelectionSpec->new(name => 'datacenterHostTraversalSpec'),
                       SelectionSpec->new(name => 'datacenterVmTraversalSpec',),
                       SelectionSpec->new(name => 'computeResourceRpTraversalSpec'),
                       SelectionSpec->new(name => 'computeResourceHostTraversalSpec'),
                       SelectionSpec->new(name => 'hostVmTraversalSpec'),
                       SelectionSpec->new(name => 'resourcePoolVmTraversalSpec'),
                       ]);

   my $obj_spec = ObjectSpec->new(obj => $moref,
                                  skip => 1,
                                  selectSet => [$folderTraversalSpec,
                                                $datacenterVmTraversalSpec,
                                                $datacenterHostTraversalSpec,
                                                ]);

   return PropertyFilterSpec->new(propSet => $property_spec,
                                  objectSet => [$obj_spec]);
}

sub validate {
   my $valid = 1;
   if (Opts::option_is_set('managedentity')) {
      my $mtype = Opts::get_option('managedentity');
      if(!(($mtype eq 'datacenter') || ($mtype eq  'host') || ($mtype eq 'folder')
         || ($mtype eq 'resourcepool'))) {
         Util::trace(0,"Option counter type must be [datacenter | host |"
                       ." folder | resourcepool]");
         $valid = 0;
      }
   }
   return $valid;
}

__END__

## bug 217605

=head1 NAME

vidiscovery.pl - displays a hierarchy of items in a VirtualCenter server or ESX host inventory. 

=head1 SYNOPSIS

 vidiscovery.pl [options]

=head1 DESCRIPTION

This VI Perl command-line utility displays the hierarchy of
items in a VirtualCenter server or ESX host inventory such 
as datacenter, folders, resource pools and hosts with proper indentation.

=head1 OPTIONS

=over

=item B<managedentity>

Required. Type of inventory item. Valid values are datacenter, folder, resource pool and host.

=item B<entityname>

Required. Name of the inventory item for which you specified in the managedentity option.
For example, if you specify host as the entitytype, and specify a host name in the name 
option, the hierarchy of all inventory items in that particular host will be displayed.

=back

=head1 EXAMPLES

Display the hierarchy of all the items in a datacenter:

 vidiscovery.pl --url https://<host>:<port>/sdk/vimService --username myuser
              --password mypassword  --managedentity datacenter --entityname myDatacenter

Display the hierarchy of all the items in a pool:

 vidiscovery.pl --url https://<host>:<port>/sdk/vimService --username myuser
              --password mypassword  --managedentity pool --entityname myPool

=head1 SUPPORTED PLATFORMS

All operations work with VMware VirtualCenter 2.0.1 or later.

