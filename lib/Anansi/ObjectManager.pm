package Anansi::ObjectManager;


=head1 NAME

Anansi::ObjectManager - A module object encapsulation manager

=head1 SYNOPSIS

 package Anansi::Example;

 use Anansi::ObjectManager;

 sub DESTROY {
  my ($self) = @_;
  my $objectManager = Anansi::ObjectManager->new();
  if(1 == $objectManager->registrations($self)) {
   $objectManager->obsolete(
    USER => $self,
   );
   $objectManager->unregister($self);
  }
 }

 sub new {
  my ($class, %parameters) = @_;
  return if(ref($class) =~ /^ (ARRAY|CODE|FORMAT|GLOB|HASH|IO|LVALUE|REF|Regexp|SCALAR|VSTRING)$/i);
  $class = ref($class) if(ref($class) !~ /^$/);
  my $self = {
   NAMESPACE => $class,
   PACKAGE => __PACKAGE__,
  };
  bless($self, $class);
  my $objectManager = Anansi::ObjectManager->new();
  $objectManager->register($self);
  return $self;
 }

 1;


=head1 DESCRIPTION
12345678901234567890123456789012345678901234567890123456789012345678901234567890
This is a manager for encapsulating module objects within other module objects
and ensures that the memory used by any module object will only be garbage
collected by the perl run time environment when the module object is no longer
used.  Many of the subroutines/methods declared by this module are for internal
use only but are provided in this context for purposes of module extension.

=cut


our $VERSION = '0.04';

my $NAMESPACE;

my $OBJECTMANAGER = Anansi::ObjectManager->new();


=head1 METHODS

=cut


=head2 current

 my $someObject = Some::Example->new();
 $someObject->{ANOTHER_OBJECT} = Another::Example->new();
 my $objectManager = Anansi::ObjectManager->new();
 $objectManager->current(
  USER => $someObject,
  USES => $someObject->{ANOTHER_OBJECT},
 );

 # OR

 my $someObject = Some::Example->new();
 $someObject->{ANOTHER_OBJECT} = Another::Example->new();
 $someObject->{YET_ANOTHER_OBJECT} = Yet::Another::Example->new();
 my $objectManager = Anansi::ObjectManager->new();
 $objectManager->current(
  USER => $someObject,
  USES => [$someObject->{ANOTHER_OBJECT}, $someObject->{YET_ANOTHER_OBJECT}],
 );

Ensures that a module object instance is tied to one or more module object
instances to ensure that those object instances are terminated after the tying
object instance.  This allows a tying object to make full use of the tied
objects up to the moment of termination.

=cut


