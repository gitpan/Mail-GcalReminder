use Test::More;
use Test::Deep;
use Net::Detect;

if ( detect_net() ) {
    plan tests => 7;
}
else {
    plan skip_all => 'These tests require an internet connection.';
}

use Mail::GcalReminder;

diag("Testing Mail::GcalReminder $Mail::GcalReminder::VERSION");

my $gcr = Mail::GcalReminder->new( gmail_user => 'me@example.com', gmail_pass => "this_is_a_terrible_password" );

#### get_gcal ##

# Has one-time and recurring events, has me@example.com and "You Self" <you@example.com> as guests
#   public XML : https://www.google.com/calendar/feeds/6qrhpfk1utcs97g9u2o27g5ojo%40group.calendar.google.com/public/basic
#   private XML: https://www.google.com/calendar/feeds/6qrhpfk1utcs97g9u2o27g5ojo%40group.calendar.google.com/private-a6689d558b4dbba8942e510985b604d3/basic
my $pub_xml_gcal  = '6qrhpfk1utcs97g9u2o27g5ojo%40group.calendar.google.com/public';
my $priv_xml_gcal = '6qrhpfk1utcs97g9u2o27g5ojo%40group.calendar.google.com/private-a6689d558b4dbba8942e510985b604d3';

$gcr->base_date( DateTime->new( month => 1, day => 21, year => 1986, time_zone => 'America/Chicago' ) );

# diag($gcr->base_date);

my $priv_cal = $gcr->get_gcal($priv_xml_gcal);

# diag( explain($priv_cal) );

is( ref($priv_cal), 'HASH', 'get_gcal() returns hash' );
is( $priv_cal, $gcr->get_gcal($priv_xml_gcal), 'gcal is cached from first call on' );

my $pub_cal      = $gcr->get_gcal($pub_xml_gcal);
my $priv_trg_ref = _get_target_datastruct($priv_xml_gcal);
my $pub_trg_ref  = _get_target_datastruct($pub_xml_gcal);

# use Devel::Kit::TAP; d( [ sort keys %{$priv_cal} ], [ sort keys %{$priv_trg_ref} ] );

cmp_deeply( $priv_cal, $priv_trg_ref, 'gcal data struct - private' );
cmp_deeply( $pub_cal,  $pub_trg_ref,  'gcal data struct - public' );

$gcr->gcal_cache( {} );
$gcr->include_event_dt_obj(1);
my $pub = $gcr->get_gcal($pub_xml_gcal);
ok( exists $pub->{'Tue Feb 11'}[0]{'event_dt_obj'}, 'event_dt_obj exists when include_event_dt_obj is true' );
isa_ok( $pub->{'Tue Feb 11'}[0]{'event_dt_obj'}, 'DateTime', 'event_dt_obj is a DateTime object' );
is( "$pub->{'Tue Feb 11'}[0]{'event_dt_obj'}", '1986-02-11T11:00:00', 'event_dt_obj is as expected' );

