#!/usr/bin/perl -w
#
# Copyright (c) 2007 VMware, Inc.  All rights reserved.

#use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../";

use VMware::VIRuntime;
use AppUtil::HostUtil;

$Util::script_version = "1.0_vEMan05";

sub create_hash;
sub get_host_info;
sub print_log;

@netlist = ();
%seen = ();

my %field_values = (
   'hostname' => 'hostname',
   'portnumber' => 'portnumber',
   'boottime' => 'boottime',
   'cpumodel' => 'cpumodel',
   'cpucores' => 'cpucores',
   'cpuspeed' => 'cpuspeed',
   'cpuusage' => 'cpuusage' ,
   'filesystem' => 'filesystem',
   'host_status' => 'host_status',
   'maintenancemode' => 'maintenancemode',
   'memorysize' => 'memorysize' ,
   'memoryusage' => 'memoryusage',
   'networkadapters' =>'networkadapters',
   'portnumber' => 'portnumber',
   'rebootrequired' => 'rebootrequired',
   'software' => 'software',
   'vmotion' => 'vmotion',
   'net' => 'net',
);

my %host_status = (
   'gray' => 'The status is unknown',
   'green' => 'The entity is OK',
   'red' => 'The entity definitely has a problem',
   'yellow' => 'The entity might have a problem',
);