sub current {
    my ($self, %parameters) = @_;
    return if(!defined($parameters{USER}));
    return if(ref($parameters{USER}) =~ /^(|ARRAY|CODE|FORMAT|GLOB|HASH|IO|LVALUE|REF|Regexp|SCALAR|VSTRING)$/i);
    my $user = $parameters{USER};
    return if(!defined($parameters{USES}));
    if(ref($parameters{USES}) =~ /^(|CODE|FORMAT|GLOB|HASH|IO|LVALUE|REF|Regexp|SCALAR|VSTRING)$/i) {
        return;
    } elsif(ref($parameters{USES}) =~ /^ARRAY$/i) {
        $self->register($user) if(!defined($user->{IDENTIFICATION}));
        my $userIndex = $self->identification($user->{IDENTIFICATION});
        if(!defined($userIndex)) {
            $self->register($user);
            $userIndex = $self->identification($user->{IDENTIFICATION});
        }
        my @users = ($userIndex);
        for(my $index = 0; $index < scalar(@users); $index++) {
            for(my $instance = 0; $instance < scalar(@{$self->{IDENTIFICATIONS}}); $instance++) {
                next if($index == $instance);
                next if(!defined($self->{'INSTANCE_'.$users[$index]}->{'USER_'.$instance}));
                next if(!defined($self->{'INSTANCE_'.$instance}));
                my $found;
                for($found = 0; $found < scalar(@users); $found++) {
                    last if($instance == $found);
                }
                push(@users, $instance) if($found == scalar(@users));
            }
        }
        foreach my $uses (@{$parameters{USES}}) {
            next if(ref($uses) =~ /^(|CODE|FORMAT|GLOB|HASH|IO|LVALUE|REF|Regexp|SCALAR|VSTRING)$/i);
            $self->register($uses) if(!defined($uses->{IDENTIFICATION}));
            my $usesIndex = $self->identification($uses->{IDENTIFICATION});
            if(!defined($usesIndex)) {
                $self->register($uses);
                $usesIndex = $self->identification($uses->{IDENTIFICATION});
            }
            if(!defined($uses->{'USER_'.$userIndex})) {
                my $found;
                for($found = 0; $found < scalar(@users); $found++) {
                    last if($usesIndex == $found);
                }
                $uses->{'USER_'.$userIndex} = $user if($found == scalar(@users));
            }
        }
    } else {
        $self->register($user) if(!defined($user->{IDENTIFICATION}));
        my $userIndex = $self->identification($user->{IDENTIFICATION});
        if(!defined($userIndex)) {
            $self->register($user);
            $userIndex = $self->identification($user->{IDENTIFICATION});
        }
        my @users = ($userIndex);
        for(my $index = 0; $index < scalar(@users); $index++) {
            for(my $instance = 0; $instance < scalar(@{$self->{IDENTIFICATIONS}}); $instance++) {
                next if($index == $instance);
                next if(!defined($self->{'INSTANCE_'.$users[$index]}->{'USER_'.$instance}));
                next if(!defined($self->{'INSTANCE_'.$instance}));
                my $found;
                for($found = 0; $found < scalar(@users); $found++) {
                    last if($instance == $found);
                }
                push(@users, $instance) if($found == scalar(@users));
            }
        }
        my $uses = $parameters{USES};
        $self->register($uses) if(!defined($uses->{IDENTIFICATION}));
        my $usesIndex = $self->identification($uses->{IDENTIFICATION});
        if(!defined($usesIndex)) {
            $self->register($uses);
            $usesIndex = $self->identification($uses->{IDENTIFICATION});
        }
        if(!defined($uses->{'USER_'.$userIndex})) {
            my $found;
            for($found = 0; $found < scalar(@users); $found++) {
                last if($usesIndex == $found);
            }
            $uses->{'USER_'.$userIndex} = $user if($found == scalar(@users));
        }
    }
}


=head2 finalise

 package Some::Example;

 use base(Anansi::ObjectManager);

 sub old {
     my ($self, %parameters) = @_;
     $self->finalise();
 }

 1;

Ensures that all of the known object instances are allowed to terminate in
reverse order of dependence.  Indirectly called by the termination of an
instance of this module.

=cut


sub finalise {
    my ($self, %parameters) = @_;
    my $identifications;
    do {
        $identifications = 0;
        for(my $instance = 0; $instance < scalar(@{$self->{IDENTIFICATIONS}}); $instance++) {
            next if(!defined($self->{'INSTANCE_'.$instance}));
            $identifications++;
            my $user;
            for($user = 0; $user < scalar(@{$self->{IDENTIFICATIONS}}); $user++) {
                next if($instance == $user);
                if(defined($self->{'INSTANCE_'.$instance}->{'USER_'.$user})) {
                    next if(undef == $self->{'INSTANCE_'.$instance}->{'USER_'.$user});
                    next if(!defined($self->{'INSTANCE_'.$user}));
                    last;
                }
            }
            if(scalar(@{$self->{IDENTIFICATIONS}}) == $user) {
                $self->{'INSTANCE_'.$instance}->DESTROY();
                if(defined($self->{'INSTANCE_'.$instance})) {
                    delete $self->{'INSTANCE_'.$instance} if(0 == $self->{'INSTANCE_'.$instance}->{REGISTERED});
                }
            }
        }
    } while(0 < $identifications);
}


=head2 identification

 my $someExample = Some::Example->new();
 my $objectManager = Anansi::ObjectManager->new();
 my $identification = $objectManager->identification($someExample);
 if(defined($identification));

 # OR

 my $someExample = Some::Example->new();
 my $objectManager = Anansi::ObjectManager->new();
 my $identification, $index;
 try {
  $identification = $someExample->{IDENTIFICATION};
 }
 $ordinal = $objectManager->identification($identification) if(defined($identification));
 if(defined($ordinal));

Assigns an identifying number to a module object instance as required and either
returns the identifying number or the unique ordinal number of the module object
instance as stored internally by this module.

=cut


