package IP::Noise::C::Translator;

use strict;

use IP::Noise;

my $arb_string_len = IP::Noise::get_max_id_string_len() + 1;

sub LAST_CHAIN ()
{
    return { 'type' => 'last' };
}

sub LAST_STATE ()
{
    return { 'type' => 'last' };
}

sub new
{
    my $class = shift;

    my $self = {};

    bless $self, $class;

    $self->initialize(@_);

    return $self;
}

sub initialize
{
    my $self = shift;

    my $arbitrator_data_structure = shift;

    $self->{'arb_ds'} = $arbitrator_data_structure;

    # This is the I/O connection to the arbitrator.
    my $conn = shift;

    $self->{'conn'} = $conn;

    return 0;
}

my %transactions =
(
    'clear_all' =>
    {
        'opcode' => 0x19,
        'params' => [],
        'out_params' => [],
    },
    'new_chain' =>
    {
        'opcode' => 0x0,
        'params' => [ "string" ],
        'out_params' => [ "int" ],
    },
    'end_connection' =>
    {
        'opcode' => 0x10000,
        'params' => [],
        'out_params' => [],
    },
    'new_state' =>
    {
        'opcode' => 0x01,
        'params' => [ "chain", "string" ],
        'out_params' => [ "int" ],
    },
    'set_source' =>
    {
        'opcode' => 0x3,
        'params' => [ "chain", "ip_packet_filter"],
        'out_params' => [],
    },
    'set_dest' =>
    {
        'opcode' => 0x4,
        'params' => [ "chain", "ip_packet_filter"],
        'out_params' => [],
    },
    'set_protocol' =>
    {
        'opcode' => 0x5,
        'params' => [ "chain", "int", "bool" ],
        'out_params' => [],
    },
    'set_tos' =>
    {
        'opcode' => 0x6,
        'params' => [ "chain", "int", "bool" ],
        'out_params' => [],
    },
    'set_drop_delay_prob' =>
    {
        'opcode' => 0x0E,
        'params' => [ "chain", "state", "prob", "prob" ],
        'out_params' => [],
    },
    'set_delay_type' =>
    {
        'opcode' => 0x0F,
        'params' => [ "chain", "state", "delay_function_type" ],
        'out_params' => [],
    },
    'set_split_linear_points' =>
    {
        'opcode' => 0x10,
        'params' => [ "chain", "state", "split_linear_points" ],
        'out_params' => [],
    },
    'set_lambda' =>
    {
        'opcode' => 0x11,
        'params' => [ "chain", "state", "lambda" ],
        'out_params' => [],
    },
    'set_time_factor' =>
    {
        'opcode' => 0x13,
        'params' => [ "chain", "state", "delay_type" ],
        'out_params' => [],
    },
    'set_stable_delay_prob' =>
    {
        'opcode' => 0x14,
        'params' => [ "chain", "state", "prob" ],
        'out_params' => [],
    },
    'delete_state' =>
    {
        'opcode' => 0x15,
        'params' => [ "chain", "state" ],
        'out_params' => [],
    },
    'delete_chain' =>
    {
        'opcode' => 0x16,
        'params' => [ "chain"],
        'out_params' => [],
    },
);

sub pack_int32
{
    my $value = shift;

    return pack("V", $value);
}

sub pack_opcode
{
    my $opcode = shift;

    return pack_int32($opcode);
}


sub read_retvalue
{
    my $self = shift;

    my $conn = $self->{'conn'};

    my $value = $conn->conn_read(4);

    return unpack("V", $value);
}

sub pack_string
{
    my $string = shift;

    return pack(("a" . $arb_string_len), $string);     
}

sub pack_prob
{
    my $prob = shift;
    
    return pack("d", $prob);
}

sub pack_delay_function_type
{
    my $delay_type = shift;

    if ($delay_type eq "exponential")
    {
        return pack_int32(0);
    }
    elsif ($delay_type eq "generic")
    {
        return pack_int32(1);
    }
}

sub pack_delay
{
    my $delay = shift;

    return pack_int32($delay);
}

sub pack_ip
{
    my $ip = shift;

    return join("", (map { chr($_) } split(/\./, $ip)));
}

sub pack_range
{
    my $range = shift;

    return pack("SS", $range->{'start'}, $range->{'end'});
}

sub pack_ip_filter
{
    my $filter = shift;
    my $ret = "";
    
    $ret = pack_ip($filter->{'ip'}) . pack_int32($filter->{'netmask_width'});

    $ret .= join("", (map { &pack_range($_) } @{$filter->{'ports'}}));

    # Now append the port terminator
    $ret .= pack("SS", 65535, 0);

    return $ret;
}

