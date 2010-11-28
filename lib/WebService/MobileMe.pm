package WebService::MobileMe;

# ABSTRACT: access MobileMe iPhone stuffs from Perl

use strict;
use warnings;

use JSON 2.00;
use LWP::UserAgent;
use MIME::Base64;
use Data::Dumper;

my %headers = (
    'X-Apple-Find-Api-Ver'  => '2.0',
    'X-Apple-Authscheme'    => 'UserIdGuest',
    'X-Apple-Realm-Support' => '1.0',
    'Content-Type'          => 'application/json; charset=utf-8',
    'Accept-Language'       => 'en-us',
    'Pragma'                => 'no-cache',
    'Connection'            => 'keep-alive',
);

my $default_uuid = '0000000000000000000000000000000000000000';
my $default_name = 'My iPhone';
my $base_url     = 'https://fmipmobile.me.com/fmipservice/device/';

sub new {
    my ( $class, %args ) = @_;
    my $self = {};
    bless $self, $class;

    $self->{debug} = $args{debug} || 0;

    $self->{ua} = LWP::UserAgent->new(
        agent => 'Find iPhone/1.1 MeKit (iPhone: iPhone OS/4.2.1)',
        autocheck => 0,
    );

    $self->{ua}->default_header( 'Authorization' => 'Basic '
            . encode_base64( $args{username} . ':' . $args{password} ) );

    while (my ($header, $value) = each %headers) {
        $self->{ua}->default_header( $header => $value);
    }

    if ( defined( $args{uuid} && $args{device_name} ) ) {
        $self->{uuid}        = $args{uuid};
        $self->{device_name} = $args{device_name};
    }
    else {
        $self->{uuid}        = $default_uuid;
        $self->{device_name} = $default_name;
    }

    $self->{ua}->default_header( 'X-Client-Uuid' => $self->{uuid} );
    $self->{ua}->default_header( 'X-Client-Name' => $self->{device_name} );

    $self->{base_url} = $base_url . $args{username};

    $self->update();

    return $self;

}

sub locate {
    my $self = shift;
    $self->update();
    my $device = $self->device(shift);
    die "Don't have location for device" unless exists $device->{location};
    return $device->{location}
}

sub device {
    my $self = shift;
    my $device_number = shift || 0;
    my $device = $self->{devices}[$device_number];
    die "Didn't find specified device number ( $device_number )" unless $device;
    return $device

}

sub sendMessage {
    my ($self, %args) = @_;
    $args{subject} ||= 'Important Message';
    $args{alarm} = $args{alarm} ? 'true' : 'false';
    die "Must specify message." unless $args{message};
    my $device = $self->device( $args{device} );
    my $post_content = sprintf('{"clientContext":{"appName":"FindMyiPhone","appVersion":"1.0","buildVersion":"57","deviceUDID":"0000000000000000000000000000000000000000","inactiveTime":5911,"osVersion":"3.2","productType":"iPad1,1","selectedDevice":"%s","shouldLocate":false},"device":"%s","serverContext":{"callbackIntervalInMS":3000,"clientId":"0000000000000000000000000000000000000000","deviceLoadStatus":"203","hasDevices":true,"lastSessionExtensionTime":null,"maxDeviceLoadTime":60000,"maxLocatingTime":90000,"preferredLanguage":"en","prefsUpdateTime":1276872996660,"sessionLifespan":900000,"timezone":{"currentOffset":-25200000,"previousOffset":-28800000,"previousTransition":1268560799999,"tzCurrentName":"Pacific Daylight Time","tzName":"America/Los_Angeles"},"validRegion":true},"sound":%s,"subject":"%s","text":"%s"}',
        $device->{id}, $device->{id},
        $args{alarm}, $args{subject}, $args{message}
    );
    return from_json( $self->_post( '/sendMessage', $post_content )->content )->{msg};
}

sub remoteLock {
    my ($self, $passcode, $devicenum) = @_;
    die "Must specify passcode." unless $passcode;
    my $device = $self->device( $devicenum );
    my $post_content = sprintf('{"clientContext":{"appName":"FindMyiPhone","appVersion":"1.0","buildVersion":"57","deviceUDID":"0000000000000000000000000000000000000000","inactiveTime":5911,"osVersion":"3.2","productType":"iPad1,1","selectedDevice":"%s","shouldLocate":false},"device":"%s","oldPasscode":"","passcode":"%s","serverContext":{"callbackIntervalInMS":3000,"clientId":"0000000000000000000000000000000000000000","deviceLoadStatus":"203","hasDevices":true,"lastSessionExtensionTime":null,"maxDeviceLoadTime":60000,"maxLocatingTime":90000,"preferredLanguage":"en","prefsUpdateTime":1276872996660,"sessionLifespan":900000,"timezone":{"currentOffset":-25200000,"previousOffset":-28800000,"previousTransition":1268560799999,"tzCurrentName":"Pacific Daylight Time","tzName":"America/Los_Angeles"},"validRegion":true}}',
        $device->{id}, $device->{id}, $passcode
    );
    return from_json( $self->_post( '/remoteLock', $post_content )->content )->{remoteLock};
}

