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
   log => {
      type => "=s",
      help => "Key of log file being monitored",
      default => "hostd",
   },
   follow => {
      type => "",
      help => "Monitor log file and append data as it grows",
   },
   lines => {
      type => "=i",
      help => "Output the last N lines",
      default => "10",
   },
   sleep => {
      type => "=f",
      help => "With -follow, sleep for S seconds between iterations",
      default => "1.0",
   },
   bundle => {
      type => "",
      help => "Generate bundles of the logs",
   },
   host => {
      type => "=s",
      help => "Host name whose logs are to be seen",
      required => 0,
   },
);


Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $logKey =Opts::get_option('log');
my $sleepTime =Opts::get_option('sleep');
my $lastNLines =Opts::get_option('lines');
my $host = Opts::get_option('host');
my $follow = 0;
my $hostname;
my $start;
my $host_view;
my $instance_type = Vim::get_service_content()->about->apiType;

$follow = 1 if (Opts::option_is_set('follow'));
my $diagmgr_view;
get_diagnosticManager();

Util::disconnect();


sub get_diagnosticManager {
   $diagmgr_view =
   Vim::get_view(mo_ref => Vim::get_service_content()->diagnosticManager);
   unless ($diagmgr_view) {
      Util::trace(0, "Diagnostic Manager not found.\n");
   }
   if(defined $diagmgr_view){
      my $result =instance_validation();
      if($result == 0) {
         $host_view = Vim::find_entity_views (view_type => 'HostSystem');
      }
      else {
         if (Opts::option_is_set('host')) {
            $host_view  = Vim::find_entity_views(view_type => 'HostSystem',
                                                 filter => {'name' => $host});
            unless (@$host_view) {
               Util::trace(0, "Host $host not found.\n");
               return;
            }
         }
      }
      if (Opts::option_is_set('bundle')) {
         generate_log_bundles();
      }
      else {
         getLogData($logKey, $sleepTime, $lastNLines, $follow);
      }
   }
}

sub instance_validation {
   my $value=1;
   if ($instance_type eq 'HostAgent') {
      if (Opts::option_is_set('host')) {
         Util::trace(0, "\nDonot specify host when running directly via host \n");
      }
      $value =0;
   }
   if ($instance_type eq 'VirtualCenter') {
      if (Opts::option_is_set('follow')){
         if (!Opts::option_is_set('host')) {
            Util::trace(0, "\nFor follow option host".
                           " must be specified when running via vCenter\n");
            $value =0;
         }
      }
      if (Opts::option_is_set('bundle')) {
         if (!Opts::option_is_set('host')) {
            $value = 0;
         }
      }
   }
   return $value;
}


sub getLogData {
   my $logData;
   my $lineEnd;
   my ($logKey, $sleepTime, $lastNLines, $follow) = @_;
   foreach (@$host_view) {
      $hostname = $_->name;
      # Get the last line of the log file by starting from a very large last line
      eval {           
         if ($instance_type eq 'VirtualCenter') {
            $logData = $diagmgr_view->BrowseDiagnosticLog(key => $logKey,
                                                          host => $_,
                                                          start => "999999999");
            $lineEnd = $logData->lineEnd;
            $start = $lineEnd - $lastNLines;
            $logData = readLogFile($diagmgr_view, $logKey, $start);
         }
         else {
            $logData = $diagmgr_view->BrowseDiagnosticLog(key => $logKey,
                                                          start => "999999999");
            $lineEnd = $logData->lineEnd;
            $start = $lineEnd - $lastNLines;
            $logData = readLogFile($diagmgr_view, $logKey, $start);
         }
         if (Opts::option_is_set('follow')) {
            while (1) {
               $logData = readLogFile($diagmgr_view, $logKey, $start);
               $start = $logData->lineEnd + 1;
               sleep $sleepTime;
            }
         }
      };
      if ($@) {
         if (ref($@) eq 'SoapFault') {
            if (ref($@->detail) eq 'CannotAccessFile') {
               Util::trace(0,"\nkey refers to a file that cannot".
                             " be accessed at the present time.\n");
            }
            elsif (ref($@->detail) eq 'InvalidArgument') {
               Util::trace(0,"\nkey refers to a nonexistent log file".
                             " or the log file is not of type plain for " .
                             "host $hostname.\n");
            }
            elsif (ref($@->detail) eq 'RuntimeFault') {
                Util::trace(0,"\nRuntime fault.\n");
            }
            else {
                Util::trace(0, "Error: "  . $@ . " ");
            }
         }
         else {
             Util::trace(0, "Error: "  . $@ . " ");
         }
      }
      # Get the last $lastNLines lines of the log first and then check every
      # $sleepTime seconds to see if the log size has increased.
   }
}

