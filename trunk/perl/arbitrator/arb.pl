#!/usr/bin/perl -w

use strict;

use Data::Dumper;
use Thread;
use Thread::Queue;
use Thread::RWLock;

use IPTables::IPv4::IPQueue qw(:constants);
use Time::HiRes qw(usleep gettimeofday);

use IP::Noise::Arb::IFace;
use IP::Noise::Arb::Switcher;
use IP::Noise::Conn;

use IP::Noise::Arb::Delayer;
use IP::Noise::Arb::Packet::Logic;

use vars qw(%flags $data $data_lock $arb_iface $update_states);

#my $conn = IP::Noise::Conn->new(1);

%flags = (
    'reinit_switcher' => 1,
);

$data = {};

$data_lock = Thread::RWLock->new();

sub thread_func_interface
{
    print "In thread!\n";
    $arb_iface = IP::Noise::Arb::IFace->new($data, $data_lock, \%flags);    

    print "In thread 2 ! \n";

    $arb_iface->loop();
}

my $thread_interface = Thread->new(\&thread_func_interface);

sub thread_func_update_states
{
    $update_states = IP::Noise::Arb::Switcher->new($data, $data_lock, \%flags);

    $update_states->loop();
}

my $thread_update_states = Thread->new(\&thread_func_update_states);

my $packget_logic = IP::Noise::Arb::Packet::Logic->new();

my $ip_queue = IPTables::IPv4::IPQueue->new(
    'copy_mode' => IPQ_COPY_PACKET,
    'copy_range' => 2048
    );

if (! $ip_queue)
{
    die IPTables::IPv4::IPQueue->errstr();
}

# Thread::Queue is a class for a thread-safe queue.
my $packets_to_arbitrate_queue = Thread::Queue->new();

my $release_callback = 
    sub {
        my $msg = shift;

        $queue->set_verdict($msg->packet_id, NF_ACCEPT);
    };

my $delayer = Delayer->new($release_callback);

my $terminate = 0;

sub release_packets_thread_func
{
    while (! $terminate)
    {
        {
            lock($delayer);
            $delayer->release_packets_poll_function();
        }
        usleep(500);
    }
}

sub decide_what_to_do_with_packets_thread_func
{
    my ($verdict);

    while (! $terminate)
    {
        my $msg_with_time = $packets_to_arbitrate_queue->dequeue();

        my $msg = $msg_with_time->{'msg'};
        
        $verdict = $packet_logic->decide_what_to_do_with_packet($msg);

        if ($verdict->{'action'} eq "accept")
        {
            # Accept immidiately
            $release_callback->($msg);
        }
        elsif ($verdict->{'action'} eq "drop")
        {
            # Drop the packet
            $queue->set_verdict($msg->packet_id, NF_DROP);
        }
        elsif ($verdict->{'action'} eq "delay")
        {
            # Delay the packet for $verdict quanta
            lock($delayer);
            $delayer->delay_packet(
                $msg,
                $msg_with_time->{'sec'},
                $msg_with_time->{'usec'},
                $msg_with_time->{'index'},
                $verdict->{'delay_len'},
                );
        }
        else
        {
            $terminate = 1;
            die "Unknown Action!\n";
        }
    }
}

my $release_packets_thread_handle = Thread->new(\&release_packets_thread_func);
my $decide_what_to_do_with_packets_thread_handle = Thread->new(\&decide_what_to_do_with_packets_thread_func);

my ($last_sec, $last_usec) = (0, 0);
my $packet_index = 0;
while (1)
{
    my $msg = $ip_queue->get_message();
    my ($sec, $usec) = gettimeofday();

    # We have to do something so it won't overflow...
    $packet_index++;

    if (! $msg)
    {
        $terminate = 1;
        die IPTables::IPv4::IPQueue->errstr();
    }

    $packets_to_arbitrate_queue->enqueue(
        {
            'msg' => $msg,
            'sec' => $sec,
            'usec' => $usec,
            'index' => $packet_index,
        }
        );
}

