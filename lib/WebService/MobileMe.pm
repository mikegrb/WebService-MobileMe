package WebService::MobileMe;

# ABSTRACT: access MobileMe iPhone stuffs from Perl

use strict;
use warnings;

use JSON 2.00;
use WWW::Mechanize;

my $accountURL = 'https://secure.me.com/account/';
my $loginURL   = 'https://auth.me.com/authenticate?service=account&ssoNamespace=primary-me&reauthorize=Y&returnURL=aHR0cHM6Ly9zZWN1cmUubWUuY29tL2FjY291bnQvI2ZpbmRteWlwaG9uZQ==&anchor=findmyiphone';
my $webObjects = 'https://secure.me.com/wo/WebObjects/';

sub new {
    my ( $class, %args ) = @_;
    my $self = {};
    bless $self, $class;
    $self->{lsc} = {};

    $self->{mech} = WWW::Mechanize->new(
        agent => 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_1; en-us) AppleWebKit/531.9 (KHTML, like Gecko) Version/4.0.3 Safari/531.9',
        autocheck => 0,
    );

    $self->_mech_get($loginURL);
    $self->{mech}->submit_form(
        form_name => 'LoginForm',
        fields =>
            { username => $args{username}, password => $args{password} },
    );

    $self->_mech_get($accountURL);
    $self->_mech_get(
        $webObjects . 'Account2.woa?lang=en&anchor=findmyiphone',
        'X-Mobileme-Version' => '1.0' );
    $self->_mech_post_js( $webObjects . 'DeviceMgmt.woa/?lang=en', undef );

    # TODO:  multi device support
    $self->{devices} = [];
    if ( $self->{mech}->content =~ m/new Device\((.*?)\)/ ) {
        ( my $data = $1 ) =~ s/'//g;
        my ( $unknown, $id, $type, $class, $os ) = split ', ', $data;
        push @{ $self->{devices} },
            {
            deviceId        => $id,
            deviceType      => $type,
            deviceClass     => $class,
            deviceOsVersion => $os
            };
    }
    else {
        warn "Didn't find new Device\n";
        return;
    }

    return $self;
}

sub locate {
    my ($self, $device_number) = @_;

    return unless exists $self->{devices};

    my %device = %{ $self->{devices}[ $device_number || 0 ] };
    my %req = (
        deviceId        => $device{deviceId},
        deviceOsVersion => $device{deviceOsVersion} );

    $self->_mech_post_js(
        $webObjects . 'DeviceMgmt.woa/wa/LocateAction/locateStatus',
        { postBody => to_json( \%req ) } );

    my $data;
    eval { $data = from_json( $self->{mech}->content )};
    return if $@;
    return $data;
}

sub sendMessage {
    my ( $self, %args ) = @_;

    my %device = %{ $self->{devices}[ $args{device_number} || 0 ] };
    my %req = (
        deviceId        => $device{deviceId},
        message         => $args{message},
        playAlarm       => $args{alarm} ? 'Y' : 'N',
        deviceType      => $device{deviceType},
        deviceClass     => $device{deviceClass},
        deviceOsVersion => $device{deviceOsVersion} );

    $self->_mech_post_js(
        $webObjects . 'DeviceMgmt.woa/wa/SendMessageAction/sendMessage',
        { postBody => to_json( \%req ) } );

    return from_json( $self->{mech}->content );
}

sub _mech_get {
    my ( $self, $url, @args ) = @_;
    my $r = $self->{mech}->get( $url, @args );
    $self->_get_auth_tokens;
    return $r;
}

sub _mech_post_js {
    my ( $self, $url, $content, @args ) = @_;
    push @args, $self->_js_headers;
    my $r = $self->{mech}->post( $url, Content => $content, @args );
    $self->_get_auth_tokens;
    return $r;
}

sub _mech_get_js {
    my ( $self, $url, @args ) = @_;
    push @args, $self->_js_headers;
    return $self->_mech_get( $url, @args );
}

sub _js_headers {
    my $self = shift;
    return (
        'Accept' =>
            'text/javascript, text/html, application/xml, text/xml, */*',
        'X-Requested-With'    => 'XMLHttpRequest',
        'X-Prototype-Version' => '1.6.0.3',
        'X-Mobileme-Version'  => '1.0',
        'X-Mobileme-Isc'      => $self->{lsc}{'secure.me.com'} );
}

sub _get_auth_tokens {
    my $self = shift;
    $self->{mech}->cookie_jar->scan(
        sub {
            my @cookie = @_;
            if ( $cookie[1] =~ /^[li]sc-(.*?)$/ ) {
                $self->{lsc}{$1} = $cookie[2];
            }
        } );
    return;
}

1;

__END__

=pod

=head1 NAME

WebService::MobileMe - access MobileMe iPhone stuffs from Perl

=head1 SYNOPSIS

    use WebService::MobileMe;

    my $mme = WebService::MobileMe->new(
        username => 'yaakov', password => 'HUGELOVE' );
    my $location = $mme->locate;
    print <<"EOT";
        As of $location->{date}, $location->{time}, Yaakov was at
        $location->{latitude}, $location->{longitude} (plus or minus
        $location->{accuracy} meters).
    EOT
    $mme->sendMessage( message => 'Hi Yaakov!', alarm => 1 );

=head1 DESCRIPTION

This module is alpha software released under the release early, release sort
of often principle.  It works for me but contains no error checking yet, soon
to come!

This module supports retrieving a latitude/longitude, and sending a message
to an iPhone via the 'Find My iPhone' service from Apple's MobileMe,
emulating the AJAX browser client.

=head1 METHODS

=head2 C<new>

    my $mme = new WebService::MobileMe->new(
        username => '', password => '');

Returns a new C<WebService::MobileMe> object. Currently the only arguments
are username and password, coresponding to your MobileMe login.

The constructor logs in to Mobile Me and retrieves the first device on the
account, storing it for use in the other methods.  If something fails, it
will return undef.

=head2 C<locate>

    my $location = $mme->locate();

Takes no arguments, returns a referrence to a hash of the information
returned by Apple.

This is currently:

    $location = {
        'isAccurate' => bless( do{\(my $o = 0)}, 'JSON::PP::Boolean' ),
        'longitude' => '-74.51767',
        'isRecent' => bless( do{\(my $o = 1)}, 'JSON::PP::Boolean' ),
        'date' => 'July 24, 2009',
        'status' => 1,
        'time' => '10:39 AM',
        'isLocationAvailable' => $VAR1->{'isRecent'},
        'statusString' => 'locate status available',
        'isLocateFinished' => $VAR1->{'isAccurate'},
        'isOldLocationResult' => $VAR1->{'isRecent'},
        'latitude' => '39.437691',
        'accuracy' => '323.239746'
    };

=head2 sendMessage

    my $r = $mme->sendMessage( message => 'Hello, World!', alarm => 1);

Takes one required and three optional arguments.  Returns a structure
containg the parsed JSON returned by apple

=over 4

=item * C<message> (REQUIRED)

The message to display.

=item * C<alarm>

A true value cause the iPhone to make noise when the message is displayed,
defaults to false.

=item * C<device_number>

The device number on the account to send the message to.  Defaults to 0, the
first device.  Only the first device is currently captured after logging in.

=back

The returned structure currently looks like:

    $r = {
        'unacknowledgedMessagePending' => 
            bless( do{\(my $o = 1)}, 'JSON::PP::Boolean' ),
        'date' => 'July 24, 2009',
        'status' => 1,
        'time' => '11:11 AM',
        'statusString' => 'message sent'
    };