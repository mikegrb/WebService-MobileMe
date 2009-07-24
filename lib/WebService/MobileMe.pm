package WebService::MobileMe;

# ABSTRACT: access MobileMe iPhone stuffs from Perl

use strict;
use warnings;

use JSON;
use Data::Dumper;
use WWW::Mechanize;

my $accountURL = 'https://secure.me.com/account/';
my $loginURL   = 'https://auth.apple.com/authenticate?service=DockStatus&reauthorize=Y&realm=primary-me&returnURL=&destinationUrl=/account&cancelURL=';
my $webObjects = 'https://secure.me.com/wo/WebObjects/';

sub new {
    my ( $class, %args ) = @_;
    my $self = {};
    bless $self, $class;

    $self->{mech} = WWW::Mechanize->new(
        agent => 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_7; en-us) AppleWebKit/530.18 (KHTML, like Gecko) Version/4.0.1 Safari/530.18',
        autocheck => 0,
    );

    my $r;
    $self->_mech_get($accountURL);
    $self->_mech_get($loginURL);
    $self->{mech}->submit_form(
        form_name => 'LoginForm',
        fields =>
            { username => $args{username}, password => $args{password} },
    );

    ( my $query_string = $self->{mech}->uri ) =~ s/^[^?]*\?//;
    $self->_mech_get(
        $webObjects . 'DockStatus.woa/wa/trampoline?' . $query_string );
    $self->_mech_get($accountURL);
    $self->_mech_get_js( $webObjects . 'DeviceMgmt.woa/?lang=en' );

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

    return $self;
}

sub locate {
    my ($self, $device_number) = @_;

    my %device = %{ $self->{devices}[ $device_number || 0 ] };
    my %req = (
        deviceId        => $device{deviceId},
        deviceOsVersion => $device{deviceOsVersion} );

    $self->_mech_post_js(
        $webObjects . 'DeviceMgmt.woa/wa/LocateAction/locateStatus',
        { postBody => to_json( \%req ) } );

    return from_json( $self->{mech}->content );
}

sub sendMessage {
    my ( $self, $message, $alarm, $device_number ) = @_;

    my %device = %{ $self->{devices}[ $device_number || 0 ] };
    my %req = (
        deviceId        => $device{deviceId},
        message         => $message,
        playAlarm       => $alarm ? 'Y' : 'N',
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
    my %lsc;
    $self->{mech}->cookie_jar->scan(
        sub {
            my @cookie = @_;
            if ( $cookie[1] =~ /^[li]sc-(.*?)$/ ) {
                $lsc{$1} = $cookie[2];
            }
        } );
    $self->{lsc} = \%lsc;
    return;
}

1;

__END__

=pod

=head1 NAME

WebService::MobileMe - access MobileMe (in particular FindMyIphone) from Perl

=head1 DESCRIPTION

Fer doin' stuff with MobileMe
