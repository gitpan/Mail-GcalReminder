package Mail::GcalReminder;

## no critic (RequireUseStrict) - Moo does strict
use Moo;

with 'Role::Multiton::New';

use Email::Send::SMTP::Gmail ();
use URI                      ();
use XML::Atom::Feed          ();
use HTML::Entities           ();

our $VERSION = '0.2';

has gmail_user => ( is => 'rw', required => 1 );

has gmail_pass => ( is => 'rw', required => 1 );

has app_name => ( is => 'rw', lazy => 1, builder => 1 );

sub _build_app_name { return $_[0]->gmail_user . ' (' . __PACKAGE__ . ')' }

has time_zone => (
    is      => 'rw',
    default => sub { 'UTC' },
    isa     => sub {
        require DateTime::TimeZone;
        my $tz;
        eval { $tz = DateTime::TimeZone->new( name => $_[0] ) };
        die "DateTime::TimeZone does not recognize the given name" unless $tz;
    }
);

has cc_self => ( is => 'rw', default => sub { 1 } );

has try_receipts => ( is => 'rw', default => sub { 1 } );

has try_priority => ( is => 'rw', default => sub { 1 } );

has no_guests_is_ok => ( is => 'rw', default => sub { 1 } );

has include_event_dt_obj => ( is => 'rw', default => sub { 0 } );

has base_date => (
    is        => 'rw',
    'lazy'    => 1,
    'default' => sub {
        require DateTime;
        return DateTime->now( time_zone => $_[0]->time_zone );
    },
    'isa' => sub { die "only DateTime objects are supported" unless ref( $_[0] ) eq 'DateTime' },
);

has essg_hax_ver => ( is => 'rw', 'default' => sub { 0.82 } );

has warning_code => (
    is        => 'rw',
    'default' => sub {
        require Carp;
        return sub {
            shift;
            local $Carp::CarpLevel += 1;
            goto &Carp::carp;
          }
    }
);

sub warning {
    my ( $self, @args ) = @_;
    $self->warning_code->( $self, @args );
}

has date_format_obj => (
    is        => 'ro',
    'lazy'    => 1,
    'default' => sub {
        require DateTime::Format::Atom;
        return DateTime::Format::Atom->new();
    },
);

has signature => ( is => 'rw', lazy => 1, builder => 1 );

sub _build_signature {
    return "\n\n--\n" . $_[0]->app_name . "\n\nNote: Please ensure mail from “" . $_[0]->gmail_user . "” is not being filtered out of your inbox.";
}

has debug => ( is => 'rw', default => sub { 0 } );

has gcal_cache => ( is => 'rw', default => sub { {} }, isa => sub { die "gcal_cache must be a hashref" unless ref( $_[0] ) eq 'HASH' } );

my %mmm_name_to_n = (
    'Jan' => 1,
    'Feb' => 2,
    'Mar' => 3,
    'Apr' => 4,
    'May' => 5,
    'Jun' => 6,
    'Jul' => 7,
    'Aug' => 8,
    'Sep' => 9,
    'Oct' => 10,
    'Nov' => 11,
    'Dec' => 12,
);

