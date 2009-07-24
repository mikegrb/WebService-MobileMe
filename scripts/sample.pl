#!/usr/bin/perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Data::Dumper;
use WebService::MobileMe;

my $mme = WebService::MobileMe->new(username => 'yaakov', password=>'mikegrbistseksi');
print Dumper($mme->locate);
print Dumper($mme->sendMessage(message => 'urmom likes messages from me', alarm => 1));

# $VAR1 = {
#           'isAccurate' => bless( do{\(my $o = 0)}, 'JSON::PP::Boolean' ),
#           'longitude' => '-74.51767',
#           'isRecent' => bless( do{\(my $o = 1)}, 'JSON::PP::Boolean' ),
#           'date' => 'July 24, 2009',
#           'status' => 1,
#           'time' => '10:39 AM',
#           'isLocationAvailable' => $VAR1->{'isRecent'},
#           'statusString' => 'locate status available',
#           'isLocateFinished' => $VAR1->{'isAccurate'},
#           'isOldLocationResult' => $VAR1->{'isRecent'},
#           'latitude' => '39.437691',
#           'accuracy' => '323.239746'
#         };
# $VAR1 = {
#           'unacknowledgedMessagePending' => bless( do{\(my $o = 1)}, 'JSON::PP::Boolean' ),
#           'date' => 'July 24, 2009',
#           'status' => 1,
#           'time' => '11:11 AM',
#           'statusString' => 'message sent'
#         };