sub readLogFile {
   my $logData;
   my ($diagMgr, $logKey, $start) = @_;
   eval {
      if ($instance_type eq 'VirtualCenter') {
         $logData = $diagmgr_view->BrowseDiagnosticLog(key => $logKey,
                                               host => $_,
                                               start => $start,
                                               lines => $lastNLines);
      }
      else {
          $logData = $diagmgr_view->BrowseDiagnosticLog(key => $logKey,
                                               start => $start,
                                               lines => $lastNLines);
      }
   };
   if ($@) {
      if (ref($@) eq 'SoapFault') {
         if (ref($@->detail) eq 'CannotAccessFile') {
            Util::trace(0,"\nkey refers to a file that cannot".
                                         " be accessed at the present time.\n");
         }
         elsif (ref($@->detail) eq 'InvalidArgument') {
            Util::trace(0,"\nkey refers to a nonexistent log file".
                                    " or the log file is not of type plain.\n");
         }
         elsif (ref($@->detail) eq 'RuntimeFault') {
            Util::trace(0,"\nRuntime fault.\n");
         }
         else {
            Util::trace(0, "Error: "  . $@ . " ");
         }
      }
      else {
         Util::trace(0, "Error: "  . $@ . " ");
      }
   }
   if ($logData->lineStart != 0) {
         Util::trace(0, "\n\n\n*************** Logs for the host "
                                 .$hostname."************************\n\n\n\n");
         foreach my $line (@{$logData->lineText}) {
            Util::trace(0, "" .$line."\n");
         }
    }
   return $logData;
}


sub generate_log_bundles {
   my $log_tasks;
   my $task;
   my @hostArray = ($host_view);

   my $input_url = Opts::get_option('url');
   my $hname = URI->new($input_url)->host();

   Util::trace(0,"\nPlease wait - Log Bundles are being".
                 " generated for server " . $hname .". It will take some time...\n");

   eval {
      if ($instance_type eq 'VirtualCenter') {
         $task = $diagmgr_view->GenerateLogBundles_Task(includeDefault => 1,
                                                        host => @hostArray,);
      }
      else {
         $task = $diagmgr_view->GenerateLogBundles_Task(includeDefault => 1);
      }
      my $task_view = Vim::get_view(mo_ref => $task);
      $log_tasks = track_progress(task_view => $task_view);

      my $cnt = 0;
      my $extension;
      my $log_len = @{$log_tasks};
      my $replace_string = "*";
      while ($cnt < $log_len) {
         my $url = $log_tasks->[$cnt]->url;
         if(rindex($url,"*:") != -1) {
            $url = substr($url,9);
            $url = 'https://'.$hname.$url;
         }
         Util::trace(0, "\n\nDownload log bundles from URL: ".$url."\n");
         $cnt++;
      }
      Util::trace(0, "\n\nLog Bundles generated for server " . $hname."\n");
   };
   if ($@) {
       if (ref($@) eq 'SoapFault') {
          if (ref($@->detail) eq 'LogBundlingFailed') {
             Util::trace(0,"\ngeneration of support bundle failed.\n");
         }
         elsif (ref($@->detail) eq 'RuntimeFault') {
             Util::trace(0,"\nRuntime fault.\n");
         }
      }
      else {
         Util::trace(0,$@);
      }
   }
}

