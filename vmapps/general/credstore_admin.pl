#!/usr/bin/perl
# -----------------------------------------------------------------------------
#
# Copyright (c) 2008 VMware, Inc.  All rights reserved.
#
# -----------------------------------------------------------------------------

use 5.006001;
use strict;
use warnings;

use File::Basename;
use VMware::VICredStore;

use constant USAGE => " [-f|--credstore <filename>] <command>

command is one of:

   add -s|--server <server> -u|--username <username> -p|--password <password>
      Add new entry into the credential store.

   remove -s|--server <server> -u|--username <username>
      Remove existing entry from credential store.

   list [-s|--server <server>]
      List existing entries.

   clear
      Delete all entries from credential store.

   help
      Display this menu.
";
use constant FILE_PATH_UNIX => '/.vmware/credstore/vicredentials.xml';
use constant FILE_PATH_WIN  => '/VMware/credstore/vicredentials.xml';


sub usage ()
{
   my $basename = basename($0);
   print "USAGE: $basename" . USAGE;
}

sub short_usage ()
{
   my $basename = basename($0);
   print STDERR "\nTry '$basename help' for more details.\n";
}

sub parse_commandline ()
{
   use Getopt::Long;
   my $file;
   my $server;
   my $username;
   my $password;
   my $command;
   my $argv;
   my $ret;

   eval {
      $ret = GetOptions (
                        'f|credstore=s' => \$file,
                        's|server=s' => \$server,
                        'u|username=s' => \$username,
                        'p|password=s' => \$password
            );
   };
   if ($@) {
      print STDERR "Failed to parse command line options.\n";
      short_usage ();
      exit -1;
   }

   if (0 == $ret) {
      short_usage ();
      exit -1;
   }

   if(defined($file) and ($file eq "" or $file =~ "^-.*")) {
      print STDERR "Credential store filename not specified.\n";
      short_usage ();
      exit -1;
   }

   if(defined($server) and ($server eq "" or $server =~ "^-.*")) {
      print STDERR "Server not specified.\n";
      short_usage ();
      exit -1;
   }

   if(defined($username) and ($username eq "" or $username =~ "^-.*")) {
      print STDERR "Username not specified.\n";
      short_usage ();
      exit -1;
   }

   # Check for invalid options
   $command = "";
   $argv = shift(@ARGV);
   while ($argv) {
      if($argv eq "add" || $argv eq "get" ||
         $argv eq "remove" || $argv eq "list" ||
         $argv eq "clear" || $argv eq "help") {
         if($command eq "") {
            $command = $argv;
         } else {
            print STDERR "Multiple commands specified: $command, $argv\n";
            short_usage ();
            exit -1;
         }
      } else {
         print STDERR "Invalid option specified: $argv\n";
         short_usage ();
         exit -1;
      }
      $argv = shift(@ARGV);
   }
   return ($file, $server, $username, $password, $command);
}

sub prompt_password ()
{
   my $password;
   my $retyped_password;

   # Dont echo
   if ($^O eq 'MSWin32') {
      require Term::Readkey;
      Term::ReadKey::ReadMode('noecho');
   } else {
      system("stty -echo") and die "ERROR: stty failed\n";
   }

   while(1) {
      print "Enter password: ";
      chomp($password = <STDIN>);
      print "\n";

      print "Re-enter password: ";
      chomp($retyped_password = <STDIN>);
      print "\n";

      if($password ne $retyped_password) {
         print STDERR "\nSorry, passwords do not match. Please re-enter.\n";
      } else {
         last;
      }
   }

   # Turn on echo
   if ($^O eq 'MSWin32') {
      Term::ReadKey::ReadMode('normal');
   } else {
      system("stty echo") and die "ERROR: stty failed\n";
   }

   return $password;
}

sub get_default_path
{
   my $filename;

   if ($^O eq 'MSWin32') {
      if (!defined ($ENV{APPDATA})) {
         die "ERROR: Environment variable APPDATA is not set.\n";
      }
      $filename = $ENV{APPDATA} . FILE_PATH_WIN;
   } else {
      if (!defined ($ENV{HOME})) {
         die "ERROR: Environment variable HOME is not set.\n";
      }
      $filename = $ENV{HOME} . FILE_PATH_UNIX;
   }

   return ($filename);
}


