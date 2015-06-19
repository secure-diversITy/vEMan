#!/usr/bin/perl -w

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

# define custom options for vm and target host
my %opts = (
   'vmname' => {
      type => "=s",
      help => "Name of VM to delete",
      required => 1,
   },
);

# read and validate command-line parameters
Opts::add_options(%opts);
Opts::parse();
Opts::validate();

my $vmname = Opts::get_option('vmname');

# connect to the server and login
Util::connect();

my $vm_view = Vim::find_entity_view(view_type => 'VirtualMachine', filter =>{ 'name' => $vmname});

unless($vm_view) {
        print "Error: Unable to locate VM " . $vmname . "\n";
}

print "\nFound VM: " . $vm_view->name . "\n";
print "Would you like to delete this VM? y|n\n";
my $ans = <STDIN>;
chomp($ans);
if($ans eq 'n') {
        print "Leaving VM alone, for now ...\n";
} elsif ($ans eq 'y') {
        print "Destroying VM \"" . $vm_view->name . "\"\n";
        my $task_ref = $vm_view->Destroy_Task();
        my $msg = "Successfully removed \"" . $vm_view->name . "\"!";
        &getStatus($task_ref,$msg);
} else {
        print "Please enter y|n!\n";
}

Util::disconnect();

sub getStatus {
        my ($taskRef,$message) = @_;

        my $task_view = Vim::get_view(mo_ref => $taskRef);
        my $taskinfo = $task_view->info->state->val;
        my $continue = 1;
        while ($continue) {
                my $info = $task_view->info;
                if ($info->state->val eq 'success') {
                        print $message,"\n";
                        return $info->result;
                        $continue = 0;
                } elsif ($info->state->val eq 'error') {
                        my $soap_fault = SoapFault->new;
                        $soap_fault->name($info->error->fault);
                        $soap_fault->detail($info->error->fault);
                        $soap_fault->fault_string($info->error->localizedMessage);
                        die "$soap_fault\n";
                }
                sleep 5;
                $task_view->ViewBase::update_view_data();
        }
}

