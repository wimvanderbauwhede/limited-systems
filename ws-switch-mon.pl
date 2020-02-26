#!/usr/bin/perl
use v5.28;
use strict;
use warnings;
use Getopt::Std;

# When the process receives a SIGINT (Ctrl-C) or SIGTERM (kill), it will call signal_handler()
$SIG{INT}  = \&signal_handler;
$SIG{TERM} = \&signal_handler;

# My defaults.
# The names must be those reported by `ps`
# Either put your apps in a file named `ws-switch-mon.cfg`, on per line
# Or provide a custom file with `-f`
my @apps_to_control=qw(
firefox
brave
chrome
code
);

our $DUMMY=0;
our $V=0;

my %opts=();
getopt('hvf:', \%opts);
if (exists $opts{'h'}){
    die "Usage: $0 [-v] [-h] [-f <path to file with list of apps to control>]
By default the script will look for a file called 'ws-switch-mon.cfg';
You can provide your own name with the '-f' option.
If it can't find any configuration file, it will control the following apps:\n\n\t".
    join("\n\t", @apps_to_control)."\n".
    "With the -v option, the script prints out what it's doing.\n";
}

if (exists $opts{'v'}){
    $V=1;
}

my $cfg_file='ws-switch-mon.cfg';
if (exists $opts{'$f'}) {
    $cfg_file=$opts{'f'};
}
if (-e $cfg_file){
    open my $CFG, '<', $opts{'$f'} or die $!;
    @apps_to_control=();
    while (my $app_line =<$CFG>) {
        next if $app_line=~/^\s*\#/;
        chomp $app_line;
        push @apps_to_control, $app_line;
    }
    close $CFG;
}

my %apps_to_stop= map {  $_ => 1 } @apps_to_control;

our $pids_in_stoplist={};
 
# make sure that only one instance of this script is running per user
#my $lockfile='/tmp/.wchg.'.$ENV{USER}.'.lockfile'


#current_workspace=$(wmctrl -d | grep \* | cut -d' ' -f1)
my $current_workspace=`xprop -root -notype _NET_CURRENT_DESKTOP`;
chomp $current_workspace;
$current_workspace=~s/_.+=.//;
while (1) {
# This is a polling app, once every second.
    sleep 1;
    my $new_workspace=`xprop -root -notype _NET_CURRENT_DESKTOP`;
    chomp $new_workspace;
    $new_workspace=~s/_.+=.//;
    #new_workspace=$(wmctrl -d | grep \* | cut -d' ' -f1)
    if ( $current_workspace ne $new_workspace ) {
        say "A workspace change has occurred. $current_workspace -> $new_workspace" if $V;
        # Now we can take an action
        my $pids_per_ws = get_pids_per_ws();
        $pids_in_stoplist = get_pids_in_stoplist( \%apps_to_stop, $pids_per_ws );
        $pids_in_stoplist = stop_or_cont_apps($pids_in_stoplist, $new_workspace, $current_workspace);

        $current_workspace=$new_workspace;
    }
}

# So, have a look at what's running 
# - on the current workspace 
# - on any other workspace
# To do this right, we get the pid from wmctrl
# wmctrl -p -l gives list of applications per workspace
#0x02200003  2 7249   mishin pause process on workspace switch - Qwant Search - Mozilla Firefox
#0x0360000a  1 8673   mishin Terminal
# Then we ps to and see if any of these pids is in our list of apps to pause
# Then we killall - s STOP $app them
# Conversely, if any app on the current workspace is in our list, we killall -s CONT $app
sub get_pids_per_ws { 
    my $pids_per_ws={};
    my @proc_lines = `wmctrl -p -l`;
    for my $proc_line (@proc_lines) {
        my @chunks = split(/\s+/,$proc_line);
        my $ws = $chunks[1];
        my $pid = $chunks[2];
        push @{$pids_per_ws->{$ws}},$pid; 
        say "On $ws: $pid" if $V;
    }
    return $pids_per_ws;
}

