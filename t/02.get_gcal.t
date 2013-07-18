use Test::More;
use Net::Detect;

if ( detect_net() ) {
    plan tests => 4;
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
my $priv_trg_ref = _get_target_datastruct( $priv_xml_gcal, 0 );
my $pub_trg_ref  = _get_target_datastruct( $pub_xml_gcal, 1 );
is_deeply( _deeplyfy_res( $priv_cal, 0 ), $priv_trg_ref, 'gcal data struct - private' );
is_deeply( _deeplyfy_res( $pub_cal,  1 ), $pub_trg_ref,  'gcal data struct - public' );

sub _deeplyfy_res {
    my ( $struct, $public ) = @_;

    for my $date ( keys %{$struct} ) {
        for my $event ( @{ $struct->{$date} } ) {
            for my $k ( keys %{$event} ) {
                if ( $public && $k eq 'guests' ) {
                    $event->{$k} = [];
                }

                if ( $k eq 'gcal_updated' ) {
                    $event->{$k} = 'date: normalized so calendar updates woudl not require new version of module just to get this test working';
                }

                if ( ref( $event->{$k} ) eq 'XML::Atom::Entry' ) {
                    $event->{$k} = 'event obj: XML::Atom::Entry';    # already done in _get_target_datastruct(), no-op there
                }
            }
        }
    }

    return $struct;
}

sub _get_target_datastruct {
    my ($gcal) = @_;

    my $public = $gcal =~ m{group\.calendar\.google\.com/private-} ? 0 : 1;

    my $gcal_uri_ref = "http://www.google.com/calendar/feeds/$gcal/basic?orderby=starttime&sortorder=a&start-min=1986-01-21&start-max=1986-03-04&max-results=100&singleevents=true";

    return _deeplyfy_res(
        {
            'Tue Feb 11' => [
                {
                    'date'              => 'Tue Feb 11',
                    'gcal_entry_obj'    => 'event obj: XML::Atom::Entry',
                    'gcal_title'        => 'Test Calendar',
                    'gcal_updated'      => '2013-04-21T03:58:13.000Z',
                    'gcal_updated_date' => 'Thu Jul 11',
                    'gcal_uri'          => $gcal_uri_ref,
                    'guests'            => [
                        'you@example.com',
                        'me@example.com'
                    ],
                    'time'  => '11am',
                    'title' => 'Recurring Limited - Start',
                    'url'   => 'http://www.google.com/calendar/event?eid=MnFmNXI2ODdkajJ1MG43OWJrdmZlam9rNGdfMTk4NjAyMTFUMTcwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                    'year'  => '1986'
                },
                {
                    'date'              => 'Tue Feb 11',
                    'gcal_entry_obj'    => 'event obj: XML::Atom::Entry',
                    'gcal_title'        => 'Test Calendar',
                    'gcal_updated'      => '2013-04-21T03:58:13.000Z',
                    'gcal_updated_date' => 'Thu Jul 11',
                    'gcal_uri'          => $gcal_uri_ref,
                    'guests'            => [
                        'you@example.com',
                        'me@example.com'
                    ],
                    'time'  => '7pm',
                    'title' => 'Recurring Forever Test',
                    'url'   => 'http://www.google.com/calendar/event?eid=NWlxanF2dThiajNoMG9xbDhlaTQ1MjZqNG9fMTk4NjAyMTJUMDEwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                    'year'  => '1986'
                }
            ],
            'Tue Feb 18' => [
                {
                    'date'              => 'Tue Feb 18',
                    'gcal_entry_obj'    => 'event obj: XML::Atom::Entry',
                    'gcal_title'        => 'Test Calendar',
                    'gcal_updated'      => '2013-04-21T03:58:13.000Z',
                    'gcal_updated_date' => 'Thu Jul 11',
                    'gcal_uri'          => $gcal_uri_ref,
                    'guests'            => [
                        'you@example.com',
                        'me@example.com'
                    ],
                    'time'  => '7pm',
                    'title' => 'Recurring Forever Test',
                    'url'   => 'http://www.google.com/calendar/event?eid=NWlxanF2dThiajNoMG9xbDhlaTQ1MjZqNG9fMTk4NjAyMTlUMDEwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                    'year'  => '1986'
                }
            ],
            'Tue Feb 25' => [
                {
                    'date'              => 'Tue Feb 25',
                    'gcal_entry_obj'    => 'event obj: XML::Atom::Entry',
                    'gcal_title'        => 'Test Calendar',
                    'gcal_updated'      => '2013-04-21T03:58:13.000Z',
                    'gcal_updated_date' => 'Thu Jul 11',
                    'gcal_uri'          => $gcal_uri_ref,
                    'guests'            => [
                        'you@example.com',
                        'me@example.com'
                    ],
                    'time'  => '7pm',
                    'title' => 'Recurring Forever Test',
                    'url'   => 'http://www.google.com/calendar/event?eid=NWlxanF2dThiajNoMG9xbDhlaTQ1MjZqNG9fMTk4NjAyMjZUMDEwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                    'year'  => '1986'
                }
            ],
            'Tue Feb 4' => [
                {
                    'date'              => 'Tue Feb 4',
                    'gcal_entry_obj'    => 'event obj: XML::Atom::Entry',
                    'gcal_title'        => 'Test Calendar',
                    'gcal_updated'      => '2013-04-21T03:58:13.000Z',
                    'gcal_updated_date' => 'Thu Jul 11',
                    'gcal_uri'          => $gcal_uri_ref,
                    'guests'            => [
                        'you@example.com',
                        'me@example.com'
                    ],
                    'time'  => '10am',
                    'title' => 'Recurring Limited - Middle',
                    'url'   => 'http://www.google.com/calendar/event?eid=MXYxYTlyNGFlaGw4YjVkNG1iMDBrcjY2djBfMTk4NjAyMDRUMTYwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                    'year'  => '1986'
                },
                {
                    'date'              => 'Tue Feb 4',
                    'gcal_entry_obj'    => 'event obj: XML::Atom::Entry',
                    'gcal_title'        => 'Test Calendar',
                    'gcal_updated'      => '2013-04-21T03:58:13.000Z',
                    'gcal_updated_date' => 'Thu Jul 11',
                    'gcal_uri'          => $gcal_uri_ref,
                    'guests'            => [
                        'you@example.com',
                        'me@example.com'
                    ],
                    'time'  => '11am',
                    'title' => 'Recurring Limited - Start',
                    'url'   => 'http://www.google.com/calendar/event?eid=MnFmNXI2ODdkajJ1MG43OWJrdmZlam9rNGdfMTk4NjAyMDRUMTcwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                    'year'  => '1986'
                },
                {
                    'date'              => 'Tue Feb 4',
                    'gcal_entry_obj'    => 'event obj: XML::Atom::Entry',
                    'gcal_title'        => 'Test Calendar',
                    'gcal_updated'      => '2013-04-21T03:58:13.000Z',
                    'gcal_updated_date' => 'Thu Jul 11',
                    'gcal_uri'          => $gcal_uri_ref,
                    'guests'            => [
                        'you@example.com',
                        'me@example.com'
                    ],
                    'time'  => '7pm',
                    'title' => 'Recurring Forever Test',
                    'url'   => 'http://www.google.com/calendar/event?eid=NWlxanF2dThiajNoMG9xbDhlaTQ1MjZqNG9fMTk4NjAyMDVUMDEwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                    'year'  => '1986'
                }
            ],
            'Tue Jan 21' => [
                {
                    'date'              => 'Tue Jan 21',
                    'gcal_entry_obj'    => 'event obj: XML::Atom::Entry',
                    'gcal_title'        => 'Test Calendar',
                    'gcal_updated'      => '2013-04-21T03:58:13.000Z',
                    'gcal_updated_date' => 'Thu Jul 11',
                    'gcal_uri'          => $gcal_uri_ref,
                    'guests'            => [
                        'you@example.com',
                        'me@example.com'
                    ],
                    'time'  => '9am',
                    'title' => 'Recurring Limited - End',
                    'url'   => 'http://www.google.com/calendar/event?eid=cmFrMjhkbGZza25xamczNzEzYjkwMWVkamdfMTk4NjAxMjFUMTUwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                    'year'  => '1986'
                },
                {
                    'date'              => 'Tue Jan 21',
                    'gcal_entry_obj'    => 'event obj: XML::Atom::Entry',
                    'gcal_title'        => 'Test Calendar',
                    'gcal_updated'      => '2013-04-21T03:58:13.000Z',
                    'gcal_updated_date' => 'Thu Jul 11',
                    'gcal_uri'          => $gcal_uri_ref,
                    'guests'            => [
                        'you@example.com',
                        'me@example.com'
                    ],
                    'time'  => '10am',
                    'title' => 'Recurring Limited - Middle',
                    'url'   => 'http://www.google.com/calendar/event?eid=MXYxYTlyNGFlaGw4YjVkNG1iMDBrcjY2djBfMTk4NjAxMjFUMTYwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                    'year'  => '1986'
                },
                {
                    'date'              => 'Tue Jan 21',
                    'gcal_entry_obj'    => 'event obj: XML::Atom::Entry',
                    'gcal_title'        => 'Test Calendar',
                    'gcal_updated'      => '2013-04-21T03:58:13.000Z',
                    'gcal_updated_date' => 'Thu Jul 11',
                    'gcal_uri'          => $gcal_uri_ref,
                    'guests'            => [
                        'you@example.com',
                        'me@example.com'
                    ],
                    'time'  => '7pm',
                    'title' => 'Recurring Forever Test',
                    'url'   => 'http://www.google.com/calendar/event?eid=NWlxanF2dThiajNoMG9xbDhlaTQ1MjZqNG9fMTk4NjAxMjJUMDEwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                    'year'  => '1986'
                }
            ],
            'Tue Jan 28' => [
                {
                    'date'              => 'Tue Jan 28',
                    'gcal_entry_obj'    => 'event obj: XML::Atom::Entry',
                    'gcal_title'        => 'Test Calendar',
                    'gcal_updated'      => '2013-04-21T03:58:13.000Z',
                    'gcal_updated_date' => 'Thu Jul 11',
                    'gcal_uri'          => $gcal_uri_ref,
                    'guests'            => [
                        'you@example.com',
                        'me@example.com'
                    ],
                    'time'  => '9am',
                    'title' => 'Recurring Limited - End',
                    'url'   => 'http://www.google.com/calendar/event?eid=cmFrMjhkbGZza25xamczNzEzYjkwMWVkamdfMTk4NjAxMjhUMTUwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                    'year'  => '1986'
                },
                {
                    'date'              => 'Tue Jan 28',
                    'gcal_entry_obj'    => 'event obj: XML::Atom::Entry',
                    'gcal_title'        => 'Test Calendar',
                    'gcal_updated'      => '2013-04-21T03:58:13.000Z',
                    'gcal_updated_date' => 'Thu Jul 11',
                    'gcal_uri'          => $gcal_uri_ref,
                    'guests'            => [
                        'you@example.com',
                        'me@example.com'
                    ],
                    'time'  => '10am',
                    'title' => 'Recurring Limited - Middle',
                    'url'   => 'http://www.google.com/calendar/event?eid=MXYxYTlyNGFlaGw4YjVkNG1iMDBrcjY2djBfMTk4NjAxMjhUMTYwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                    'year'  => '1986'
                },
                {
                    'date'              => 'Tue Jan 28',
                    'gcal_entry_obj'    => 'event obj: XML::Atom::Entry',
                    'gcal_title'        => 'Test Calendar',
                    'gcal_updated'      => '2013-04-21T03:58:13.000Z',
                    'gcal_updated_date' => 'Thu Jul 11',
                    'gcal_uri'          => $gcal_uri_ref,
                    'guests'            => [
                        'you@example.com',
                        'me@example.com'
                    ],
                    'time'  => '10:38am',
                    'title' => 'Space Shuttle Challenger STS-51-L',
                    'url'   => 'http://www.google.com/calendar/event?eid=MjhhcTBwYXBnajVkY2o4NGxsY2dlaW9sbXMgNnFyaHBmazF1dGNzOTdnOXUybzI3ZzVvam9AZw',
                    'year'  => '1986'
                },
                {
                    'date'              => 'Tue Jan 28',
                    'gcal_entry_obj'    => 'event obj: XML::Atom::Entry',
                    'gcal_title'        => 'Test Calendar',
                    'gcal_updated'      => '2013-04-21T03:58:13.000Z',
                    'gcal_updated_date' => 'Thu Jul 11',
                    'gcal_uri'          => $gcal_uri_ref,
                    'guests'            => [
                        'you@example.com',
                        'me@example.com'
                    ],
                    'time'  => '11am',
                    'title' => 'Recurring Limited - Start',
                    'url'   => 'http://www.google.com/calendar/event?eid=MnFmNXI2ODdkajJ1MG43OWJrdmZlam9rNGdfMTk4NjAxMjhUMTcwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                    'year'  => '1986'
                },
                {
                    'date'              => 'Tue Jan 28',
                    'gcal_entry_obj'    => 'event obj: XML::Atom::Entry',
                    'gcal_title'        => 'Test Calendar',
                    'gcal_updated'      => '2013-04-21T03:58:13.000Z',
                    'gcal_updated_date' => 'Thu Jul 11',
                    'gcal_uri'          => $gcal_uri_ref,
                    'guests'            => [
                        'you@example.com',
                        'me@example.com'
                    ],
                    'time'  => '7pm',
                    'title' => 'Recurring Forever Test',
                    'url'   => 'http://www.google.com/calendar/event?eid=NWlxanF2dThiajNoMG9xbDhlaTQ1MjZqNG9fMTk4NjAxMjlUMDEwMDAwWiA2cXJocGZrMXV0Y3M5N2c5dTJvMjdnNW9qb0Bn',
                    'year'  => '1986'
                }
            ]
        },
        $public
    );
}