sub track_progress {
   my %args = @_;
   my $task_view = $args{task_view};

   # Print the scale and then enough spaces so that the hash marks line up.
   print "0% |";
   # bug 371487
   print "-" x 50;
   print "| 100%\n";
   print " " x 4;

   my $progress = 0;

   # Keep checking the task's status until either error
   # or success.  If the task is in progress print out
   # the progress.
   while (1) {
      my $info = $task_view->info;
      if ($info->state->val eq 'success') {
         # bug 274300, 371487
         print "#" x (50 - $progress/2);
         print "\n";
         return $info->result;
      } elsif ($info->state->val eq 'error') {
         print "\n";
         my $soap_fault = SoapFault->new;
         $soap_fault->detail($info->error->fault);
         $soap_fault->fault_string($info->error->localizedMessage);
         die $soap_fault;
      } else {
         # Don't buffer output right here.  Doing so 
         # causes the progress bar to not display correctly.
         {
            local $| = 1;

            my $new_progress = $info->progress;
            if ($new_progress and $new_progress > $progress) {
               # Print one # for each percentage done.
               print "#" x (($new_progress - $progress)/2);
               $progress = $new_progress;
            }
         }

         # 2 seconds between updates is fine
         sleep 2;
         $task_view->update_view_data();
      }
   }
}


__END__

## bug 217605

=head1 NAME

hostdiagnostics.pl - Extracts the specified log from the ESX host or VirtualCenter server.

=head1 SYNOPSIS

 hostdiagnostics.pl [options]

=head1 DESCRIPTION

This VI Perl command-line utility displays the log for the ESX host or VirtualCenter server,
and allows users to monitor the log.

=head1 OPTIONS

=over

=item B<log>

Optional. Key of log file being monitored. Default
file is hostd.

=item B<lines>

Optional. Output the last N lines. For example, if 
you specify 2, a log of the last 2 lines is displayed.

=item B<follow>

Optional. This is used to monitor log file and append data as it grows.

=item B<sleep>

Optional. Used with follow sleep for S seconds between iterations.

=item B<bundle>

Optional. Extract the entire diagnostic bundle.

=item B<host>

Optional. Name of the host.
It is required when running via VirtualCenter.

=back

=head1 EXAMPLES

Display log of hostd file:

 hostdiagnostics.pl --url https://<ipaddress>:<port>/sdk/vimService --username
  myuser --password mypassword  --log hostd

Display log details of hostd file's last 2 lines:

 hostdiagnostics.pl --url https://<ipaddress>:<port>/sdk/vimService --username
  myuser --password mypassword  --log hostd --lines 2

Monitor the hostd's log file and append new data as the file grows,
if running via host directly:

 hostdiagnostics.pl --url https://<ipaddress>:<port>/sdk/vimService --username
  myuser --password mypassword  --log hostd --follow

If running via vCenter, give the host name also:

 hostdiagnostics.pl --url https://<ipaddress>:<port>/sdk/vimService --username
  myuser --password mypassword  --log hostd --follow --host myhost

Monitor the host's log file and append new data as the file grows. Sleep for 
4 seconds between the iterations.  If running via host:

 hostdiagnostics.pl --url https://<ipaddress>:<port>/sdk/vimService --username
  myuser --password mypassword  --log hostd --follow --sleep 4

If running via vCenter:

 hostdiagnostics.pl --url https://<ipaddress>:<port>/sdk/vimService --username
  myuser --password mypassword  --log hostd --host myHost

Generate the log bundles:

 hostdiagnostics.pl --url https://<ipaddress>:<port>/sdk/vimService --username
 myuser --password mypassword  --log hostd --bundle

=head1 SUPPORTED PLATFORMS

All operations work with VMware VirtualCenter 2.0.1 and VMware ESX 3.0.1.