# TODO: clear_gcal() ?
sub get_gcal {
    my ( $self, $gcal ) = @_;
    my $cache = $self->gcal_cache();

    if ( !exists $cache->{$gcal} ) {

        my $q_end = $self->base_date->clone;
        $q_end->add( days => 42 );    # TODO: start-max via object

        my $query_string = 'orderby=starttime&sortorder=a&start-min=' . $self->base_date->format_cldr('yyyy-MM-dd') . '&start-max=' . $q_end->format_cldr('yyyy-MM-dd') . '&max-results=100';    # TODO: max via object

        my $single_event = 1;                                                                                                                                                                    # ? DO THIS ALL THE TIME?
        my $addt = $single_event ? '&singleevents=true' : '';

        my $uri = URI->new("http://www.google.com/calendar/feeds/$gcal/basic?$query_string$addt") || die "URI object fail: http://www.google.com/calendar/feeds/$gcal/basic?$query_string";
        local $ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;

        my $feed = XML::Atom::Feed->new($uri) || die XML::Atom::Feed->errstr() . " ($uri)";

        # my $datetime_obj = ;

        my %feed;

        if ( $self->include_event_dt_obj ) {
            require DateTime;
        }

        for my $entry ( $feed->entries() ) {
            my $summary = $entry->summary();

            my ($_dt) = split /\<br\s*\/?\>/i, $summary;
            $_dt =~ s/\&nbsp\;[\n\r]*/ /g;    # this is nbsp char
            my ( $date, $year, $time ) = $_dt =~ m/^\s*when\:\s*([^,]+)\s*\,\s*(\d+)\s*(\S+)?/i;

            if ( !$date ) {
                $self->warning("Could not parse date from summary: $_dt\n\tOrig: $summary");
                next;
            }

            # next unless exists $target_dates{$date};

            $time ||= '???';

            my $event_dt_obj;
            if ( $self->include_event_dt_obj ) {
                my ( $dw, $mon, $day ) = split( /\s+/, $date );
                my $mon_n = $mmm_name_to_n{$mon};
                $event_dt_obj = DateTime->new( year => $year, month => $mon_n, day => $day, hour => 0, minute => 1, second => 0, time_zone => $self->time_zone );
            }

            my ($who) = $summary =~ m/Who:(.*)\n/;
            $who ||= '';
            my @who = map {
                my $w = $_;
                $w =~ s/\A\s+//g;
                $w =~ s/\s+\z//g;
                $w !~ m/\@/ ? () : $w;
            } split( /,/, $who );

            my $desc = $entry->content || 'Thanks!';
            $desc = $desc->body if ref($desc);
            $desc ||= 'Thanks!';    # in case ->body resets it
            $desc = undef() if defined $desc && $desc !~ m/Event Description: /ms;
            if ( defined $desc ) {
                $desc =~ s/.*Event Description: //ms;
                $desc = HTML::Entities::decode_entities($desc);
            }

            push @{ $feed{$date} }, {
                'title' => HTML::Entities::decode_entities( $entry->title() ),
                'desc'  => $desc,
                'url'   => $entry->link()->href(),
                'date'  => $date,
                'year'  => $year,
                'time'  => $time,
                ( defined $event_dt_obj ? ( 'event_dt_obj' => $event_dt_obj ) : () ),

                # TODO: 'where'             => $where,
                'guests'            => \@who,
                'gcal_title'        => $feed->title(),
                'gcal_uri'          => $uri,
                'gcal_entry_obj'    => $entry,
                'gcal_updated'      => $feed->updated(),
                'gcal_updated_date' => $self->date_format_obj->parse_datetime( $feed->updated() )->format_cldr("E MMM d"),
            };
        }

        $cache->{$gcal} = \%feed;
    }

    return $cache->{$gcal};
}

sub send_reminders {
    my ( $self, $conf ) = @_;

    my $gcal = $self->get_gcal( $conf->{'gcal'} );
    my $name = $conf->{'label'} || $conf->{'gcal'};

    my $target = $self->base_date->clone();
    $target->add( @{ $conf->{'in_advance'} } );
    my $target_str = $target->format_cldr("E MMM d");

    return "0E0" if !exists $gcal->{$target_str} || !@{ $gcal->{$target_str} };    # no events that day

    my $event_cnt = @{ $gcal->{$target_str} };

    if ( $conf->{'min_events'} && $event_cnt < $conf->{'min_events'} ) {
        $self->warning("Not enough events (min $conf->{'min_events'}, actual $event_cnt) for “$name”.");
    }

    if ( $conf->{'max_events'} && $event_cnt > $conf->{'max_events'} ) {
        $self->warning("Too many events (max $conf->{'max_events'}, actual $event_cnt) for “$name”.");
    }

    # ? TODO ? warning() if $conf->{'max_events'} < $conf->{'min_events'}

    my $count = 0;
    for my $event ( @{ $gcal->{$target_str} } ) {
        my @guests = $event->{'guests'} ? @{ $event->{'guests'} } : ();
        @guests = $conf->{'guestcheck'}->( $self, @guests ) if ref( $conf->{'guestcheck'} ) eq 'CODE';

        if (@guests) {
            my $guests_cnt = @guests;
            if ( $conf->{'min_guests'} && @guests < $conf->{'min_guests'} ) {
                $self->warning("Not enough guests (min $conf->{'min_guests'}, actual $guests_cnt) for “$event->{'title'}”.");
            }

            if ( $conf->{'max_guests'} && @guests > $conf->{'max_guests'} ) {
                $self->warning("Too many guests (max $conf->{'max_guests'}, actual $guests_cnt) for “$event->{'title'}”.");
            }

            # ? TODO ? warning() if $conf->{'max_guests'} < $conf->{'min_guests'}

            my $to = join( ',', @guests );
            my $subject = ref( $conf->{'subject'} ) eq 'CODE' ? $conf->{'subject'}->( $self, $event ) : $conf->{'subject'};    # || ? TODO, default/warning/both ?
            my $body = ref( $conf->{'body'} ) eq 'CODE' ? $conf->{'body'}->( $self, $event ) : $conf->{'body'};                # || ? TODO, default/warning/both ?

            $count++ if $self->send_gmail( $to, $subject, $body );
        }
        else {
            $self->warning("No guests for “$event->{'title'}”.");
            $count++ if $self->no_guests_is_ok;
        }
    }

    return unless $count == @{ $gcal->{$target_str} };
    return $count;
}

