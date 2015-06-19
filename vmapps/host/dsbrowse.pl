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

$Util::script_version = "1.0_vEMan02";

my %field_values = (
   'name' => 'name',
   'location' => 'location',
   'filetype' => 'filetype',
   'capacity' => 'capacity',
   'freespace' => 'freespace',
   'hosts' => 'hosts' ,
   'vms' => 'vms',
   'templates' => 'templates',
);

my %opts = (
   name => {
      type => "=s",
      help => "Name of the Datastore",
      required => 0,
   },
   filetype => {
      type => "=s",
      help => "Type of file system volume",
      required => 0,
   },
   capacity => {
      type => "=i",
      help => "Maximum capacity of the datastore, in GB",
      required => 0,
   },
   freespace => {
      type => "=i",
      help => "Available space of the datastore, in GB",
      required => 0,
   },
   out => {
      type => "=s",
      help => "The file name for storing the script's output",
      required => 0,
   },
   attributes => {
      type => "=s",
      help => "List of attributes to be displayed",
      required => 0,
   },
   'storagesum'=>{
      type => ":s",
      help => "Produces a short output for the storages only",
      required => 0,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate(\&validate);

my @valid_properties;
use constant STORAGE_MULTIPLIER => 1073741824;  # 1024*1024*1024 (to convert to GB)

Util::connect();

my $datastores = find_datastores();
if (@$datastores) {
   browse_datastore($datastores);
}
else {
   Util::trace(0, "\nNo Datastores Found\n");
}


Util::disconnect();

sub browse_datastore {
   my ($datastores) = @_;
   foreach my $datastore (@$datastores) {
      display_summary($datastore);
      if (not defined (Opts::get_option('storagesum'))) {
	foreach (@valid_properties) {
       	  	if ($_ eq 'hosts') {
       	     	display_hosts($datastore);
         	}
         	if ($_ eq 'vms') {
            		display_vms($datastore);
         	}
         	if ($_ eq 'templates') {
            		display_templates($datastore);
         	}
      	}
      	display_folder_structure($datastore);
     }
    }
   Util::trace(0, "\n");
}

sub print_browse {
   my %args = @_;
   my $datastore_mor = $args{mor};
   my $path = $args{filePath};
   my $level = $args{level};
   my $browse_task;
   eval {
      $browse_task = $datastore_mor->SearchDatastoreSubFolders(datastorePath=>$path);
   };
   if ($@) {
      Util::trace(0, "\nError occured : ");
      if (ref($@) eq 'SoapFault') {
         if (ref($@->detail) eq 'FileNotFound') {
            Util::trace(0, "The file or folder specified by "
                         . "datastorePath is not found");
         }
         elsif (ref($@->detail) eq 'InvalidDatastore') {
            Util::trace(0, "Operation cannot be performed on the target datastores");
         }
         else {
            Util::trace(0, "\n" . $@ . "\n");
         }
      }
      else {
         Util::trace(0, "\n" . $@ . "\n");
      }
   }
   
   foreach(@$browse_task) {
      print_log("\n Folder Path: '" . $_->folderPath . "'");
      if(defined $_->file) {
         print_log("\n Files present \n");
         foreach my $x (@{$_->file}) {
            print_log("  " . $x->path . "\n");
         }
      }
   }
}


sub find_datastores {
   my $datastore_name = Opts::get_option('name');
   my $filetype = Opts::get_option('filetype');
   my $capacity = Opts::get_option('capacity');
   my $freespace = Opts::get_option('freespace');
   my $dc = Vim::find_entity_views(view_type => 'Datacenter');
   my @ds_array = ();

   foreach(@$dc) {
      if(defined $_->datastore) {
         @ds_array = (@ds_array, @{$_->datastore});
      }
   }
   my $datastores = Vim::get_views(mo_ref_array => \@ds_array);
   @ds_array = ();
   foreach(@$datastores) {
   my $match_flag = 1;
      if($_->summary->accessible) {
         if($match_flag && $datastore_name) {
            if($_->summary->name eq $datastore_name) {
               # Do Nothing
            }
            else {
               $match_flag = 0;
            }
         }
         
         if($match_flag && $filetype) {
            if($_->summary->type eq $filetype) {
               # Do Nothing
            }
            else {
               $match_flag = 0;
            }
         }
         
         if($match_flag && $capacity) {
            if( (($_->summary->capacity)/STORAGE_MULTIPLIER) >= $capacity) {
               # Do Nothing
            }
            else {
               $match_flag = 0;
            }
         }
         
         if($match_flag && $freespace) {
            if((($_->summary->freeSpace)/STORAGE_MULTIPLIER) >= $freespace) {
               # Do Nothing
            }
            else {
               $match_flag = 0;
            }
         }
         if($match_flag) {
            @ds_array = (@ds_array, $_);
         }
      }
   }

   return \@ds_array;
}


sub display_summary {
  my ($datastore) = @_;
  if (not defined (Opts::get_option('storagesum'))){
  	if($datastore->summary->accessible) {
      		print_log("\n\nInformation about datastore : '"
              	. $datastore->summary->name . "'");
      		print_log("\n---------------------------");
      		print_log("\nSummary");
      		foreach (@valid_properties) { 
			if ($_ eq 'name') {
            			print_log("\n Name             : " . $datastore->summary->name);
         		}
         		if ($_ eq 'location') {
            			print_log("\n Location         : " . $datastore->info->url);
         		}
         		if ($_ eq 'filetype') {
            			print_log("\n File system      : " . $datastore->summary->type);
         		}
         		if ($_ eq 'capacity') {
            			print_log("\n Maximum Capacity : "
                   		. (($datastore->summary->capacity)/STORAGE_MULTIPLIER) . " GB");
         		}
         		if ($_ eq 'freespace') {
            			print_log("\n Available space  : "
                   		. (($datastore->summary->freeSpace)/STORAGE_MULTIPLIER) . " GB");
         		}
      		}
   	}
   	else {
      		Util::trace(0, "\nDatastore summary not accessible\n");
  	}
  }
  else {
	my $CapaRounded = sprintf("%0.0f GB", $datastore->summary->capacity/STORAGE_MULTIPLIER);
	my $FreeRounded = sprintf("%0.0f GB", $datastore->summary->freeSpace/STORAGE_MULTIPLIER);
     	print_log($datastore->summary->name . " (Type: "
			.  $datastore->summary->type . ", Capacity/Free: " 
			. $CapaRounded . "/"
			. $FreeRounded . ")\n");
  }
}


sub display_hosts {
   my ($datastore) = @_;
   my @host_array = ();
   if(defined $datastore->host) {
      print_log("\n\nHosts associated with this datastore.");
      foreach(@{$datastore->host}) {
         @host_array = (@host_array, $_->key);
         my $host_views = Vim::get_views(mo_ref_array => \@host_array);
         foreach(@$host_views) {
            print_log("\n " . $_->name);
         }
      }
   }
   else {
      print_log("\n None");
   }
}

sub display_vms {
   my ($datastore) = @_;
   my $exist_flag = 0;
   print_log("\n\nVirtual machines on this datastore.");
   my $vm_views = Vim::get_views(mo_ref_array => $datastore->vm);
   foreach(@$vm_views) {
      if(!($_->config->template)) {
         $exist_flag = 1;
         print_log("\n " . $_->name);
      }
   }
   if($exist_flag eq 0) {
      print_log("\n None");
   }
}

sub display_templates {
   my ($datastore) = @_;
   my $exist_flag = 0;
   print_log("\n\nTemplates on this datastore.");
   my $vm_views = Vim::get_views(mo_ref_array => $datastore->vm);
   foreach(@$vm_views) {
      if(($_->config->template)) {
         $exist_flag = 1;
         print_log("\n " . $_->name);
      }
   }
   if($exist_flag eq 0) {
      print_log("\n None");
   }
}

sub display_folder_structure {
   my ($datastore) = @_;
   print_log("\n\nDatastore Folder Structure.");
   my $host_data_browser = Vim::get_view(mo_ref => $datastore->browser);
   print_browse(mor => $host_data_browser,
                filePath => '[' . $datastore->summary->name . ']',
                level => 0);
}


sub print_log {
   my ($data) = @_;
   if (defined (Opts::get_option('out'))) {
      print OUTFILE  "$data";
   }
   else {
   	Util::trace(0, "$data");
   }
}



# Create hash for filter criteria
# ================================
sub create_hash {
   my ($name, $filetype, $capacity, $freespace) = @_;
   my %filterHash;
   if ($name) {
      $filterHash{'name'} = $name;
   }
   if ($filetype) {
      $filterHash{'filetype'} = $filetype;
   }
   if ($capacity) {
      $filterHash{'capacity'} = $capacity;
   }
   if ($freespace) {
      $filterHash{'freespace'} = $freespace;
   }
   return %filterHash;
}


#Sub routine to check wheather value is Numeric
sub isNumber {
   my ($val) = @_;
   my $result = ($val =~ /^-?(?:\d+(?:\.\d*)?|\.\d+)$/);
   return $result;
}

# validate the host's fields to be displayed
# ===========================================
sub validate {
   my $valid = 1;
   my @properties_to_add;
   my $length =0;
   if (Opts::option_is_set('attributes')) {
      my @filter_Array = split (',', Opts::get_option('attributes'));
      foreach (@filter_Array) {
         if ($field_values{ $_ }) {
            $properties_to_add[$length] = $field_values{$_};
            $length++;
         }
         else {
            Util::trace(0, "\nInvalid attribute specified: " . $_ );
         }
      }
      @valid_properties = sort  @properties_to_add;
      if (!@valid_properties) {
         $valid = 0;
      }
   }
   else {
      @valid_properties = ("name",
                           "location",
                           "filetype",
                           "capacity",
                           "freespace",
                           "hosts",
                           "vms",
                           "templates");
   }
   
   if (Opts::option_is_set('capacity')) {
      if(isNumber (Opts::get_option('capacity'))) {
         if(Opts::get_option('capacity') <= 0) {
            Util::trace(0, "\nCapacity must be a poistive non zero number \n");
            $valid = 0;
         }
      }
   }
   
   if (Opts::option_is_set('freespace')) {
      if(isNumber (Opts::get_option('freespace'))) {
         if(Opts::get_option('freespace') <= 0) {
            Util::trace(0, "\nFreespace must be a poistive non zero number \n");
            $valid = 0;
         }
      }
   }
   
   if (Opts::option_is_set('out')) {
      my $filename = Opts::get_option('out');
      if ((length($filename) == 0)) {
         Util::trace(0, "\n'$filename' Not Valid:\n$@\n");
         $valid = 0;
      }
      else {
         open(OUTFILE, ">$filename");
         Util::trace(0, "\nStoring output into file . . . \n");
         if ((length($filename) == 0) ||
            !(-e $filename && -r $filename && -T $filename)) {
            Util::trace(0, "\n'$filename' Not Valid:\n$@\n");
            $valid = 0;
         }
      }
   }
   
   return $valid;
}

__END__

## bug 217605

=head1 NAME

dsbrowse.pl - Browse datastores and list their attributes.

=head1 SYNOPSIS

 dsbrowse.pl [options]

=head1 DESCRIPTION

This VI Perl command-line utility provides an interface to browse
datastores and list attributes of datastores. It can also list
datastores by particular attribute like name, size. This script
also provide functionality browse through the files in a datastore.
If no option is specified, then the information of all the datastores
found will be displayed.

=head1 OPTIONS

=over

=item B<name>

Optional. Name of the datastore.

=item B<filetype>

Optional. Type of file system volume.

=item B<capacity>

Optional. Capacity of the datastore, in GB. Datastore will be retrieved
if the actual capacity is greater than or equal to the <capacity> option.

=item B<freespace>

Optional. Available space on this datastore, in GB. Datastore will be retrieved
if the actual available space is greater than or equal to the <freespace> option.

=item B<out>

Optional. The file name for storing the script's output.

=item B<attributes>

Optional. List containing the various attributes of the
datastore. (refer to the ATTRIBUTE PARAMETERS section)

=back

=head2 ATTRIBUTE PARAMETERS

=over

=item B<name>

Optional. Name of the datastore.

=item B<location>

Optional. The unique locator for the datastore.

=item B<filetype>

Optional. Type of file system volume.

=item B<capacity>

Optional. Maximum capacity of the datastore, in GB.

=item B<freespace>

Optional. Available space on this datastore, in GB.

=item B<hosts>

Optional. Hosts attached to this datastore.

=item B<vms>

Optional. Virtual machines stored on this datastore.

=item B<templates>

Optional. Templates stored on this datastore.

=back

=head1 EXAMPLES

List all the datastores which have file type 'VMFS'.

 dsbrowse.pl --url https://<host>:<port>/sdk/vimService
                --username myuser --password mypassword
                --filetype VMFS

List name, location, capacity, number of hosts connected
and number of virtual machines for datastore 'Data123'.

 dsbrowse.pl --url https://<host>:<port>/sdk/vimService
                --username myuser --password mypassword
                --name Data123 --attributes name,location,capacity,
                  hosts,vms

=head1 SUPPORTED PLATFORMS

All operations work with VMware VirtualCenter 2.0.1 or later.

All operations work with VMware ESX 3.0.1 or later.