sub transact
{
    my $self = shift;

    my $name = shift;

    if (!exists($transactions{$name}))
    {
        die "No such transaction";
    }

    my $record = $transactions{$name};

    my $conn = $self->{'conn'};

    $conn->conn_write(pack_opcode($record->{'opcode'}));

    foreach my $param_type (@{$record->{'params'}})
    {
        # TODO: Write each parameter according to what was inputted in the 
        # function arguments.
        my $param = shift;

        if ($param_type eq "string")
        {
            $conn->conn_write(pack_string($param));
        }
        elsif ($param_type eq "chain")
        {
            if ($param->{'type'} eq "last")
            {
                $conn->conn_write(pack_int32(2));
            }
            else
            {
                die "Unknown chain type!\n";
            }
        }
        elsif ($param_type eq "state")
        {
            if ($param->{'type'} eq "last")
            {
                $conn->conn_write(pack_int32(2));
            }
            else
            {
                die "Unknown state type!\n";
            }        
        }
        elsif ($param_type eq "prob")
        {
            $conn->conn_write(pack_prob($param));
        }
        elsif ($param_type eq "delay_function_type")
        {
            $conn->conn_write(pack_delay_function_type($param));
        }
        elsif ($param_type eq "split_linear_points")
        {
            foreach my $point (@{$param})
            {
                $conn->conn_write(pack_prob($point->{'prob'}));
                $conn->conn_write(pack_delay($point->{'delay'}));
            }
        }
        elsif ($param_type eq "lambda")
        {
            $conn->conn_write(pack_int32($param));
        }
        elsif ($param_type eq "delay_type")
        {
            $conn->conn_write(pack_int32($param));
        }
        elsif ($param_type eq "ip_packet_filter")
        {
            my $filters = $param->{'filters'};

            foreach my $f (@$filters)
            {
                $conn->conn_write(pack_ip_filter($f));
            }
            $conn->conn_write(
                pack_ip_filter(
                    {
                        'ip' => "255.255.255.255",
                        'ports' => [ { 'start' => 0, 'end' => 65535 } ],
                        'netmask_width' => 32,
                    }
                    )
                );
        }
        elsif ($param_type eq "int")
        {
            $conn->conn_write(
                pack_int32($param)
                );
        }
        elsif ($param_type eq "bool")
        {
            $conn->conn_write(
                pack_int32($param)
                );
        }
        else
        {
            die "Unknown param_type $param_type!\n";
        }
    }

    my $ret_value = $self->read_retvalue();

    my (@ret);
    foreach my $param_type (@{$record->{'out_params'}})
    {
        #TODO: read output params from the line and return them.
        if ($param_type eq "int")
        {
            my $int = $conn->conn_read(4);
            push @ret, unpack("V", $int);
        }
        else
        {
            die "Unknown param_type $param_type!\n";
        }
    }

    return ($ret_value, \@ret);
}

my $ws = "    ";