sub send_gmail {
    my ( $self, $to, $subject, $body ) = @_;

    eval {
        my $charset = 'UTF-8';

        # have to verify this still works as new versions come out
        # Email::Send::SMTP::Gmail -charset 'bugure' header injection:
        if ( $Email::Send::SMTP::Gmail::VERSION <= $self->essg_hax_ver ) {
            if ( $self->try_receipts || $self->try_priority ) {

                # end charset header
                $charset .= "\n";

                if ( $self->try_priority ) {

                    # flag as important to help them see it:
                    $charset .= "X-Priority: 1\n";
                    $charset .= "Priority: Urgent\n";
                    $charset .= "Importance: high";             # !! no newline !! (\n is appended to -charset call in Email::Send::SMTP::Gmail)
                    $charset .= "\n" if $self->try_receipts;    # so we can continue the hack
                }

                if ( $self->try_receipts ) {

                    # at least try to get some response:
                    $charset .= "X-Confirm-Reading-To: " . $self->gmail_user . "\n";
                    $charset .= "Return-Receipt-To: " . $self->gmail_user . "\n";
                    $charset .= "Disposition-Notification-To: " . $self->gmail_user;    # !! no newline !! (\n is appended to -charset call in Email::Send::SMTP::Gmail)
                }
            }
        }
        else {
            if ( $self->try_receipts || $self->try_priority ) {
                my $essg_hax_ver = $self->essg_hax_ver;
                $self->warning("Email::Send::SMTP::Gmail is newer than $essg_hax_ver, skipping header-via-charset hack");
            }
        }

        my $mail = Email::Send::SMTP::Gmail->new(
            '-smtp'  => 'smtp.gmail.com',
            '-login' => $self->{'gmail_user'},
            '-pass'  => $self->{'gmail_pass'},
        );

        $mail->send(
            '-to' => ( $self->debug ? $self->gmail_user : $to ),
            '-from' => $self->gmail_user,
            ( $self->cc_self ? ( '-cc' => $self->gmail_user ) : () ),
            '-subject' => $subject,
            '-charset' => $charset,
            '-verbose' => $self->debug,
            '-body'    => $body . $self->signature,
        );

        $@ = $@;    # send() is eval()

        $mail->bye;
    };

    if ($@) {
        $self->warning($@);
        return;
    }

    return 1;
}

1;

__END__

=encoding utf-8

=head1 NAME

Mail::GcalReminder - Send reminders to Google calendar event guests

=head1 VERSION

This document describes Mail::GcalReminder version 0.2

