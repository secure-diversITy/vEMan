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
sub do_get;
sub do_put;

$Util::script_version = "1.0";

# bug 222613
my %operations = (
   "get", "",
   "put", "" ,
   "browse", "" ,
);

my %opts = (
   'datacentername' => {
      type => "=s",
      help => "Name of the datacenter",
      required => 0,
   },
   'datastorename' => {
      type => "=s",
      help => "Name of the datastore",
      required => 0,
   },
   'operation' => {
      type => "=s",
      help => "Type of Operation [Get | Put | Browse]",
      required => 1,
      default => "browse",
   },
   'filetype' => {
      type => "=s",
      help => "[datastore | config | tmp]",
      required => 0,
   },
   'remotepath' => {
      type => "=s",
      help => "Remote path of vCenter or ESX server",
      required => 0,
   },
   'remotefilename' => {
      type => "=s",
      help => "Remote path of file in vCenter or ESX server",
      required => 0,
   },
   'localpath' => {
      type => "=s",
      help => "localpath",
      required => 0,
   },
   'interactive' => {
      type => "",
      help => "Interactive browsing",
      required => 0,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate(\&validate);

Util::connect();
my $operation = Opts::get_option('operation');
if($operation eq 'browse') {
   do_browse();
}
elsif($operation eq 'get') {
   do_get();
}
elsif($operation eq 'put') {
   do_put();
}
Util::disconnect();

sub do_get() {
   my $dcname = Opts::get_option('datacentername');
   my $dsname = Opts::get_option('datastorename');
   my $filetype = Opts::get_option('filetype');
   my $localpath = Opts::get_option('localpath');
   my $remotepath;
   my $mode;
   if($filetype eq 'datastore') {
      $mode = "folder";
      $remotepath = Opts::get_option('remotepath');
      print "\nRetrieving the datastore file from $remotepath\n"
   }
   elsif($filetype eq 'config') {
      $mode = "host";
      $remotepath = Opts::get_option('remotefilename');
      print "\nRetrieving the configuration file $remotepath\n"
   }
   my $resp = VIExt::http_get_file($mode,$remotepath,$dsname,$dcname,$localpath);
   # bug 460341
   check_response($resp,"Get");
}

sub do_put() {
   my $dcname = Opts::get_option('datacentername');
   my $dsname = Opts::get_option('datastorename');
   my $filetype = Opts::get_option('filetype');
   my $localpath = Opts::get_option('localpath');
   my $remotepath;
   my $mode;
   my $resp;
   if($filetype eq 'datastore') {
      $mode = "folder";
      $remotepath = Opts::get_option('remotepath');
      print "\nCopying the file $localpath to $remotepath under ".
            "datastore $dsname abd datacenter $dcname\n";
      $resp = VIExt::http_put_file($mode,$localpath,$remotepath,$dsname,$dcname);
   }
   elsif($filetype eq 'config') {
      $mode = "host";
      $remotepath = Opts::get_option('remotefilename');
      print "\nCopying the configuration file $remotepath\n";
      $resp = VIExt::http_put_file($mode,$localpath,$remotepath,$dsname,$dcname);
   }
   elsif($filetype eq 'tmp') {
      $mode = 'tmp';
      print "\nCopying the file $localpath to tmp directory\n";
      $remotepath = Opts::get_option('remotefilename');
      $resp = VIExt::http_put_tmp_file($localpath,$remotepath);
   }
   # bug 460341
   check_response($resp,"Put");
}

sub do_browse() {
   my $api_type = get_api_type();
   my $url = Opts::get_option('url');
   my $lind = index(Opts::get_option ('url'), "/sdk");
   my $base_url = substr(Opts::get_option ('url'),0,$lind);

   my $filetype = Opts::get_option('filetype');
   my @vm_files;
   if($filetype eq 'datastore') {

      my $dcname;
      if($api_type eq 'HostAgent') {
         $dcname = "ha-datacenter";
      }
      else {
         $dcname = Opts::get_option('datacentername');
      }
      my $dsname = Opts::get_option('datastorename');
      my $remotepath = Opts::get_option('remotepath');

      my $valid = 1;
      if(defined $remotepath) {
         if(!defined $dcname) {
            print "For browse operation on vCenter, datacentername option is required if remotepath option is supplied.";
            $valid = 0;
         }
         elsif(!defined $dsname) {
            print "For browse operation, datastorename option is required if remotepath option is supplied.";
            $valid = 0;
         }
      }
      elsif(defined $dsname) {
         if(!defined $dcname) {
            print "For browse operation on vCenter, datacentername option is required if datastorename option is supplied.";
            $valid = 0;
         }
      }
      if($valid == 0) {
         return;
      }

      my $temp = "";
      my $temp_ds = $dsname;
      my $temp_dc = $dcname;
      while(1) {
         my $remote_url;
         if(defined $remotepath) {
            $remote_url = $base_url."/folder/".$remotepath."?dcPath=".$dcname."&dsName=".$dsname;
         }
         elsif(defined $dsname) {         
            $remote_url = $base_url."/folder?dcPath=".$dcname."&dsName=".$dsname;
         }
         elsif (defined $dcname){
            $remote_url = $base_url."/folder?dcPath=".$dcname;
         }
         else {
            $remote_url = $base_url."/folder";
         }

         @vm_files = get_directory_listing($remote_url);
         if(!defined $vm_files[0]) {            
            print "\nLocation " . $remote_url ."\n\n"; 
            print "No files found under this location\n";
         }
         elsif(index($vm_files[0], "##ERROR##") == -1) {
            print "\nLocation " . $remote_url ."\n\n";
            my $max_length = 0;
            if(!defined Opts::get_option('interactive')) {
               foreach (@vm_files) {
                  if($max_length < index($_, "##DELIMITER##")) {
                     $max_length = index($_, "##DELIMITER##");
                  }
               }
            }
            $max_length = $max_length + 5;
            foreach (@vm_files) {
               if(!defined Opts::get_option('interactive')) {
                  my $dindex = index($_, "##DELIMITER##");
                  my $name = substr($_,0,$dindex);
                  my $url = substr($_,$dindex+13);
                  printf '%-' . $max_length. 's', $name;
                  print $url . "\n";
               }
               else {
                  print  $_."\n";
               }
            }
            if ($#{@vm_files} == 0) {
               print "No files found under this location\n";
            }
            $temp = $remotepath;
            $temp_ds = $dsname;
            $temp_dc = $dcname;
         }
         else {
            $remotepath = $temp;
            $dsname = $temp_ds;
            $dcname = $temp_dc;
         }
         if(!defined Opts::get_option('interactive')) {
            return;
         }
         if(!defined $dcname) {
            print "\nEnter the name of the datacenter (enter -1 to exit) ";
            my $name = "";
            $name = <STDIN>;
            chomp $name;
            if($name eq '-1') {
               return;
            }
            $dcname = $name;
         }
         elsif(!defined $dsname) {
            print "\nEnter the name of the datastore (enter -1 to exit) ";
            my $name = "";
            $name = <STDIN>;
            chomp $name;
            if($name eq '-1') {
               return;
            }
            $dsname = $name;
         }
         else {
            print "\nEnter the name of the folder (enter -1 to exit) ";
            my $folder = "";
            $folder = <STDIN>;
            chomp $folder;
            if($folder eq '-1') {
               return;
            }
            if($folder eq "..") {
               if(defined $remotepath) {
                  if(index($remotepath, "/") == -1) {
                     undef $remotepath;
                  }
                  else {
                     $remotepath = substr($remotepath,0,rindex($remotepath, "/"));
                  }
               }
               else {
                  undef $dsname;
               }
            }
            else {
               if(defined $remotepath) {
                  $remotepath = $remotepath . "/" . $folder;
               }
               else {
                  $remotepath = $folder;
               }
            }
         }
      }
   }
   else {
      @vm_files = get_directory_listing($base_url."/host");
      print "Host Configuration Files\n";
      foreach (@vm_files) {
         if(defined Opts::get_option('interactive')) {
            print $_ . "\n";
         }
         else {
            my $dindex = index($_, "##DELIMITER##");
            my $name = substr($_,0,$dindex);
            print  $name."\n";
         }
      }
   }
}

sub check_response {
   my ($resp, $op) = @_;
   if ($resp) {
      if (!$resp->is_success) {
         if($resp->code eq 404) {
           print STDERR "$op operation unsuccessful: service not available.\n";
         }
         else {
           print STDERR "$op operation unsuccessful: response status code " . $resp->code . "\n";
         }
        #TFI-MOD:
	exit $resp->code
        #:TFI-MOD
      }
      else {
         print "$op operation completed successfully.\n";
         #TFI-MOD:
         exit 0
         #:TFI-MOD
      }
   }
   else {
      print STDERR "$op operation unsuccessful: failed to get response.\n";
      #TFI-MOD:
      exit 2
      #:TFI-MOD
   }
}

sub get_directory_listing {   
   my ($url) = @_;
   my @listFiles;
   my $is_interactive = Opts::get_option('interactive');
   my $service = Vim::get_vim_service();
   my $userAgent = $service->{vim_soap}->{user_agent};
   my $request = HTTP::Request->new("GET", $url);
   my $response = $userAgent->request($request);
   if ($response->is_success) {
      my $content = $response->content;
      my $count = 0;
      while ($content =~ m/(<a href=\".*\">.*<\/a>)/g) {
         my $sdk_url = Opts::get_option('url');
         $sdk_url = substr $sdk_url, 0, index($sdk_url, '/sdk');
         # bug 289353
         my $sind = index($1,'>')+1;
         my $name = substr($1,$sind);
         my $href = $sdk_url . substr($1,index($1, "href=")+6,index($1,"\">")-9);
         $href =~ s/\&amp\;/\&/g;
         my $temp = $name;
         my $lind = index($name,"</a>");
         my $delimeter = "##DELIMITER##";
         $name = substr($name,0,$lind);
         if ($count == 0) {
            if ($name =~ /^Parent/) {
               if ($temp =~ m/(<a href=\".*\">.*<\/a>)/g) {
                  $sind = index($1,'>')+1;
                  $name = substr($1,$sind);
                  $lind = index($name,"</a>");
                  $name = substr($name,0,$lind);
                  if(!defined $is_interactive) {
                     $listFiles[$count] = "." . $delimeter . $url;
                     $count = $count + 1;
                  }
                  if(!defined $is_interactive) {
                     $listFiles[$count] = ".." . $delimeter . $href;
                  }
                  else {
                     $listFiles[$count] = "..";
                  }
                  $count = $count + 1;
                  $href = $sdk_url . substr($1,index($1, "href=")+6,index($1,"\">")-9);
                  $href =~ s/\&amp\;/\&/g;
                  if(!defined $is_interactive) {
                     $name = $name . $delimeter . $href
                  }
                  $listFiles[$count] = $name;
               }
               else {
                  if (!Encode::is_utf8($name)) {
                     $name = Encode::decode_utf8($name);
                  }
                  if(!defined $is_interactive) {
                     $listFiles[$count] = "." . $delimeter . $url;
                     $count = $count + 1;
                  }
                  if($name eq "Parent Directory") {
                     if(!defined $is_interactive) {
                        $name = ".." . $delimeter . $href;
                     }
                     else {
                        $name = "..";
                     }
                     $listFiles[$count] = $name;
                  }
                  else {
                     $listFiles[$count] = $name;
                  }
               }
            }
            else {
               if (!Encode::is_utf8($name)) {
                  $name = Encode::decode_utf8($name);
               }
               if(!defined $is_interactive) {
                  $name = $name . $delimeter . $href
               }
               $listFiles[$count] = $name;
            }
            $count = $count + 1;
         }
         else {
            if ($name) {
               if (!Encode::is_utf8($name)) {
                  $name = Encode::decode_utf8($name);
               }
               if(!defined $is_interactive) {
                  $name = $name . $delimeter . $href
               }
               $listFiles[$count] = $name;
               $count = $count + 1;
            }
         }
      }
   } else {
      print "Error : " . $response->status_line . "\n";
      $listFiles[0] = "##ERROR## ". $response->status_line;
   }
   return @listFiles;
}

sub get_api_type() {
   my $si_moref = ManagedObjectReference->new(type => 'ServiceInstance',
                                              value => 'ServiceInstance');
   my $si_view = Vim::get_view(mo_ref => $si_moref);
   my $api_type = $si_view->content->about->apiType;
   return $api_type;
}

sub validate {
   my $valid = 1;
   my $operation = Opts::get_option('operation');
   my $filetype = Opts::get_option('filetype');
   my $remotepath = Opts::get_option('remotepath');
   my $remotefilename = Opts::get_option('remotefilename');
   my $localpath = Opts::get_option('localpath');
   my $datastore = Opts::get_option('datastorename');
   my $datacenter = Opts::get_option('datacentername');
   
   if($operation eq 'get') {
      if(defined $filetype) {
         if($filetype eq 'datastore') {
            if(!(defined $remotepath && defined $localpath
                 && defined $datastore && defined $datacenter)) {
               $valid = 0;
               print "\nFor performing get operation on datastore files, remotepath,".
                     " localpath, datacentername and datastorename are ".
                     " mandatory arguments.\n";
            }
         }
         elsif($filetype eq 'config') {
            if(!(defined $remotefilename && defined $localpath)) {
               $valid = 0;
               print "\nFor performing get operation on config files, remotefilename ".
                     "and localpath are mandatory arguments.\n"
            }
         }
         elsif($filetype eq 'tmp') {
            $valid = 0;
            print "\nOnly put operation is supported on tmp directory\n";
         }
         else {
            $valid = 0;
            print "\nFor performing the get operation, valid vaues for filetype ".
                  "argument are datastore and config\n";
         }
      }
      else {
         $valid = 0;
         print "\nfiletype is a mandatory option for performing the get operation\n";
      }
   }
   elsif($operation eq 'put') {
      if(defined $filetype) {
         if($filetype eq 'datastore') {
            if(!(defined $remotepath && defined $localpath
                 && defined $datastore && defined $datacenter)) {
               $valid = 0;
               print "\nFor performing put operation on datastore files remotepath,".
                     " localpath, datastorename and datacentername are the ".
                     "mandatory arguments.\n"
            }
         }
         elsif($filetype eq 'config') {
            if(!(defined $remotefilename && defined $localpath)) {
               $valid = 0;
               print "\nFor performing put operation on config files remotefilename and".
                     " localpath are the mandatory arguments.\n"
            }
         }
         elsif($filetype eq 'tmp') {
            if(!(defined $remotefilename && defined $localpath)) {
               $valid = 0;
               print "\nFor performing put operation on tmp directory remotefilename and".
                     " localpath are the mandatory arguments.\n"
            }
         }
         else {
            $valid = 0;
            print "\nFor the put operation only valid vaues for filetype ".
                  "argument are datastore, config and tmp\n";
         }
      }
      else {
         $valid = 0;
         print "\nfiletype is a mandatory option for the put operation\n";
      }
   }
   elsif($operation eq 'browse') {
      if(defined $filetype) {
         if($filetype eq 'tmp') {
            $valid = 0;
            print "\nOnly put operation is supported on tmp directory\n";
         }
         elsif($filetype ne 'config' && $filetype ne 'datastore') {
            $valid = 0;
            print "\nFor browse operation only valid values for filetype ".
                  "argument are datastore and config\n";
         }
      }
      else {
         $valid = 0;
         print "\nfiletype is a mandatory option for the browse operation\n";
      }
   }
   else {
      # bug 222613
      Util::trace(0, "Invalid operation: '$operation'\n");
      Util::trace(0, " List of valid operations:\n");
      map {print "  $_\n"; } sort keys %operations;
      $valid = 0;
   }
   return $valid;
}

__END__

## bug 217605

=head1 NAME

fileaccess.pl - Allows get and put operations on datastore and configuration files and put operation on the /tmp directory

=head1 SYNOPSIS

 fileaccess.pl --operation <put|get|browse> [options]

=head1 DESCRIPTION

This VI Perl command-line utility provides an interface for get and put operations on the datastore 
and configuration files and put operation on the /tmp directory.
The Basic operations are:

=over

=item *

Retrieve the datastore and configuration files.

=item *

Put the files under datastore directory.

=item *

Put the modified configuration files.

=item *

Put the files under /tmp directory.

=item *

Display all the accessible datastore and configuration files.

=back

=head1 OPTIONS

=over

=item B<operation>

Operation to be performed.  Must be one of the following:

I<get> Retrieve the datastore and configuration files.

I<put> Put files under the datastore and tmp directories, modifying the configuration files.

I<browse> Display all the accessible datastore and configuration files.

=item B<datacentername>

Optional. Name of the Datacenter. Mandatory argument for get and put operations on datastore files.

=item B<datastorename>

Optional. Name of the Datastore. Mandatory argument for get and put operations on datastore files.

=item B<filetype>

Optional. Value must be one of the following:

I<datastore> For the get and put operations on datastore files.

I<config> For the get and put operations on configuration files.

I<tmp> For the put operation on the /tmp directory.

=item B<remotepath>

Optional. Remote path of the datastore file.
Mandatory argument for the get and put operations on datastore files

=item B<remotefilename>

Optional. Configuration file name.
Mandatory argument for the get and put operations on configuration files

=item B<localpath>

Optional. Localpath to save the extracted log.

=back

=head1 EXAMPLES

To retrieve the datastore file

   fileaccess.pl --url <https://<IP Address>:<Port>/sdk/vimService>
                 --username myuser --password mypassword --operation get
                 --localpath "C:/tmp/vm.vmx" --remotepath "vm/vm.vmx"
                 --filetype datastore --datastorename <datastore name>
                 -- datacentername <datacenter name>

To retrieve the configuration file

   fileaccess.pl --url <https://<IP Address>:<Port>/sdk/vimService>
                 --username myuser --password mypassword --operation get
                 --localpath "C:/tmp/vm.vmx"
                 --remotefilename <name of configuration files> 
                 --filetype config

To put the datastore file

   fileaccess.pl --url <https://<IP Address>:<Port>/sdk/vimService>
                 --username myuser --password mypassword --operation put
                 --localpath "C:/tmp/vm.vmx" --remotepath "vm/vm.vmx"
                 --filetype datastore  --datastorename <datastore name>
                 -- datacentername <datacenter name>

To put the configuration file

   fileaccess.pl --url <https://<IP Address>:<Port>/sdk/vimService>
                 --username myuser --password mypassword --operation put
                 --localpath "C:/tmp/filename" --remotefilename <name of configuration files> 
                 --filetype config

To put the file under tmp directory

   fileaccess.pl --url <https://<IP Address>:<Port>/sdk/vimService>
                 --username myuser --password mypassword --operation put
                 --localpath "C:/tmp/filename" --remotefilename <name of configuration files> 
                 --filetype tmp

To display the accessible datastore files.

   fileaccess.pl --url <https://<IP Address>:<Port>/sdk/vimService>
                 --username myuser --password mypassword --operation browse --filetype datastore
                 --remotepath vm --datastorename <Datastore name> --datacentername <Datacenter name>

To display the accessible configuration files.

   fileaccess.pl --url <https://<IP Address>:<Port>/sdk/vimService>
                 --username myuser --password mypassword --operation browse --filetype config

=head1 SUPPORTED PLATFORMS

All operations work with VMware VirtualCenter 2.5.

All operations work with VMware ESX 3.5.