sub start ()
{
   my $s_item;
   my $u_item;
   my $p_item;
   my @server_list;
   my @user_list;

   my ($filename, $server, $username, $password, $command)
      = parse_commandline();

   if (!defined($filename) || "" eq $filename) {
      if (defined ($ENV{VI_CREDSTORE})) {
         $filename = $ENV{VI_CREDSTORE};
      }
   }

   eval {

      VMware::VICredStore::init (filename => $filename)
         or die ("ERROR: Unable to initialize Credential Store.\n");

      # Get password from credential store.
      if ($command eq "get") {
         if (!defined ($server) || "" eq $server) {
            print STDERR "Server not specified.\n";
            short_usage();
            exit -1;
         }
         if (!defined ($username) || "" eq $username) {
            print STDERR "User name not specified.\n";
            short_usage();
            exit -1;
         }
         $password = VMware::VICredStore::get_password
                     (server => $server, username => $username);
         if (defined ($password)) {
            print ("Password: $password\n");
         } else {
            print ("Password not found in Credential Store.\n");
         }

      # Add new / update existing entry in credential store.
      } elsif ($command eq "add") {
         if (!defined ($server) || "" eq $server) {
            print STDERR "Server not specified.\n";
            short_usage();
            exit -1;
         }
         if (!defined ($username) || "" eq $username) {
            print STDERR "User name not specified.\n";
            short_usage();
            exit -1;
         }
         if (!defined ($password)) {
            $password = prompt_password();
         }
         if (VMware::VICredStore::add_password (server => $server,
                                                username => $username,
                                                password => $password)) {
            print ("Existing entry modified successfully.\n");
         } else {
            print ("New entry added successfully\n");
         }

      # Remove existing entry from credential store.
      } elsif ($command eq "remove") {
         if (!defined ($server) || "" eq $server) {
            print STDERR "Server not specified.\n";
            short_usage();
            exit -1;
         }
         if (!defined ($username) || "" eq $username) {
            print STDERR "User name not specified.\n";
            short_usage();
            exit -1;
         }
         if (VMware::VICredStore::remove_password (server => $server,
                                                   username => $username)) {
            print ("Existing entry deleted successfully.\n");
         } else {
            print ("Entry not found.\n");
         }

      # Remove all entries from credential store.
      } elsif ($command eq "clear") {
         VMware::VICredStore::clear_passwords();
         print ("All entries have be removed successfully.\n");

      # List entries in credential store.
      } elsif ($command eq "list") {
         printf ("%-12s %-12s\n", "Server", "User Name");

         if (!defined ($server) or "" eq $server) {
            @server_list = VMware::VICredStore::get_hosts ();
         } else {
            @server_list = ($server);
         }

         foreach $s_item (@server_list) {
            @user_list = VMware::VICredStore::get_usernames (server => $s_item);
            foreach $u_item (@user_list) {
               printf ("%-12s %-12s", $s_item, $u_item);
               printf ("\n");
            }
         }

      } elsif ($command eq "help") {
         usage ();
         exit -1;
      } else {
         short_usage ();
         exit -1;
      }
   };
   if ($@) {
      if (!defined($filename) || "" eq $filename) {
         $filename = get_default_path ();
      }
      if ($@ =~ /File not found/) {
         print STDERR "ERROR: File not found: $filename.\n";
         exit -1;
      } elsif ($@ =~ /Operation failed/) {
         print STDERR "ERROR: Operation failed.\n";
         exit -1;
      } elsif ($@ =~ /Failed to parse file/) {
         print STDERR "ERROR: Failed to parse file: $filename\n";
         exit -1;
      } else {
         print STDERR "ERROR: Internal error.\n";
         exit -1;
      }
   }
}

start();

__END__

## bug 217605

=head1 NAME

credstore_admin.pl - add, remove, list and clear entries stored in credential store.

=head1 SYNOPSIS

 credstore_admin.pl [options]

=head1 DESCRIPTION

This VI Perl command-line utility can be used to add, remove, list and clear
entries stored in credential store.

=head1 OPTIONS

=over

=item B<add>

Add an entry into the credential store. User must specify
the server  using the --server option and username using
the --username option. If password is not specified at
command line, then user is prompted to enter the password.

=item B<remove>

Remove existing entry from credential store. User must
specify the server using the --server option and username
using the --username option.

=item B<list>

List existing entry from credential store. User can use
the --server option to specify the server. In such a case,
entries specific to that server will be listed.

=item B<clear>

Remove all existing entries from credential store.

=item B<help>

This will display the usage details for the credstore_admin.pl.

=item B<Note:>

Location of credential store file can be specified using
the --credstore option. If credential store filename is
not specified, then it defaults to the following location:

 UNIX:    $HOME/.vmware/credstore/vicredentials.xml
 WINDOWS: %APPDATA%\VMware\credstore\vicredentials.xml

=back

=head1 EXAMPLES

Add new entry into the credential store:

   credstore_admin.pl add --server <server> --username <username> --password <password>

Remove existing entry from credential store:

   credstore_admin.pl remove --server <server> --username <username>

List existing entries from the credential store:

   credstore_admin.pl list [--server <server>] [--showpw]

Delete all entries from credential store:

   credstore_admin.pl clear

Display the usage details:

   credstore_admin.pl help

=head1 SUPPORTED PLATFORMS

VI Toolkit (for Windows).