sub identification {
    my ($self, $instance) = @_;
    if(!defined($instance)) {
        my ($second, $minute, $hour, $day, $month, $year) = localtime(time);
        my $random;
        my $identification;
        do {
            $random = int(rand(1000000));
            $identification = sprintf("%4d%02d%02d%02d%02d%02d%06d", $year + 1900, $month, $day, $hour, $minute, $second, $random);
        } while(defined($self->identification($identification)));
        return $identification;
    } elsif(ref($instance) =~ /^(CODE|FORMAT|GLOB|HASH|IO|LVALUE|REF|Regexp|SCALAR|VSTRING)$/i) {
        return;
    } elsif(ref($instance) =~ /^$/) {
        return if($instance =~ /^\s*$/);
        return if(!defined($self->{IDENTIFICATIONS}));
        return if(ref($self->{IDENTIFICATIONS}) !~ /^ARRAY$/i);
        for(my $index = 0; $index < scalar(@{$self->{IDENTIFICATIONS}}); $index++) {
            return $index if($instance == @{$self->{IDENTIFICATIONS}}[$index]);
        }
        return;
    } else {
        return if(!defined($instance->{IDENTIFICATION}));
        return if($instance->{IDENTIFICATION} =~ /^\s*$/);
        for(my $index = 0; $index < scalar(@{$self->{IDENTIFICATIONS}}); $index++) {
            return $index if($instance->{IDENTIFICATION} == @{$self->{IDENTIFICATIONS}}[$index]);
        }
        return;
    }
}


=head2 initialise

 package Some::Example;

 use base(Anansi::ObjectManager);

 sub initialise {
  my ($self, %parameters) = @_;
  $self->SUPER::initialise(%parameters);
 }

 1;

Performs after creation actions on the first instance object of this module that
is created.

=cut


sub initialise {
    my ($self, %parameters) = @_;
    $self->{IDENTIFICATION} = $self->identification();
    $self->{IDENTIFICATIONS} = [
        $self->{IDENTIFICATION}
    ];
}


=head2 new

 my $objectManager = Anansi::ObjectManager->new();

Instantiates an object instance of this module, ensuring that the object
instance can be interpreted by this module.

=cut


sub new {
    my ($class, %parameters) = @_;
    return if(ref($class) =~ /^(ARRAY|CODE|FORMAT|GLOB|HASH|IO|LVALUE|REF|Regexp|SCALAR|VSTRING)$/i);
    $class = ref($class) if(ref($class) !~ /^$/);
    if(!defined($NAMESPACE)) {
        my $self = {
            NAMESPACE => $class,
            PACKAGE => __PACKAGE__,
        };
        $NAMESPACE = bless($self, $class);
        $NAMESPACE->initialise(%parameters);
    } else {
        $NAMESPACE->reinitialise(%parameters);
    }
    return $NAMESPACE;
}


=head2 obsolete

 my $someObject = Some::Example->new();
 $someObject->{ANOTHER_OBJECT} = Another::Example->new();
 my $objectManager = Anansi::ObjectManager->new();
 $objectManager->current(
  USER => $someObject,
  USES => $someObject->{ANOTHER_OBJECT},
 );
 # ...
 my $objectManager = Anansi::ObjectManager->new();
 $objectManager->obsolete(
  USER => $someObject,
  USES => $someObject->{ANOTHER_OBJECT},
 );
 delete $someObject->{ANOTHER_OBJECT};

 # OR

 my $someObject = Some::Example->new();
 $someObject->{ANOTHER_OBJECT} = Another::Example->new();
 $someObject->{YET_ANOTHER_OBJECT} = Yet::Another::Example->new();
 my $objectManager = Anansi::ObjectManager->new();
 $objectManager->current(
  USER => $someObject,
  USES => [$someObject->{ANOTHER_OBJECT}, $someObject->{YET_ANOTHER_OBJECT}],
 );
 # ...
 my $objectManager = Anansi::ObjectManager->new();
 $objectManager->obsolete(
  USER => $someObject,
  USES => [$someObject->{ANOTHER_OBJECT}, $someObject->{YET_ANOTHER_OBJECT}],
 );
 delete $someObject->{ANOTHER_OBJECT};
 delete $someObject->{YET_ANOTHER_OBJECT};

Ensures that module object instances that have previously been tied to an object
instance can terminate prior to the termination of the tying object instance.
This allows object instances that are no longer required to be cleaned-up early
by the perl interpreter garbage collection.

=cut