sub _get_target_datastruct {
    my ($gcal) = @_;

    my $public = $gcal =~ m{group\.calendar\.google\.com/private-} ? 0 : 1;

    my $gcal_uri = "http://www.google.com/calendar/feeds/$gcal/basic?orderby=starttime&sortorder=a&start-min=1986-01-21&start-max=1986-03-04&max-results=100&singleevents=true";

    return {
        'Tue Feb 11' => [
            {
                'date'              => 'Tue Feb 11',
                'gcal_entry_obj'    => code( sub { ref( $_[0] ) eq 'HASH' } ),
                'gcal_title'        => 'Test Calendar',
                'gcal_updated'      => re(qr/^\d+\-\d+\-\d+T\d+:\d+:\d+\.000Z$/),
                'gcal_updated_date' => re(qr/^\w+ \w+ \d+$/),
                'gcal_uri'          => re(qr{http://www\.google\.com/calendar/feeds/6qrhpfk1utcs97g9u2o27g5ojo%40group\.calendar\.google\.com}),
                'guests'            => $public ? []
                : [
                    'you@example.com',
                    'me@example.com'
                ],
                'location' => '',
                'time'     => '11:00 AM',
                'title'    => 'Recurring Limited - Start',
                'desc'     => undef(),
                'url'      => 'http://www.google.com/calendar/event?eid=MnFmNXI2ODdkajJ1MG43OWJrdmZlam9rNGdfMTk4NjAyMTFUMTcwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                'year'     => '1986'
            },
            {
                'date'              => 'Tue Feb 11',
                'gcal_entry_obj'    => code( sub { ref( $_[0] ) eq 'HASH' } ),
                'gcal_title'        => 'Test Calendar',
                'gcal_updated'      => re(qr/^\d+\-\d+\-\d+T\d+:\d+:\d+\.000Z$/),
                'gcal_updated_date' => re(qr/^\w+ \w+ \d+$/),
                'gcal_uri'          => re(qr{http://www\.google\.com/calendar/feeds/6qrhpfk1utcs97g9u2o27g5ojo%40group\.calendar\.google\.com}),
                'guests'            => $public ? []
                : [
                    'you@example.com',
                    'me@example.com'
                ],
                'location' => '',
                'time'     => '7:00 PM',
                'title'    => 'Recurring Forever Test',
                'desc'     => undef(),
                'url'      => 'http://www.google.com/calendar/event?eid=NWlxanF2dThiajNoMG9xbDhlaTQ1MjZqNG9fMTk4NjAyMTJUMDEwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                'year'     => '1986'
            }
        ],
        'Tue Feb 18' => [
            {
                'date'              => 'Tue Feb 18',
                'gcal_entry_obj'    => code( sub { ref( $_[0] ) eq 'HASH' } ),
                'gcal_title'        => 'Test Calendar',
                'gcal_updated'      => re(qr/^\d+\-\d+\-\d+T\d+:\d+:\d+\.000Z$/),
                'gcal_updated_date' => re(qr/^\w+ \w+ \d+$/),
                'gcal_uri'          => re(qr{http://www\.google\.com/calendar/feeds/6qrhpfk1utcs97g9u2o27g5ojo%40group\.calendar\.google\.com}),
                'guests'            => $public ? []
                : [
                    'you@example.com',
                    'me@example.com'
                ],
                'location' => '',
                'time'     => '7:00 PM',
                'title'    => 'Recurring Forever Test',
                'desc'     => undef(),
                'url'      => 'http://www.google.com/calendar/event?eid=NWlxanF2dThiajNoMG9xbDhlaTQ1MjZqNG9fMTk4NjAyMTlUMDEwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                'year'     => '1986'
            }
        ],
        'Tue Feb 25' => [
            {
                'date'              => 'Tue Feb 25',
                'gcal_entry_obj'    => code( sub { ref( $_[0] ) eq 'HASH' } ),
                'gcal_title'        => 'Test Calendar',
                'gcal_updated'      => re(qr/^\d+\-\d+\-\d+T\d+:\d+:\d+\.000Z$/),
                'gcal_updated_date' => re(qr/^\w+ \w+ \d+$/),
                'gcal_uri'          => re(qr{http://www\.google\.com/calendar/feeds/6qrhpfk1utcs97g9u2o27g5ojo%40group\.calendar\.google\.com}),
                'guests'            => $public ? []
                : [
                    'you@example.com',
                    'me@example.com'
                ],
                'location' => '',
                'time'     => '7:00 PM',
                'title'    => 'Recurring Forever Test',
                'desc'     => undef(),
                'url'      => 'http://www.google.com/calendar/event?eid=NWlxanF2dThiajNoMG9xbDhlaTQ1MjZqNG9fMTk4NjAyMjZUMDEwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                'year'     => '1986'
            }
        ],
        'Tue Feb 4' => [
            {
                'date'              => 'Tue Feb 4',
                'gcal_entry_obj'    => code( sub { ref( $_[0] ) eq 'HASH' } ),
                'gcal_title'        => 'Test Calendar',
                'gcal_updated'      => re(qr/^\d+\-\d+\-\d+T\d+:\d+:\d+\.000Z$/),
                'gcal_updated_date' => re(qr/^\w+ \w+ \d+$/),
                'gcal_uri'          => re(qr{http://www\.google\.com/calendar/feeds/6qrhpfk1utcs97g9u2o27g5ojo%40group\.calendar\.google\.com}),
                'guests'            => $public ? []
                : [
                    'you@example.com',
                    'me@example.com'
                ],
                'location' => '',
                'time'     => '10:00 AM',
                'title'    => 'Recurring Limited - Middle',
                'desc'     => 'Recurring Limited - Middle Desc',
                'url'      => 'http://www.google.com/calendar/event?eid=MXYxYTlyNGFlaGw4YjVkNG1iMDBrcjY2djBfMTk4NjAyMDRUMTYwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                'year'     => '1986'
            },
            {
                'date'              => 'Tue Feb 4',
                'gcal_entry_obj'    => code( sub { ref( $_[0] ) eq 'HASH' } ),
                'gcal_title'        => 'Test Calendar',
                'gcal_updated'      => re(qr/^\d+\-\d+\-\d+T\d+:\d+:\d+\.000Z$/),
                'gcal_updated_date' => re(qr/^\w+ \w+ \d+$/),
                'gcal_uri'          => re(qr{http://www\.google\.com/calendar/feeds/6qrhpfk1utcs97g9u2o27g5ojo%40group\.calendar\.google\.com}),
                'guests'            => $public ? []
                : [
                    'you@example.com',
                    'me@example.com'
                ],
                'location' => '',
                'time'     => '11:00 AM',
                'title'    => 'Recurring Limited - Start',
                'desc'     => undef(),
                'url'      => 'http://www.google.com/calendar/event?eid=MnFmNXI2ODdkajJ1MG43OWJrdmZlam9rNGdfMTk4NjAyMDRUMTcwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                'year'     => '1986'
            },
            {
                'date'              => 'Tue Feb 4',
                'gcal_entry_obj'    => code( sub { ref( $_[0] ) eq 'HASH' } ),
                'gcal_title'        => 'Test Calendar',
                'gcal_updated'      => re(qr/^\d+\-\d+\-\d+T\d+:\d+:\d+\.000Z$/),
                'gcal_updated_date' => re(qr/^\w+ \w+ \d+$/),
                'gcal_uri'          => re(qr{http://www\.google\.com/calendar/feeds/6qrhpfk1utcs97g9u2o27g5ojo%40group\.calendar\.google\.com}),
                'guests'            => $public ? []
                : [
                    'you@example.com',
                    'me@example.com'
                ],
                'location' => '',
                'time'     => '7:00 PM',
                'title'    => 'Recurring Forever Test',
                'desc'     => undef(),
                'url'      => 'http://www.google.com/calendar/event?eid=NWlxanF2dThiajNoMG9xbDhlaTQ1MjZqNG9fMTk4NjAyMDVUMDEwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                'year'     => '1986'
            }
        ],
        'Tue Jan 21' => [
            {
                'date'              => 'Tue Jan 21',
                'gcal_entry_obj'    => code( sub { ref( $_[0] ) eq 'HASH' } ),
                'gcal_title'        => 'Test Calendar',
                'gcal_updated'      => re(qr/^\d+\-\d+\-\d+T\d+:\d+:\d+\.000Z$/),
                'gcal_updated_date' => re(qr/^\w+ \w+ \d+$/),
                'gcal_uri'          => re(qr{http://www\.google\.com/calendar/feeds/6qrhpfk1utcs97g9u2o27g5ojo%40group\.calendar\.google\.com}),
                'guests'            => $public ? []
                : [
                    'you@example.com',
                    'me@example.com'
                ],
                'location' => '',
                'time'     => '9:00 AM',
                'title'    => 'Recurring Limited - End',
                'desc'     => 'Recurring Limited - End Desc',
                'url'      => 'http://www.google.com/calendar/event?eid=cmFrMjhkbGZza25xamczNzEzYjkwMWVkamdfMTk4NjAxMjFUMTUwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                'year'     => '1986'
            },
            {
                'date'              => 'Tue Jan 21',
                'gcal_entry_obj'    => code( sub { ref( $_[0] ) eq 'HASH' } ),
                'gcal_title'        => 'Test Calendar',
                'gcal_updated'      => re(qr/^\d+\-\d+\-\d+T\d+:\d+:\d+\.000Z$/),
                'gcal_updated_date' => re(qr/^\w+ \w+ \d+$/),
                'gcal_uri'          => re(qr{http://www\.google\.com/calendar/feeds/6qrhpfk1utcs97g9u2o27g5ojo%40group\.calendar\.google\.com}),
                'guests'            => $public ? []
                : [
                    'you@example.com',
                    'me@example.com'
                ],
                'location' => '',
                'time'     => '10:00 AM',
                'title'    => 'Recurring Limited - Middle',
                'desc'     => 'Recurring Limited - Middle Desc',
                'url'      => 'http://www.google.com/calendar/event?eid=MXYxYTlyNGFlaGw4YjVkNG1iMDBrcjY2djBfMTk4NjAxMjFUMTYwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                'year'     => '1986'
            },
            {
                'date'              => 'Tue Jan 21',
                'gcal_entry_obj'    => code( sub { ref( $_[0] ) eq 'HASH' } ),
                'gcal_title'        => 'Test Calendar',
                'gcal_updated'      => re(qr/^\d+\-\d+\-\d+T\d+:\d+:\d+\.000Z$/),
                'gcal_updated_date' => re(qr/^\w+ \w+ \d+$/),
                'gcal_uri'          => re(qr{http://www\.google\.com/calendar/feeds/6qrhpfk1utcs97g9u2o27g5ojo%40group\.calendar\.google\.com}),
                'guests'            => $public ? []
                : [
                    'you@example.com',
                    'me@example.com'
                ],
                'location' => '',
                'time'     => '7:00 PM',
                'title'    => 'Recurring Forever Test',
                'desc'     => undef(),
                'url'      => 'http://www.google.com/calendar/event?eid=NWlxanF2dThiajNoMG9xbDhlaTQ1MjZqNG9fMTk4NjAxMjJUMDEwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                'year'     => '1986'
            }
        ],
        'Tue Jan 28' => [
            {
                'date'              => 'Tue Jan 28',
                'gcal_entry_obj'    => code( sub { ref( $_[0] ) eq 'HASH' } ),
                'gcal_title'        => 'Test Calendar',
                'gcal_updated'      => re(qr/^\d+\-\d+\-\d+T\d+:\d+:\d+\.000Z$/),
                'gcal_updated_date' => re(qr/^\w+ \w+ \d+$/),
                'gcal_uri'          => re(qr{http://www\.google\.com/calendar/feeds/6qrhpfk1utcs97g9u2o27g5ojo%40group\.calendar\.google\.com}),
                'guests'            => $public ? []
                : [
                    'you@example.com',
                    'me@example.com'
                ],
                'location' => '',
                'time'     => '9:00 AM',
                'title'    => 'Recurring Limited - End',
                'desc'     => 'Recurring Limited - End Desc',
                'url'      => 'http://www.google.com/calendar/event?eid=cmFrMjhkbGZza25xamczNzEzYjkwMWVkamdfMTk4NjAxMjhUMTUwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                'year'     => '1986'
            },
            {
                'date'              => 'Tue Jan 28',
                'gcal_entry_obj'    => code( sub { ref( $_[0] ) eq 'HASH' } ),
                'gcal_title'        => 'Test Calendar',
                'gcal_updated'      => re(qr/^\d+\-\d+\-\d+T\d+:\d+:\d+\.000Z$/),
                'gcal_updated_date' => re(qr/^\w+ \w+ \d+$/),
                'gcal_uri'          => re(qr{http://www\.google\.com/calendar/feeds/6qrhpfk1utcs97g9u2o27g5ojo%40group\.calendar\.google\.com}),
                'guests'            => $public ? []
                : [
                    'you@example.com',
                    'me@example.com'
                ],
                'location' => '',
                'time'     => '10:00 AM',
                'title'    => 'Recurring Limited - Middle',
                'desc'     => 'Recurring Limited - Middle Desc',
                'url'      => 'http://www.google.com/calendar/event?eid=MXYxYTlyNGFlaGw4YjVkNG1iMDBrcjY2djBfMTk4NjAxMjhUMTYwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                'year'     => '1986'
            },
            {
                'date'              => 'Tue Jan 28',
                'gcal_entry_obj'    => code( sub { ref( $_[0] ) eq 'HASH' } ),
                'gcal_title'        => 'Test Calendar',
                'gcal_updated'      => re(qr/^\d+\-\d+\-\d+T\d+:\d+:\d+\.000Z$/),
                'gcal_updated_date' => re(qr/^\w+ \w+ \d+$/),
                'gcal_uri'          => re(qr{http://www\.google\.com/calendar/feeds/6qrhpfk1utcs97g9u2o27g5ojo%40group\.calendar\.google\.com}),
                'guests'            => $public ? []
                : [
                    'you@example.com',
                    'me@example.com'
                ],
                'location' => '',
                'time'     => '10:38 AM',
                'title'    => 'Space Shuttle Challenger STS-51-L',
                'desc'     => undef(),
                'url'      => 'http://www.google.com/calendar/event?eid=MjhhcTBwYXBnajVkY2o4NGxsY2dlaW9sbXMgNnFyaHBmazF1dGNzOTdnOXUybzI3ZzVvam9AZw',
                'year'     => '1986'
            },
            {
                'date'              => 'Tue Jan 28',
                'gcal_entry_obj'    => code( sub { ref( $_[0] ) eq 'HASH' } ),
                'gcal_title'        => 'Test Calendar',
                'gcal_updated'      => re(qr/^\d+\-\d+\-\d+T\d+:\d+:\d+\.000Z$/),
                'gcal_updated_date' => re(qr/^\w+ \w+ \d+$/),
                'gcal_uri'          => re(qr{http://www\.google\.com/calendar/feeds/6qrhpfk1utcs97g9u2o27g5ojo%40group\.calendar\.google\.com}),
                'guests'            => $public ? []
                : [
                    'you@example.com',
                    'me@example.com'
                ],
                'location' => '',
                'time'     => '11:00 AM',
                'title'    => 'Recurring Limited - Start',
                'desc'     => undef(),
                'url'      => 'http://www.google.com/calendar/event?eid=MnFmNXI2ODdkajJ1MG43OWJrdmZlam9rNGdfMTk4NjAxMjhUMTcwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                'year'     => '1986'
            },
            {
                'date'              => 'Tue Jan 28',
                'gcal_entry_obj'    => code( sub { ref( $_[0] ) eq 'HASH' } ),
                'gcal_title'        => 'Test Calendar',
                'gcal_updated'      => re(qr/^\d+\-\d+\-\d+T\d+:\d+:\d+\.000Z$/),
                'gcal_updated_date' => re(qr/^\w+ \w+ \d+$/),
                'gcal_uri'          => re(qr{http://www\.google\.com/calendar/feeds/6qrhpfk1utcs97g9u2o27g5ojo%40group\.calendar\.google\.com}),
                'guests'            => $public ? []
                : [
                    'you@example.com',
                    'me@example.com'
                ],
                'location' => '',
                'time'     => '7:00 PM',
                'title'    => 'Recurring Forever Test',
                'desc'     => undef(),
                'url'      => 'http://www.google.com/calendar/event?eid=NWlxanF2dThiajNoMG9xbDhlaTQ1MjZqNG9fMTk4NjAxMjlUMDEwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                'year'     => '1986'
            }
        ]
    };
}