sub update {
    my $self = shift;
    my $response;

    my $post_content =
        '{"clientContext":{"appName":"FindMyiPhone","appVersion":"1.1","buildVersion":"99","deviceUDID":"'
        . $self->{uuid}
        . '","inactiveTime":2147483647,"osVersion":"4.2.1","personID":0,"productType":"iPhone3,1"}}';
    my $retry = 1;
    while ($retry) {
        $response = $self->_post( '/initClient', $post_content );
        if ($response->code == 330) {
            my $host = $response->headers->header('X-Apple-MME-Host');
            $self->_debug("Updating url to point to $host");
            $self->{base_url} =~ s|https://fmipmobile.me.com|https://$host|;
        }
        else {
            $retry = 0;
        }
    }
    if ($response->code != 200) {
        die "Failed to init, got " . $response->status_line;
    }

    my $data = from_json( $response->content );

    $self->{devices} = $data->{content};
    $self->_debug("In update, found " . scalar (@{$self->{devices}})  . " device(s)");

    return 1;
}

sub _debug {
    print STDERR $_[1] . "\n" if $_[0]->{debug};
}

sub _post {
    my $self = shift;
    return $self->{ua}->post( $self->{base_url} . $_[0], Content => $_[1] );
}

1;

__END__

=pod

=head1 NAME

WebService::MobileMe - access MobileMe iPhone stuffs from Perl

=head1 SYNOPSIS

    use WebService::MobileMe;

    my $mme = WebService::MobileMe->new(
        username => 'urmom@me.com', password => 'HUGELOVE' );
    my $location = $mme->locate;

    $mme->sendMessage( message => 'Hi Yaakov!', alarm => 1 );

    $mme->remoteLock( 42 );

=head1 DESCRIPTION

THIS MODULE THROWS EXCEPTIONS, USE TRY::TINY OR SIMILIAR IF YOU WISH TO CATCH
THEM.

This module is alpha software released under the release early, release sort
of often principle.  It works for me but contains not much error checking yet,
soon to come! (maybe)

This module supports retrieving a latitude/longitude, sending a message, and
remote locking of an iPhone via the 'Find My iPhone' service from Apple's
MobileMe, emulating the Find My iPhone iOS app.

Timestamps returned are those returned in the JSON which are JavaScript
timestamps and thus in miliseconds since the epoch.  Divide by 1000 for
seconds.

=head1 METHODS

=head2 C<new>

    my $mme = new WebService::MobileMe->new(
        username => '', password => '', debug => 1);

Returns a new C<WebService::MobileMe> object. The only arguments
are username and password coresponding to your MobileMe login and debug.

If you have a paid MobileMe account, include the @me.com in the username.

The constructor logs in to Mobile Me and retrieves the currently available
information.  If something fails, it will thow an error.

=head2 C<locate>

    my $location = $mme->locate();

Takes an optional device number, starting at 0.  Returns the raw json parsed
from Apple.

This is currently:

    $location = {
        'horizontalAccuracy' => '10',
        'longitude' => '-74.4966423982358',
        'latitude' => '39.4651979706557',
        'positionType' => 'GPS',
        'timeStamp' => '1290924314359',
        'isOld' => bless( do{\(my $o = 0)}, 'JSON::XS::Boolean' ),
        'locationFinished' => bless( do{\(my $o = 1)}, 'JSON::XS::Boolean' )
    };

NOTE: The timeStamp is a JavaScript timestamp so it is miliseconds since the
epoch.  Divide by 1000 for seconds since.

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

=item * C<device>

The device number on the account to send the message to.  Defaults to 0, the
first device.

=back

The returned structure currently looks like:

    $message = {
        'createTimestamp' => '1290933263675',
        'statusCode' => '200'
    }

=head2 remoteLock

    $mme->remoteLock( 42 );

Sends a remote lock request with the designated passcode.  Optionaly also
takes a device number which defaults to 0, the first device.

The returned structure currently looks like:

    $lock = {
        'createTimestamp' => '1290929589780',
        'statusCode' => '2200'
    }

=head2 device

    my $device = $mme->device()

Takes one optional argument, the device number.  Defaults to device 0, the
first device.  Returns the full structure for the specified device which
currently looks like:

    $device = {
        'a' => 'NotCharging',
        'isLocating' => bless( do{\(my $o = 1)}, 'JSON::XS::Boolean' ),
        'deviceModel' => 'FourthGen',
        'id' => 'deadbeef',
        'remoteLock' => undef,
        'msg' => undef,
        'remoteWipe' => undef,
        'location' => {
             'horizontalAccuracy' => '10',
             'longitude' => '-74.4966423982358',
             'latitude' => '39.4651979706557',
             'positionType' => 'GPS',
             'timeStamp' => '1290924314359',
             'isOld' => bless( do{\(my $o = 0)}, 'JSON::XS::Boolean' ),
             'locationFinished' => $VAR1->{'isLocating'}
        },
        'features' => {
             'KEY' => $VAR1->{'isLocating'},
             'WIP' => $VAR1->{'isLocating'},
             'LCK' => $VAR1->{'isLocating'},
             'SND' => $VAR1->{'isLocating'},
             'LOC' => $VAR1->{'isLocating'},
             'REM' => $VAR1->{'location'}{'isOld'},
             'CWP' => $VAR1->{'location'}{'isOld'},
             'MSG' => $VAR1->{'isLocating'}
        },
        'deviceStatus' => '203',
        'name' => 'mmm cake',
        'thisDevice' => $VAR1->{'location'}{'isOld'},
        'b' => '1',
        'locationEnabled' => $VAR1->{'isLocating'},
        'deviceDisplayName' => 'iPhone 4',
        'deviceClass' => 'iPhone'
    };

remoteWipe, msg, and remoteLock will contain structures similiar to those
returned by the appropriate methods if they have been used in the recent past.