sub obsolete {
    my ($self, %parameters) = @_;
    return if(!defined($parameters{USER}));
    return if(ref($parameters{USER}) =~ /^(|ARRAY|CODE|FORMAT|GLOB|HASH|IO|LVALUE|REF|Regexp|SCALAR|VSTRING)$/i);
    my $user = $parameters{USER};
    return if(!defined($user->{IDENTIFICATION}));
    my $userIndex = $self->identification($user->{IDENTIFICATION});
    return if(!defined($userIndex));
    return if(!defined($self->{'INSTANCE_'.$userIndex}));
    if(!defined($parameters{USES})) {
        for(my $identification = scalar(@{$self->{IDENTIFICATIONS}}) - 1; 0 < $identification; $identification--) {
            next if(!defined($self->{'INSTANCE_'.$identification}));
            if(defined($self->{'INSTANCE_'.$identification}->{'USER_'.$userIndex})) {
                if(!defined($self->{'INSTANCE_'.$identification}->{PACKAGE})) {
                    $self->unregister($self->{'INSTANCE_'.$identification});
                } elsif(ref($self->{'INSTANCE_'.$identification}->{PACKAGE}) !~ /^$/) {
                    $self->unregister($self->{'INSTANCE_'.$identification});
                } elsif($self->{'INSTANCE_'.$identification}->{PACKAGE} !~ /^Anansi::.*$/) {
                    $self->unregister($self->{'INSTANCE_'.$identification});
                }
                $self->{'INSTANCE_'.$identification}->DESTROY();
                if(defined($self->{'INSTANCE_'.$identification})) {
                    delete $self->{'INSTANCE_'.$identification}->{'USER_'.$userIndex} if(defined($self->{'INSTANCE_'.$identification}->{'USER_'.$userIndex}));
                }
            }
        }
    } elsif(ref($parameters{USES}) =~ /^(|CODE|FORMAT|GLOB|HASH|IO|LVALUE|REF|Regexp|SCALAR|VSTRING)$/i) {
        return;
    } elsif(ref($parameters{USES}) =~ /^ARRAY$/i) {
        foreach my $uses (@{$parameters{USES}}) {
            if(ref($uses) =~ /^(CODE|FORMAT|GLOB|HASH|IO|LVALUE|REF|Regexp|SCALAR|VSTRING)$/i) {
                next;
            } elsif(ref($uses) =~ /^$/) {
                my $usesIndex = $self->identification($uses);
                next if(!defined($usesIndex));
                next if(!defined($self->{'INSTANCE_'.$usesIndex}));
                if(defined($self->{'INSTANCE_'.$usesIndex}->{'USER_'.$userIndex})) {
                    if(!defined($self->{'INSTANCE_'.$usesIndex}->{PACKAGE})) {
                        $self->unregister($self->{'INSTANCE_'.$usesIndex});
                    } elsif(ref($self->{'INSTANCE_'.$usesIndex}->{PACKAGE}) !~ /^$/) {
                        $self->unregister($self->{'INSTANCE_'.$usesIndex});
                    } elsif($self->{'INSTANCE_'.$usesIndex}->{PACKAGE} !~ /^Anansi::.*$/) {
                        $self->unregister($self->{'INSTANCE_'.$usesIndex});
                    }
                    $self->{'INSTANCE_'.$usesIndex}->DESTROY();
                    if(defined($self->{'INSTANCE_'.$usesIndex})) {
                        delete $self->{'INSTANCE_'.$usesIndex}->{'USER_'.$userIndex} if(defined($self->{'INSTANCE_'.$usesIndex}->{'USER_'.$userIndex}));
                    }
                }
            } else {
                next if(!defined($uses->{IDENTIFICATION}));
                my $usesIndex = $self->identification($uses->{IDENTIFICATION});
                next if(!defined($usesIndex));
                next if(!defined($self->{'INSTANCE_'.$usesIndex}));
                if(defined($self->{'INSTANCE_'.$usesIndex}->{'USER_'.$userIndex})) {
                    if(!defined($self->{'INSTANCE_'.$usesIndex}->{PACKAGE})) {
                        $self->unregister($self->{'INSTANCE_'.$usesIndex});
                    } elsif(ref($self->{'INSTANCE_'.$usesIndex}->{PACKAGE}) !~ /^$/) {
                        $self->unregister($self->{'INSTANCE_'.$usesIndex});
                    } elsif($self->{'INSTANCE_'.$usesIndex}->{PACKAGE} !~ /^Anansi::.*$/) {
                        $self->unregister($self->{'INSTANCE_'.$usesIndex});
                    }
                    $self->{'INSTANCE_'.$usesIndex}->DESTROY();
                    if(defined($self->{'INSTANCE_'.$usesIndex})) {
                        delete $self->{'INSTANCE_'.$usesIndex}->{'USER_'.$userIndex} if(defined($self->{'INSTANCE_'.$usesIndex}->{'USER_'.$userIndex}));
                    }
                }
            }
        }
    } else {
        my $uses = $parameters{USES};
        return if(!defined($uses->{IDENTIFICATION}));
        my $usesIndex = $self->identification($uses->{IDENTIFICATION});
        return if(!defined($usesIndex));
        if(defined($self->{'INSTANCE_'.$usesIndex}->{'USER_'.$userIndex})) {
            if(!defined($self->{'INSTANCE_'.$usesIndex}->{PACKAGE})) {
                $self->unregister($self->{'INSTANCE_'.$usesIndex});
            } elsif(ref($self->{'INSTANCE_'.$usesIndex}->{PACKAGE}) !~ /^$/) {
                $self->unregister($self->{'INSTANCE_'.$usesIndex});
            } elsif($self->{'INSTANCE_'.$usesIndex}->{PACKAGE} !~ /^Anansi::.*$/) {
                $self->unregister($self->{'INSTANCE_'.$usesIndex});
            }
            $self->{'INSTANCE_'.$usesIndex}->DESTROY();
            if(defined($self->{'INSTANCE_'.$usesIndex})) {
                delete $self->{'INSTANCE_'.$usesIndex}->{'USER_'.$userIndex} if(defined($self->{'INSTANCE_'.$usesIndex}->{'USER_'.$userIndex}));
            }
        }
    }
}