sub load_arbitrator
{
    my $self = shift;

    my $ds = $self->{'arb_ds'};

    my ($ret_value, $other_args) = $self->transact("clear_all");

    if ($ret_value != 0)
    {
        die "The arbitrator failed or refused to clear all the chains!\n";
    }

    foreach my $chain (values(%{$ds->{'chains'}}))
    {
        # Create a new chain by that name in the arbitrator
        print "In chain: " , $chain->{'name'}, "\n";

        ($ret_value, $other_args) = 
            $self->transact(
                "new_chain", 
                $chain->{'name'}
                );

        if ($ret_value != 0)
        {
            die "The arbitrator did not give a valid chain index!\n";
        }

        $chain->{'id'} = $other_args->[0];

        print "Chain ID =  ",  $chain->{'id'} , "!\n";

        foreach my $state_name (keys(%{$chain->{'states'}}))
        {
            my $state = $chain->{'states'}->{$state_name};
            
            print "In State " , $state_name, "\n";
            ($ret_value, $other_args) = 
                $self->transact(
                    "new_state",
                    LAST_CHAIN,
                    $state_name
                    );
            
            if ($ret_value != 0)
            {
                die "The arbitrator did not accept the state!\n";
            }
            # Put the index of the state within the arbitrator in a safe
            # place for safekeeping.
            $state->{'id'} = $other_args->[0];

            # Let's set the drop/delay probabilities of the state.

            ($ret_value, $other_args) = 
                $self->transact(
                    "set_drop_delay_prob",
                    LAST_CHAIN,
                    LAST_STATE,
                    $state->{'drop_prob'},
                    $state->{'delay_prob'}
                    );
                
            if ($ret_value != 0)
            {
                die "The arbitrator did not accept the Drop/Delay probabilites!\n";
            }

            if ($state->{'delay_prob'} > 0)
            {
                # Let's set the delay function type of the state
    
                ($ret_value, $other_args) = 
                    $self->transact(
                        "set_delay_type",
                        LAST_CHAIN,
                        LAST_STATE,
                        $state->{'delay_type'}->{'type'}
                        );

                if ($ret_value != 0)
                {
                    die "The arbitrator did not accept the delay type!\n";
                }
                
                if ($state->{'delay_type'}->{'type'} eq "generic")
                {
                    # Let's transmit the points to the other end

                    ($ret_value, $other_args) = 
                        $self->transact(
                            "set_split_linear_points",
                            LAST_CHAIN,
                            LAST_STATE,
                            $state->{'delay_type'}->{'points'}
                            );

                    if ($ret_value != 0)
                    {
                        die "The arbitrator did not accept the points " . 
                            "for the generic function!\n";                            
                    }
                }
                elsif ($state->{'delay_type'}->{'type'} eq "exponential")
                {
                    # Let's transmit the Lambda to the arbitrator
                    ($ret_value, $other_args) = 
                        $self->transact(
                            "set_lambda",
                            LAST_CHAIN,
                            LAST_STATE,
                            $state->{'delay_type'}->{'lambda'}
                            );

                    if ($ret_value != 0)
                    {                        
                        die "The arbitrator did not accept our lambda!\n";
                    }
                }
            }

            # Let's transmit the time factor of the state

            ($ret_value, $other_args) =
                $self->transact(
                    "set_time_factor",
                    LAST_CHAIN,
                    LAST_STATE,
                    $state->{'time_factor'}
                    );

            if ($ret_value != 0)
            {
                die "The arbitrator did not accept our time factor!\n";
            }

            # Let's transmit the stable delay probability

            ($ret_value, $other_args) =
                $self->transact(
                    "set_stable_delay_prob",
                    LAST_CHAIN,
                    LAST_STATE,
                    $state->{'stable_delay_prob'}
                    );

            if ($ret_value != 0)
            {
                die ("The arbitrator did not accept our " . 
                    "stable delay probability!\n");
            }
        } # End of States-Loop

        # Now, let's upload the source IP Packet Filter

        if ($chain->{'source'}->{'type'} ne "none")
        {
            print "Uploading source!\n";

            ($ret_value, $other_args) = 
                $self->transact(
                    "set_source",
                    LAST_CHAIN,
                    $chain->{'source'}
                    );

            if ($ret_value != 0)
            {
                die "The arbitrator did not accept our source!\n";
            }
        }

        if ($chain->{'dest'}->{'type'} ne "none")
        {
            print "Uploading dest!\n";

            ($ret_value, $other_args) = 
                $self->transact(
                    "set_dest",
                    LAST_CHAIN,
                    $chain->{'dest'}
                    );

            if ($ret_value != 0)
            {
                die "The arbitrator did not accept our dest!\n";
            }
        }

        if ($chain->{'protocols'}->{'type'} ne "all")
        {
            print "Uploading Protocols!\n";

            my $include_or_exclude = $chain->{'protocols'}->{'type'} eq "only";

            if ($include_or_exclude)
            {
                ($ret_value, $other_args) =
                    $self->transact(
                        "set_protocol",
                        LAST_CHAIN,
                        256,
                        0
                        );

                if ($ret_value != 0)
                {
                    die ("The arbitrator refused to disable " . 
                        "all the protocols!\n");
                }
            }
            foreach my $p (keys(%{$chain->{'protocols'}->{'protocols'}}))
            {
                ($ret_value, $other_args) =
                    $self->transact(
                        "set_protocol",
                        LAST_CHAIN,
                        $p,
                        $include_or_exclude
                        );
                
                if ($ret_value != 0)
                {
                    die ("The arbitrator refused to " . 
                        ($include_or_exclude ? "enable" : "disable") .
                        " the protocol $p!\n");
                }
            }
        }

        if ($chain->{'tos_spec'}->{'type'} ne "all")
        {
            print "Uploading TOS!\n";

            my $include_or_exclude = $chain->{'tos_spec'}->{'type'} eq "only";

            if ($include_or_exclude)
            {
                ($ret_value, $other_args) =
                    $self->transact(
                        "set_tos",
                        LAST_CHAIN,
                        64,
                        0
                        );

                if ($ret_value != 0)
                {
                    die ("The arbitrator refused to disable " . 
                        "all the tos bits!\n");
                }
            }
            foreach my $p (keys(%{$chain->{'tos_spec'}->{'tos'}}))
            {
                print "Setting TOS bit $p!\n";
                ($ret_value, $other_args) =
                    $self->transact(
                        "set_tos",
                        LAST_CHAIN,
                        $p,
                        $include_or_exclude
                        );
                
                if ($ret_value != 0)
                {
                    die ("The arbitrator refused to " . 
                        ($include_or_exclude ? "enable" : "disable") .
                        " the tos bit $p!\n");
                }
            }
        }
    }

    ($ret_value, $other_args) = $self->transact("end_connection");

    return 0;
}


1;