=head1 SYNOPSIS

    use Mail::GcalReminder;

    my $gcr = Mail::GcalReminder->new(
        'gmail_user' => "…@gmail.com",
        'gmail_pass' => "…", # !!!! chmod 700 !!
        'app_name' => 'Acme Co, Auto Notifier',
    );

    $gcr->send_reminders({
        'gcal' => '…%40group.calendar.google.com/private-…', # !!!! chmod 700 !!
        'in_advance' => ['weeks' => 1],
        'min_events' => 1,
        'max_events' => 1,
        'subject' => "[thing schedule] 1 week reminder for you thing",
        'body' => 'Be there or be square! Call me if you have questions: 867-5309.',
    });

    $gcr->send_reminders({
        'gcal' => '…%40group.calendar.google.com/private-…', # !!!! chmod 700 !!
        'in_advance' => ['weeks' => 5],
        'min_events' => 1,
        'max_events' => 1,
        'subject' => sub {
            my ($self,$event) = @_;
            …
            return "[thing schedule] 5 week heads up for you $event->{'title'}";
        },
        'body' => sub {
            my ($self,$event) = @_;
            …
            return 'All details are in the calendar, see you in five weeks!';
       },
    });

Now simply cron that to run everyday at, say, 4am (to avoid DST blackouts) and you're done! Any problems are output as messages and will come into your cron email.

    0 4 * * * /home/me/send_talk_reminders.pl

=head1 DESCRIPTION

You can set gmail to send you reminders for stuff in your calendar but you can’t have it send reminders to guests.

This module allows you to create scripts that grab a goodle calendar and send reminders to guests from your gmail account.

=head1 INTERFACE

=head2 new() attribute/get-set methods

=over 4

=item * gmail_user (required in new)

Your Gmail account user.

=item * gmail_pass (required in new)

Your Gmail account password. For security, you should protect your script (e.g. chmod 700).

=item * app_name

A name to use in the default signature().

Defaults to: $gcr->gmail_user (__PACKAGE__)

=item * cc_self

Boolean, default 1, CC gmail_user() on each email sent.

=item * try_receipts

Boolean, default 1, try to do read receipts for each email sent.

=item * try_priority

Boolean, default 1, try to do read receipts for each email sent.

=item * no_guests_is_ok

Boolean, default 1, if an event has no guests do not count it as a failure in send_reminders(). You still get a “No guests” warning().

=item * base_date

A date time object, default DateTime->now( time_zone => $gcal->time_zone ), to base 'in_advance' on.

=item * time_zone

Time zone to use in default 'base_date' and the event_dt_obj object.

Defaults to UTC. Value given must be sutiable for DateTime::TimeZone->new’s name attribute.

=item * include_event_dt_obj

Boolean, default 1, calculate and include the key event_dt_obj in the “hashref of event details”

=item * essg_hax_ver

Mostly internal, identifies a module version that we've tested a certain header behavior on, this is mostly for testing and to flag us down when the module is updated.

=item * warning_code

This is a code ref that is executed by warning(). The default it is a carp() with the proper level set.

=item * date_format_obj

Can not be set. Returns the object that can parse ataom format date strings.

=item * signature

Message to append to the email body.

Default is:

    $body

    --
    $gcr->app_name

    Note: Please ensure mail from “$gcr->gmail_user” is not being filtered out of your inbox.

=item * debug

Boolean, default 0, enables debug mode which makes things more verbose and uses gmail_user() for “to” instead of guests.

=item * gcal_cache

A hashref that contains a cache of fetched and parsed calendars. We cache so we can send different reminders (e.g. 1 week and 5 week) on the same calendar and only download and parse it once.

=back

=head2 methods

=head3 send_reminders({…})

This sends reminders per the configuration hashref you pass in (described below).

Returns zero-but-true when there are no applicable events.