=head2 old

 package Some::Example;

 use base(Anansi::ObjectManager);

 sub old {
  my ($self, %parameters) = @_;
  $self->SUPER::old(%parameters);
 }

 1;

Performs module object instance clean-up actions.

=cut


sub old {
    my ($self, %parameters) = @_;
    $self->finalise(%parameters);
}


=head2 register

 my $someObject = Some::Example->new();
 my $objectManager = Anansi::ObjectManager->new();
 $objectManager->register($someObject);

Ties as required an object instance to this module and increments an internal
counter as to how many times the object instance has been tied.  This ensure
that the perl garbage collection does not remove the object instance from memory
until either the object instance is untied or this module has terminated.

=cut


sub register {
    my ($self, $instance) = @_;
    return 0 if(ref($instance) =~ /^(|ARRAY|CODE|FORMAT|GLOB|HASH|IO|LVALUE|REF|Regexp|SCALAR|VSTRING)$/i);
    if(!defined($instance->{IDENTIFICATION})) {
        $instance->{IDENTIFICATION} = $self->identification();
        push(@{$self->{IDENTIFICATIONS}}, $instance->{IDENTIFICATION});
    }
    my $instanceIndex = $self->identification($instance);
    return 0 if(!defined($instanceIndex));
    $instance->{REGISTERED} = 0 if(!defined($instance->{REGISTERED}));
    $instance->{REGISTERED}++;
    $self->{'INSTANCE_'.$instanceIndex} = $instance if(!defined($self->{'INSTANCE_'.$instanceIndex}));
    return 1;
}


=head2 registrations

 my $someObject = Some::Example->new();
 my $objectManager = Anansi::ObjectManager->new();
 $objectManager->register($someObject);
 # ...
 if(0 < $objectManager->registrations($someObject));

Determines the number of times an object instance has been tied to this module.

=cut


sub registrations {
    my ($self, $instance) = @_;
    return 0 if(ref($instance) =~ /^(|ARRAY|CODE|FORMAT|GLOB|HASH|IO|LVALUE|REF|Regexp|SCALAR|VSTRING)$/i);
    return 0 if(!defined($instance->{IDENTIFICATION}));
    return $instance->{REGISTERED};
}


=head2 reinitialise

 package Some::Example;

 use base(Anansi::ObjectManager);

 sub reinitialise {
  my ($self, %parameters) = @_;
  $self->SUPER::reinitialise(%parameters);
 }

 1;

Performs additional after creation actions on subsequent instance objects of
this module that are created.

=cut


sub reinitialise {
    my ($self, %parameters) = @_;
}