# Check if any process occurs in the stop list
sub get_pids_in_stoplist { (my $stoplist, my $pids_per_ws)=@_;
    my $pids_in_stoplist={};
    for my $ws (sort keys %{$pids_per_ws}) {
        my $pids =  $pids_per_ws->{$ws};
        for my $pid (@{$pids}) {
# This ps command returns lines like
# 14712 ?        00:03:26 firefox           
            my $ps_line = `ps -p $pid --no-headers`;
            chomp $ps_line;
            $ps_line=~s/^\s+//;
            my @chunks = split(/\s+/,$ps_line);
            my $name=$chunks[3];
            say "$pid: <$name>" if $V;
            if (exists $stoplist->{$name}) {
                $pids_in_stoplist->{$name}=[$pid,$ws];
            }
        } 
    }
    return $pids_in_stoplist;
}

# kill sends a signal to a process. The signals we need are STOP/CONT. We specify the signal with -s
sub stop_or_cont_apps { my ($pids_in_stoplist, $current_ws, $old_ws) = @_; 
# For a given app in this list:
# If it is on the current workspace, send it a CONT
# Else send it a STOP
    my $all_pids_in_stoplist={};
    for my $app (sort keys %{$pids_in_stoplist}) {
        my ($pid,$app_ws) =@{$pids_in_stoplist->{$app}};
        say "App $app is on workspace $app_ws, current workspace is $current_ws, switched from $old_ws" if $V;
        my $all_pids_for_app = get_all_pids_for_app($pid);
        my $pids_str = join(' ',@{$all_pids_for_app});
        $all_pids_in_stoplist->{$app}=[$pids_str,$app_ws];
        if ($app_ws eq $current_ws) {
            say "kill -s CONT $pids_str"." ($app)"  if $V;
            system "kill -s CONT $pids_str" unless $DUMMY;
        } else {
            if ($app_ws eq $old_ws) {
                say "Switched away from workspace for app ($app_ws)" if $V;
                say "kill -s STOP $pids_str"." ($app)" if $V;
                system "kill -s STOP $pids_str" unless $DUMMY;
            } else {
    # Else it means we switched from another ws to the current one
            say  "switched from another workspace ($old_ws) to the current one ($current_ws), leave $app alone" if $V;
            }
        }
    }
    return $all_pids_in_stoplist;
}

# Apps like Chrome and Brave create lots of child processes, which don't stop when the parent gets a STOP signal.
# So we use the pid to the the app name, and then use the app name to get all pids
# I use 
# ps xao pid,comm | grep chrome
# That will get the list of lines, from that get the PIDs
# then send the STOP/CONT to all of these
sub get_all_pids_for_app { (my $pid)=@_;
    my $all_pids_for_app=[];
    my $ps_line = `ps xao pid,comm  --no-headers | grep $pid`;
    chomp $ps_line;
    $ps_line=~s/^\s+//;
    # prints out $pid $app_name
    # split and get these 
    ($pid,my $app_name) = split(/\s+/,$ps_line);
    say "'$ps_line' => $app_name" if $V;
    my @ps_lines =`ps xao pid,comm  --no-headers | grep $app_name`;
    
    for my $ps_line (@ps_lines) {
        chomp $ps_line;
        $ps_line=~s/^\s+//;
        (my $cpid,my $m_app_name) = split(/\s+/,$ps_line);
        say "'$ps_line' => $cpid, $m_app_name ($app_name)" if $V;
        if ($m_app_name eq $app_name) {
            say $cpid if $V;
            push @{$all_pids_for_app}, $cpid;
        }
    }
    return $all_pids_for_app;
}

# Clean up on exit: send a CONT to all processes with pids in the stop list
sub signal_handler {
    for my $app (sort keys %{$pids_in_stoplist}) {
        my ($pid,$app_ws) =@{$pids_in_stoplist->{$app}};
        say "kill -s CONT $pid ($app)" if $V;
        system "kill -s CONT $pid" unless $DUMMY;
         
    }
    exit(0);
}