Returns the event count if all were successfully sent messages (or there were any with no guests but you've considered it ok via $gcal->no_guests_is_ok()).

Returns false otherwise. Specific messages are given to $gcal->warning().

The send_reminders() configuration hashref has the following keys:

=over 4

=item 'gcal'

The calendar whose events you are interested in.

The value is part of the XML (under “Calendar Details” in your google calendar UI).

Take the URL and remove 'https://www.google.com/calendar/feeds/' from the beggining and '/basic' from the end.

B<For example>:

If your public XML URL is: https://www.google.com/calendar/feeds/6qrhpfk1utcs97g9u2o27g5ojo%40group.calendar.google.com/public/basic

Then the value to 'gcal' is: 6qrhpfk1utcs97g9u2o27g5ojo%40group.calendar.google.com/public

If your private XML URL is: https://www.google.com/calendar/feeds/6qrhpfk1utcs97g9u2o27g5ojo%40group.calendar.google.com/private-a6689d558b4dbba8942e510985b604d3/basic

Then the value to 'gcal' is: 6qrhpfk1utcs97g9u2o27g5ojo%40group.calendar.google.com/private-a6689d558b4dbba8942e510985b604d3';

I<Note>: The public URL does not include guests in the data so you should probably use the private URL (or 'guestcheck' to get a list via other means). For security, you should protect your script (e.g. chmod 700).

=item 'label'

Name to use in messages, defaults to 'gcal'.

=item 'in_advance'

This is how we find the events we are interested in. If your your base_date is the default and you are sending remionders for 1 week 'in_advance' then any events 7 days from right now are what we are looking for.

The value is an array ref of arguments sutiable for DateTime’s add method.

=item 'subject'

The subject of the reminder email. Either a UTF-8 string or a coderef that takes the main object and a hashref of event details (described under get_gcal()) as its arguments and returns the string.

=item 'body'

The body of the reminder email. Either a UTF-8 string or a coderef that takes the main object and a hashref of event details (described under get_gcal()) as its arguments and returns the string.

=item 'min_events'

Optional. The minimum number of events that should be on a given day if there are any.

=item 'max_events'

Optional. The maximum number of events that should be on a given day if there are any.

=item 'min_guests'

Optional. The minimum number of guests that an event is expected to have.

=item 'max_guests'

Optional. The maximum number of guests that an event is expected to have.

=item 'guestcheck'

Optional. A coderef that takes the main object and then any event guests as it args, does whatever you want (e.g. check that the guest is in your database and warning() otherwise, filter out certain ones, include others, etc), and returns the guest list you want to use.

=back

Other methods that exist to support send_reminders():

=over 4

=item * get_gcal($gcal)

Fetch, parse, and cache the given google calendar. Argument is the same as set_reminder’s 'gcal' key. Returns the cached hashref of event details for the given google calendar.

The “hashref of event details” has the following keys:

=over 4

=item 'title'

Name of the event.

=item 'desc'

Description of event. This is undef if there is no description.

=item 'url'

URL of the event.

=item 'date'

Stringified month and day of the event.

=item 'year'

Year of the event.

=item 'time'

Time of the event.

=item 'guests'

An array ref of event guests.

=item event_dt_obj

This will exist if $gcr->include_event_dt_obj is true. It is a L<DateTime> object of the event’s date (time one minute past midnight). The time zone is $gcr->time_zone

=item 'gcal_title'

Title of the calendar.

=item 'gcal_uri'

URL of the calendar.

=item 'gcal_entry_obj'

The events’s L<XML::Atom::Entry> object.

=item 'gcal_updated'

Raw date the calendar was last updated.

=item 'gcal_updated_date'

Formatted date the calendar was last updated.

=back

=item * warning("message goes here\n");

Handle the given message. set via warning_code().

=item * send_gmail($to,$subject,$body);

Send an email from gmail_users() account. Returns true on success. If it fails the error is sent to warning() and it returns false.

=back

=head1 DIAGNOSTICS

All messages are sent to $gcr->warnings().

=over

=item C<< Not enough events (min %d, actual %d) for “%s”. >>

=item C<< Too many events (max %d, actual %d) for “%s”. >>

=item C<< Not enough guests (min %d, actual %d) for “%s”. >>

=item C<< Too many guests (max %d, actual %d) for “%s”. >>

=item C<< No guests for “%s”. >>

=item C<< Could not parse date from summary: %s\nOrig: %s >>

=item C<< Email::Send::SMTP::Gmail is newer than %gcr->essg_hax_ver, skipping header-via-charset hack >>

=back

Errors beyond those are not directly from this module.

=head1 DEPENDENCIES

L<Moo>

L<Email::Send::SMTP::Gmail>

L<URI>

L<XML::Atom::Feed>

L<HTML::Entities>

L<DateTime>

L<Carp>

L<DateTime::Format::Atom>

For Testing: L<Test::More>, L<Net::Detect>, L<Test::Warn>

=head1 TODO

Support and/or outline how a config file might be used to various advantages.

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-mail-gcalreminder@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 AUTHOR

Daniel Muey  C<< <http://drmuey.com/cpan_contact.pl> >>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2013, Daniel Muey C<< <http://drmuey.com/cpan_contact.pl> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