my %opts = (
   'hostname' => {
      type => "=s",
      help => "Host name",
      required => 0,
   },
   'datacenter' => {
      type => "=s",
      help => "Name of the DataCentre",
      required => 0,
   },
   'folder' => {
      type => "=s",
      help => "Name of the Folder",
      required => 0,
   },
   'vmotion' => {
      type => "=i",
      help => "The flag to indicate whether or not VMotion is enabled on this host",
      required => 0,
   },
   'maintenancemode' => {
      type => "=i",
      help => "The flag to indicate whether or not the host is in maintenance mode",
      required => 0,
   },
   'fields' => {
      type => "=s",
      help => "To specify host properties for display",
      required => 0,
   },
   'fileoutput'=>{
      type => "=s",
      help => "The file name for storing the script output",
      required => 0,
   },
   'machinereadable'=>{
      type => ":s",
      help => "Produces machine readable output",
      required => 0,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate(\&validate);

my @valid_properties;
my $filename;

Util::connect();
get_host_info();
Util::disconnect();


# This subroutine first retrieve the hosts based on the user criteria like
# datacenter, folder etc. and then for each host it displays
# the host information like BootTime, cpumodel, cpuspeed, filesystem,
# memoryusage, networkadapters etc.
# =========================================================================
sub get_host_info {
   my $filename;
   my $hostname = Opts::get_option('hostname');
   my $datacenter = Opts::get_option('datacenter');
   my $folder = Opts::get_option('folder');
   my $vmotion = Opts::get_option('vmotion');
   my $maintenancemode = Opts::get_option('maintenancemode');

   my %filterHashHost = create_hash($vmotion, $maintenancemode, $hostname);

   my $host_views = HostUtils::get_hosts('HostSystem', $datacenter
                                          , $folder, %filterHashHost);

   if ($host_views) {
      if (defined (Opts::get_option('fileoutput'))) {
         $filename = Opts::get_option('fileoutput');
         my $extension = lc substr($filename, length($filename)-4, 4);
         if($extension ne '.xml') {
            $filename =$filename.'.xml';
         }
      }
      foreach (@$host_views) {
         my $status = $_->summary->overallStatus->val;
         my $host_view = $_;
         if (defined (Opts::get_option('fileoutput'))) {
            print OUTFILE "<host>\n";
         }
         else {
	    if (not defined (Opts::get_option('machinereadable'))) {
            	Util::trace(0,"\nHost Information \n\n");
	    }
         }
         foreach (@valid_properties) {
            if ($_ eq 'boottime') {
               if (defined ($host_view->runtime->bootTime)) {
                 print_log("        ".$host_view->runtime->bootTime,"BootTime","BootTime");
               }
               else {
                   print_log("        Not Known","BootTime","BootTime");
               }
            }
            elsif ($_ eq 'cpumodel') {
               if (defined ($host_view->summary->hardware)) {
                  print_log("        ".$host_view->summary->hardware->cpuModel,
                            "CpuModel","Cpu Model");
               }
               else {
                  print_log("Not Known","CpuModel","Cpu Model");
               }
            }
            elsif ($_ eq 'cpuspeed') {
               if (defined ($host_view->hardware)) {

	          my $getGHZcpu = sprintf("        "."%0.0f Mhz",$host_view->hardware->cpuInfo->hz / 1000000 * $host_view->hardware->cpuInfo->numCpuCores);
		  print_log($getGHZcpu,"CPUSpeed","Cpu Speed");
               }
               else {
                  print_log("Not Known","CPUSpeed","Cpu Speed");
               }
            }
            elsif ($_ eq 'cpuusage') {
               if (defined ($host_view->summary->quickStats->overallCpuUsage)) {
                   print_log("        ".$host_view->summary->quickStats->overallCpuUsage . " Mhz",
                             "CpuUsage","Cpu Usage");
               }
               else {
                  print_log("Not Known","CpuUsage","Cpu Usage");
               }
            }
	    elsif ($_ eq 'cpucores') {
               if (defined ($host_view->hardware->cpuInfo->numCpuCores)) {
                   print_log($host_view->hardware->cpuInfo->numCpuCores,
                             "CPUcores","Cpu Cores");
               }
               else {
                  print_log("Not Known","CPUcores","Cpu Cores");
               }
            }
            elsif ($_ eq 'filesystem') {
               my $filesys;
               my $cnt = 0;
               if (defined($host_view->config) && defined($host_view->config->fileSystemVolume)) {
                  if (defined($host_view->config->fileSystemVolume->volumeTypeList)){
                     $filesys = @{$host_view->config->fileSystemVolume->volumeTypeList};
                     my $logStmt = "";
                     while($cnt < $filesys) {
                        $logStmt = $logStmt. "".$host_view->config->
                                   fileSystemVolume->volumeTypeList->[$cnt]." ";
                        $cnt++;
                     }
                     print_log("        ".$logStmt,"FileSystem","File System");
                  }
               }
               else {
                 print_log("Not Known","FileSystem","File System");
               }
            }
            elsif ($_ eq 'hostname') {
               print_log("        ".$host_view->name,"HostName","Host Name");
            }
            elsif ($_ eq 'host_status') {
               print_log("        ".$host_status{$status},"HostStatus","Host Status");
            }
            elsif ($_ eq 'maintenancemode') {
               my $mode = $host_view->runtime->inMaintenanceMode;
               print_log($mode,"MaintenanceMode","Maintenance mode");
            }
            elsif ($_ eq 'memorysize') {
               if (defined ($host_view->summary->hardware)){
		my $phymem = ($host_view->summary->hardware->memorySize);
		sub BytesToReadableString($) {
   			my $phymemconv = shift;
			      $phymemconv >= 1048576 ? sprintf("%0.0f MB", $phymemconv/1048576)
			      : $phymemconv >= 1024 ? sprintf("%0.0f KB", $phymemconv/1024)
			      : $phymemconv . "bytes";
		}
                  print_log(BytesToReadableString($phymem),"PhysicalMemory","Physical Memory");
               }
               else {
                  print_log("Not Known","PhysicalMemory","Physical Memory");
               }
            }
            elsif ($_ eq 'memoryusage') {
               if (defined ($host_view->summary->quickStats->overallMemoryUsage)){
                  print_log($host_view->summary->quickStats->overallMemoryUsage." MB",
                  "MemoryUsage","Memory Usage");
               }
               else {
                  print_log("Not Known","MemoryUsage","Memory Usage");
               }
            }
            elsif ($_ eq 'networkadapters') {
               if (defined ($host_view->summary->hardware)){
                  print_log($host_view->summary->hardware->numNics,
                            "NetworkAdapters","Network Adapters");
               }
               else {
                  print_log("Not Known","NetworkAdapters","Network Adapters");
               }
            }
            elsif ($_ eq 'portnumber') {
               print_log("        ".$host_view->summary->config->port,"PortNumber","Port Number");
            }
            elsif ($_ eq 'rebootrequired') {
               print_log($host_view->summary->rebootRequired,"RebootRequired",
                         "Reboot Required");
            }
            elsif ($_ eq 'software') {
               if (defined ($host_view->summary->config->product)) {
                  print_log(${$host_view->summary->config->product}{'fullName'},
                              "SoftwareOnHost","Software on host");
               }
               else {
                  print_log("Not Known","SoftwareOnHost","Software on host");
               }
            }
            elsif ($_ eq 'vmotion') {
              print_log("        ".$host_view->summary->config->vmotionEnabled,
                         "VMotion","VMotion");
            }
  	    elsif (defined ($_ eq 'net')) {
	      if (defined ($host_view->config->network->portgroup)) {
 		my $prt_grp = $host_view->config->network->portgroup;
  		foreach (@$prt_grp) {
      			if (defined ($_->port)) {
      				#Util::trace(0, "\nName: " . $_->spec->name . "\n");
				my $netport = $_->spec;
         			my $prts = $_->port;
         			foreach (@$prts) {
					my $nettype = $_->type;
					#Util::trace(0, "\nTYPE: " . $nettype . "\n");
					#if ($nettype eq 'virtualMachine') {
					  my $netname = $netport->name;
					  push(@netlist,"$netname" . ",");
					  #print("\nArray:" . "@netlist" . "\n");
					  #Util::trace(0, "\nResult:" . $nettype . " , " . $netname);
					#}
         			}
      			}
      		}
      	    }
		foreach $item (@netlist) {
			$seen{$item}++;
		}
		@uniq = keys %seen;
		print_log("        " . "@uniq", 'Networks', 'Networks');
#		Util::trace(0, "Networks:     " . "@uniq" . "\n");
	      }
            else {
               Util::trace(0, "$_". Not Supported."\n");
            }
         }
         if (defined (Opts::get_option('fileoutput'))) {
            print OUTFILE  "</host>\n";
         }
      }
      if (defined (Opts::get_option('fileoutput'))) {
         print OUTFILE  "</Root>\n";
      }
   }
}

sub print_log {
   my ($propvalue, $xmlprop, $prop) = @_;
   if (defined (Opts::get_option('fileoutput'))) {
      print OUTFILE  "<".$xmlprop.">" . $propvalue
                     ."</".$xmlprop.">\n";
   }
   else {
	if (defined (Opts::get_option('machinereadable'))) {
      		$propvalue=~s/^\s+//;
		Util::trace(0,$prop."\n".$propvalue."\n");
	}
	else {
	      Util::trace(0, $prop.":\t\t ".$propvalue." \n");
	}
   }
}

# Create hash for filter criteria
# ================================
sub create_hash {
   my ($vmotion, $maintenancemode, $hostname) = @_;
   my %filterHash;
   # bug 298842, 371425
   if (defined $vmotion && $vmotion eq 1) {
      $filterHash{'summary.config.vmotionEnabled'} = 'true';
   }
   elsif(defined $vmotion && $vmotion eq 0) {
      $filterHash{'summary.config.vmotionEnabled'} = 'false';
   }
   if (defined $maintenancemode && $maintenancemode eq 1) {
      $filterHash{'runtime.inMaintenanceMode'} = 'true';
   }
   elsif(defined $maintenancemode && $maintenancemode eq 0) {
      $filterHash{'runtime.inMaintenanceMode'} = 'false';
   }

   if ( $hostname) {
      $filterHash{'name'} = $hostname;
   }
   return %filterHash;
}

# validate the host's fields to be displayed
# ===========================================
sub validate {
   my $valid = 1;
   my @properties_to_add;
   my $length =0;

   if (Opts::option_is_set('fields')) {
      my @filter_Array = split (',', Opts::get_option('fields'));
      foreach (@filter_Array) {
         if ($field_values{ $_ }) {
            $properties_to_add[$length] = $field_values{$_};
            $length++;
         }
         else {
            Util::trace(0, "\nInvalid property specified: " . $_ );
         }
      }
      @valid_properties = sort  @properties_to_add;
      if (!@valid_properties) {
         $valid = 0;
      }
   }
   else {
      @valid_properties = ("hostname",
                           "portnumber",
                           "boottime",
                           "cpumodel",
                           "cpuspeed",
                           "cpuusage",
                           "filesystem",
                           "host_status",
                           "maintenancemode",
                           "memorysize",
                           "memoryusage",
                           "networkadapters",
                           "rebootrequired",
                           "software",
                           "vmotion");
   }
   if (Opts::option_is_set('fileoutput')) {
      my $filename = Opts::get_option('fileoutput');
      if ((length($filename) == 0)) {
         Util::trace(0, "\n'$filename' Not Valid:\n$@\n");
         $valid = 0;
      }
      else {
         open(OUTFILE, ">$filename");
         if ((length($filename) == 0) ||
           !(-e $filename && -r $filename && -T $filename)) {
            Util::trace(0, "\n'$filename' Not Valid:\n$@\n");
            $valid = 0;
         }
         else {
            print OUTFILE  "<Root>\n";
         }
      }
   }
   if (Opts::option_is_set('vmotion')) {
      if ((Opts::get_option('vmotion') != 0) && (Opts::get_option('vmotion') != 1)) {
         Util::trace(0, "\nMust specify vmotion parameter as either 0 or 1\n");
         $valid = 0;
      }
   }
   if (Opts::option_is_set('maintenancemode')) {
      if ((Opts::get_option('maintenancemode') !=0)
           && (Opts::get_option('maintenancemode') !=1)) {
         Util::trace(0, "\nMust specify maintenancemode parameter as either 0 or 1\n");
         $valid = 0;
      }
   }
   if (Opts::option_is_set('machinereadable')) {
	   $valid = 1;
	}
   return $valid;
}

__END__

## bug 217605

=head1 NAME

hostinfo.pl - Display the Processor, Network and Memory attributes of the hosts.

=head1 SYNOPSIS

 hostinfo.pl [options]

=head1 DESCRIPTION

This VI Perl command-line utility provides a query tool that
lists various hosts and attributes for a host or set of hosts.

=head1 OPTIONS

=over

=item B<datacenter>

Optional. Name of the datacenter.  When datacenter is specified, the hosts will
be searched in this specified datacenter also.

=item B<fileoutput>

Optional. An xml filename or path of an xml filename to which the output
will be written to. If fileoutput not used, the output will be displayed.

=item B<folder>

Optional. Name of a folder. When folder is specified, only hosts 
in the specified folder are listed.

=item B<maintenancemode>

Optional. Filters host based on maintenancemode. The flag to indicate whether
or not the host is in maintenance mode.

=item B<vmotion>

Optional. Filters host based on VMotion enabled or disabled. The flag to indicate
whether or not VMotion is enabled on this host.

=item B<fields>

Optional. Refer to FIELD OPTIONS for details

=back

=head2 FIELD OPTIONS

=over

=item B<hostname>

Optional. Display  hostname property.

=item B<portnumber>

Optional. Display  portnumber property, which lists the port number.

=item B<boottime>

Optional. Display  bootTime property, which displays the time when
the host was booted in dateTime format.

=item B<cpumodel>

Optional Display cpumodel  property which, It provides
the cpu model identification.

=item B<cpuspeed>

Optional. Display cpuspeed property. The product of the speed of cpu
cores and number of processors contained by a CPU package is approximately equal to
the sum of the MHz for all the individual cores on the host. This product forms the
cpuspeed.

=item B<cpuusage>

Optional. Display  cpuusage property, which specifies the
aggregated CPU usage across all cores on the host in MHz.

=item B<filesystem>

Optional. Display filesystem property, which describes the file system
volume information for the host, listing the supported file system volume types.

=item B<host_status>

Optional. Display  host_status property, which gives the overall
alarm status of the host.

=item B<maintenancemode>

Optional. Display maintenancemode propery, which indicates
whether or not the host is in maintenance mode. It is set when the host
has entered the maintenance mode.

=item B<memorysize>

Optional. Display memorysize propery, which provides the physical
memory size in bytes.

=item B<memoryusage>

Optional. Display memoryusage property, which gives the physical
memory usage on the host in MB.

=item B<networkadapters>

Optional. Display the networkadapters property, which gives the number
of network adapters.

=item B<rebootrequired>

Optional. Display the reebootrequired.propery,  which indicates whether
or not the host requires a reboot due to a configuration change.

=item B<software>

Optional. Display the software property, which gives the complete product name,
including the version information

=item B<vmotion>

Optional. Display the VMotion property, which indicates whether VMotion is
enabled or disabled for the host.

=back

=head1 EXAMPLES

List all hosts and all properties of the hosts that are part of ha datacenter.

 hostinfo.pl --username administrator --password mypassword
            --url https://<ipaddress>:<port>/sdk/webService
            --datacenter ha

List all hosts that are part of ha datacenter and
selected properties of the hosts, as specified in the fields

 hostinfo.pl --username administrator --password mypassword
            --url https://<ipaddress>:<port>/sdk/webService
            --fields hostname,portnumber,boottime,cpumodel,cpuspeed,
                 cpuusage,filesystem,host_status,maintenancemode,
                 memorysize,memoryusage,networkadapters,
                 rebootrequired,software,vmotion
            --datacenter ha

List all hosts and all the properties of the hosts.
The results are displayed in the file mentioned in fileoutput.

 hostinfo.pl --username administrator --password mypassword
            --url https://<ipaddress>:<port>/sdk/webService
            --fileoutput D:\Output\result.xml

Lists the properties of all the hosts having their maintenance mode
and vmotion property as specified in maintenancemode and vmotion respectively.

 hostinfo.pl --username administrator --password mypassword
            --url https://<ipaddress>:<port>/sdk/webService --maintenancemode 0
            --vmotion 1

Lists the properties of all the hosts part of the folder as specified in folder.

 hostinfo.pl --username administrator --password mypassword
          --url https://<ipaddress>:<port>/sdk/webService
          --folder myfolder

=head1 SUPPORTED PLATFORMS

This script works with VMware VirtualCenter 2.0 or later.

This script works with VMware ESX 3.0 or later.