=head2 unregister

 my $someObject = Some::Example->new();
 my $objectManager = Anansi::ObjectManager->new();
 $objectManager->register($someObject);
 # ...
 my $objectManager = Anansi::ObjectManager->new();
 $objectManager->unregister($someObject);

Reduce the number of times an object instance has been tied to this module and
remove the tie that inhibits the perl garbage collection from removing the
object instance from memory if the object instance is no longer tied.

=cut


sub unregister {
    my ($self, $instance) = @_;
    return 1 if(!defined($instance->{IDENTIFICATION}));
    my $instanceIndex = $self->identification($instance);
    return 1 if(!defined($instanceIndex));
    $instance->{REGISTERED}--;
    return 1 if(!defined($self->{'INSTANCE_'.$instanceIndex}));
    if(0 == $instance->{REGISTERED}) {
        for(my $identification = 0; $identification < scalar(@{$self->{IDENTIFICATIONS}}); $identification++) {
            next if($instanceIndex == $identification);
            next if(!defined($self->{'INSTANCE_'.$identification}));
            return 1 if(defined($self->{'INSTANCE_'.$instanceIndex}->{'USER_'.$identification}));
        }
        delete $self->{'INSTANCE_'.$instanceIndex};
    }
    return 1;
}


=head2 user

 my $someObject = Some::Example->new();
 $someObject->{ANOTHER_OBJECT} = Another::Example->new();
 my $objectManager = Anansi::ObjectManager->new();
 $objectManager->current(
  USER => $someObject,
  USES => $someObject->{ANOTHER_OBJECT},
 );
 # ...
 my $userObjects = $objectManager->user($someObject);
 if(defined($userObjects)) {
  foreach my $userObject (@{$userObjects}) {
   # ...
  }
 }

Determine the object instances that are made use of by an object instance.

=cut


sub user {
    my ($self, $instance) = @_;
    return if(ref($instance) =~ /^(|ARRAY|CODE|FORMAT|GLOB|HASH|IO|LVALUE|REF|Regexp|SCALAR|VSTRING)$/i);
    return if(!defined($instance->{IDENTIFICATION}));
    my $instanceIndex = $self->identification($instance);
    return if(!defined($instanceIndex));
    return if(!defined($self->{'INSTANCE_'.$instanceIndex}));
    my @identifications;
    for(my $identification = 0; $identification < scalar(@{$self->{IDENTIFICATIONS}}); $identification++) {
        next if($instanceIndex == $identification);
        push(@identifications, $identification) if(defined($self->{'INSTANCE_'.$instanceIndex}->{'USER_'.$identification}));
    }
    return if(0 == scalar(@identifications));
    return (@identifications);
}


=head2 uses

 my $someObject = Some::Example->new();
 my $anotherObject = Another::Example->new();
 $someObject->{ANOTHER_OBJECT} = $anotherObject;
 my $objectManager = Anansi::ObjectManager->new();
 $objectManager->current(
  USER => $someObject,
  USES => $someObject->{ANOTHER_OBJECT},
 );
 # ...
 my $usesObjects = $objectManager->uses($anotherObject);
 if(defined($usesObjects)) {
  foreach my $usesObject (@{$usesObjects}) {
   # ...
  }
 }

Determine the object instances that an object instance makes use of.

=cut


sub uses {
    my ($self, $instance) = @_;
    return if(ref($instance) =~ /^(|ARRAY|CODE|FORMAT|GLOB|HASH|IO|LVALUE|REF|Regexp|SCALAR|VSTRING)$/i);
    return if(!defined($instance->{IDENTIFICATION}));
    my $instanceIndex = $self->identification($instance);
    return if(!defined($instanceIndex));
    return if(!defined($self->{'INSTANCE_'.$instanceIndex}));
    my @identifications;
    for(my $identification = 0; $identification < scalar(@{$self->{IDENTIFICATIONS}}); $identification++) {
        next if($instanceIndex == $identification);
        next if(!defined($self->{'INSTANCE_'.$identification}));
        push(@identifications, $identification) if(defined($self->{'INSTANCE_'.$identification}->{'USER_'.$instanceIndex}));
    }
    return if(0 == scalar(@identifications));
    return (@identifications);
}


END {
    $OBJECTMANAGER->old() if(defined($OBJECTMANAGER));
}


=head1 AUTHOR

Kevin Treleaven <kevin AT treleaven DOT net>

=cut


1;
