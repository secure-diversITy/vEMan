#!/usr/bin/perl -w
#
# Copyright (c) 2007 VMware, Inc.  All rights reserved.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../";

use VMware::VIRuntime;

$Util::script_version = "1.0";

my %opts = (
   aboutservice => {
      type => "=s",
      help => "Information about the service",
      required => 0,
      default => 'all',
   },
   aboutviperl => {
      type => "=s",
      help => "Information about the viPerl toolkit",
      required => 0,
      default =>'version',
   },
);

my %field_values = (
   'apiInfo',
    'product',
    'version',
    'osType',
);

my $service_content;

Opts::add_options(%opts);
Opts::parse();
if (Opts::option_is_set('aboutviperl')) {
   get_toolkitversion();
} else {
   Opts::validate(\&validate);

   Util::connect();
   about_info();
   Util::disconnect();
}

sub about_info {
$service_content = Vim::get_service_content();
   if(Opts::get_option('aboutservice') eq 'apiinfo') {
     get_apiInfo();
   }
   if(Opts::get_option('aboutservice') eq 'product') {
     get_productInfo();
   }
   if(Opts::get_option('aboutservice') eq 'version') {
      get_versionInfo();
   }
   if(Opts::get_option('aboutservice') eq 'ostype') {
      get_osType();
   }
   if(Opts::get_option('aboutservice') eq 'all') {
      get_apiInfo();
      get_productInfo();
      get_versionInfo();
      get_osType();
   }
}


sub get_toolkitversion {
   Util::trace(0, "\n\nPerl Toolkit Version is ". VMware::VIRuntime->VERSION ."\n");
}

sub get_apiInfo {
   if($service_content) {
      if($service_content->about) {
         if(defined $service_content->about->apiType) {
            my $apiType = $service_content->about->apiType;
            Util::trace(0, "\nThis is  ".$apiType. "");
         }
         else {
            Util::trace(0," apiType not known");
         }
         if(defined $service_content->about->apiVersion) {
            my $apiVersion = $service_content->about->apiVersion;
            Util::trace(0, " ".$apiVersion. "\n");
         }
         else {
            Util::trace(0,"apiVersion not known");
         }
      }
   }
}

sub get_productInfo {
   if($service_content) {
      if($service_content->about) {
         if(defined $service_content->about->fullName) {
            my $fullName = $service_content->about->fullName;
            Util::trace(0, "\nThis is ".$fullName. "");
         }
         else {
            Util::trace(0," fullName not known");
         }
         if(defined $service_content->about->osType) {
            my $osType = $service_content->about->osType;
            if ($osType eq 'win32-x86') {
               Util::trace(0," running on x86-based Windows systems ");
            }
            elsif($osType eq 'linux-x86') {
               Util::trace(0," running on x86-based Linux systems");
            }
            elsif($osType eq 'vmnix-x86') {
               Util::trace(0," running on x86 ESX Server microkernel");
            }
            else {
               Util::trace(0," having operating system type and "
                             ."architecture as " .$osType."");
            }
         }
         else {
            Util::trace(0," osType not known");
         }
         if(defined $service_content->about->productLineId) {
            my $productLineId = $service_content->about->productLineId;
            Util::trace(0,"\nThe product Line ID is a unique identifier for "
                          ."a product line.");
            if ($productLineId eq 'vpx') {
               Util::trace(0," This is VMware VirtualCenter product.\n");
            }
            elsif($productLineId eq 'esx') {
               Util::trace(0," This is VMware ESX Server product.\n");
            }
            elsif($productLineId eq 'gsx') {
               Util::trace(0," This is VMware GSX Server product.\n");
            }
            else {
               Util::trace(0," product line id is ".$productLineId. " ");
            }
         }
         else {
            Util::trace(0,"productLineId not known");
         }
      }
   }
}


sub get_versionInfo {

   if($service_content) {
      if($service_content->about) {
         if(defined $service_content->about->name) {
            my $name = $service_content->about->name;
            Util::trace(0, "\nShort form of the product name is "
                           .$name. "");
         }
         else {
            Util::trace(0," name not known");
         }
         if(defined $service_content->about->version) {
            my $version = $service_content->about->version;
            Util::trace(0," having version " .$version."\n\n");
         }
         else {
            Util::trace(0," version not known");
         }
         
      }
   }
}

sub get_osType {

   if($service_content) {
      if($service_content->about) {
         if(defined $service_content->about->osType) {
            my $osType = $service_content->about->osType;
             if ($osType eq 'win32-x86') {
               Util::trace(0,"System is running on x86-based Windows systems \n");
            }
            elsif($osType eq 'linux-x86') {
               Util::trace(0,"System is running on x86-based Linux systems \n");
            }
            elsif($osType eq 'vmnix-x86') {
               Util::trace(0,"System is running on x86 ESX Server microkernel \n");
            }
            else {
               Util::trace(0,"System is having operating system type and "
                             ."architecture as " .$osType."\n");
            }
         }
         else {
            Util::trace(0," osType not known");
        }
     }
   }
}

sub validate {
   my $valid = 1;
   if (Opts::option_is_set('aboutservice')) {
      my $service_option = Opts::get_option('aboutservice');
      if(!(($service_option eq 'apiinfo')||($service_option eq 'product')||
          ($service_option eq 'version')||($service_option eq 'ostype')||
          ($service_option eq 'all'))) {
         Util::trace(0, "Invalid aboutservice option "
                    . "supported options are apiinfo,product,version,ostype,all \n");
          $valid = 0;
      }
     }
     if (Opts::option_is_set('aboutviperl')) {
         my $viperl_option = Opts::get_option('aboutviperl');
         if(!($viperl_option eq 'version')) {
             Util::trace(0, "Invalid aboutviperl option "
                    . "supported options is version\n");
          $valid = 0;
      }
   }
   return $valid;
}

__END__

## bug 217605

=head1 NAME

viversion.pl - Displays system information like the name, type, and version.

=head1 SYNOPSIS

 viversion.pl --aboutservice <all|apiinfo|product|version|ostype>
              --aboutviperl <version> [options]

=head1 DESCRIPTION

This VI Perl command-line utility displays the system
information like the name, type, version, and build number.

=head1 OPTIONS

=over

=item B<aboutviperl>

Optional. Version information about the ViPerl toolkit

=item B<aboutService>

Required. This data object type describes system information including
the name, type, version, and build number etc. Options are
apiinfo, product, version, and ostype.

=back

=head1 EXAMPLES

Displaying the product information, which include FullName OsType and productLineId::

 perl viversion.pl --url https://<ipaddress>:<port>/sdk/webService --username myuser
  --password mypassword --aboutservice product

Displaying the version information, which include name and  version::

 perl viversion.pl --url https://<ipaddress>:<port>/sdk/webService --username myuser
  --password mypassword --aboutservice version

Displaying all the aboutInfo contents name, type, version, and build number etc::

 perl viversion.pl --url https://<ipaddress>:<port>/sdk/webService --username myuser
  --password mypassword --aboutservice all

Displaying perltoolkit information:

 perl viversion.pl --url https://<ipaddress>:<port>/sdk/webService --username myuser
  --password mypassword --aboutviperl version

=head1 SUPPORTED PLATFORMS

All operations work with VMware VirtualCenter 2.0.1 and VMware ESX 3.0.1.

