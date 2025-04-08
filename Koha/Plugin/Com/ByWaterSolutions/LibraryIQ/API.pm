package Koha::Plugin::Com::ByWaterSolutions::LibraryIQ::API;

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';

use Try::Tiny;

=head1 API

=cut

sub records_full {
    warn "Koha::Plugin::Com::ByWaterSolutions::LibraryIQ::API::records_full";
    my $c = shift->openapi->valid_input or return;

    return try {

        my $query = q{
SELECT b.biblionumber,
       bi.isbn,
       bi.itemtype,
       b.title,
       b.author,
       copyrightdate,
       publishercode
FROM   biblio b
       JOIN biblioitems bi
         ON bi.biblionumber = b.biblionumber  
        };

        my $dbh = C4::Context->dbh;
        my $sth = $dbh->prepare($query);
        $sth->execute();

        my @columns = ( 'biblio number','isbn','item type','title','author','copyright date', 'publisher code' );
        my $tsv = join("\t", @columns) . "\n";

        while (my @row = $sth->fetchrow_array) {
            $tsv .= join("\t", @row) . "\n";
        }

        return $c->render( status => 200, format => "text", text => $tsv );
    } catch {
        $c->unhandled_exception($_);
    };
}

sub records_delta {
    warn "Koha::Plugin::Com::ByWaterSolutions::LibraryIQ::API::records_delta";
    my $c = shift->openapi->valid_input or return;

    return try {

        my $query = q{
SELECT b.biblionumber,
       bi.isbn,
       bi.itemtype,
       b.title,
       b.author,
       copyrightdate,
       publishercode
FROM   biblio b
       JOIN biblioitems bi
         ON bi.biblionumber = b.biblionumber
WHERE  b.timestamp > Now() - INTERVAL 3 day  
        };

        my $dbh = C4::Context->dbh;
        my $sth = $dbh->prepare($query);
        $sth->execute();

        my @columns = ( 'biblio number','isbn','item type','title','author','copyright date', 'publisher code' );
        my $tsv = join("\t", @columns) . "\n";

        while (my @row = $sth->fetchrow_array) {
            $tsv .= join("\t", @row) . "\n";
        }

        return $c->render( status => 200, format => "text", text => $tsv );
    } catch {
        $c->unhandled_exception($_);
    };
}

sub items_full {
    warn "Koha::Plugin::Com::ByWaterSolutions::LibraryIQ::API::items_full";
    my $c = shift->openapi->valid_input or return;

    return try {

        my $query = q{
 SELECT i.itemnumber,
       i.barcode,
       i.biblionumber,
       isbn,
       i.ccode,
       i.itype,
       i.holdingbranch,
       i.homebranch,
       itemcfullnumber,
       i.location,
       dateaccessioned,
       i.notforloan,
       i.damaged,
       i.itemlost,
       i.withdrawn,
       bt.tobranch,
       r.found,
       i.datelastborrowed,
       i.onloan,
       (SELECT Count(*)
        FROM   statistics s
        WHERE  s.type IN ( 'issue', 'renew' )
               AND i.itemnumber = s.itemnumber
               AND Date(s.datetime) >= Concat( Date_format( Last_day( Now() - INTERVAL 1 month), '%Y-' ), '01-01') ) AS YTD,
       i.issues + Ifnull(i.renewals, 0) AS lifetime
FROM   items i
       JOIN biblioitems bi
         ON i.biblionumber = bi.biblionumber
       LEFT JOIN branchtransfers bt
              ON bt.itemnumber = i.itemnumber
                 AND bt.datesent IS NOT NULL
                 AND bt.datearrived IS NULL
       LEFT JOIN reserves r
              ON r.itemnumber = i.itemnumber
       LEFT JOIN authorised_values a
              ON a.authorised_value = i.ccode
                 AND a.category = 'CCODE'
       LEFT JOIN authorised_values a2
              ON a2.authorised_value = i.location
                 AND a2.category = 'LOC'  
        };

        my $dbh = C4::Context->dbh;
        my $sth = $dbh->prepare($query);
        $sth->execute();

        my @columns = ( 'item number', 'barcode', 'biblio number', 'isbn', 'collection code', 'item type', 'holding branch','home branch', 'cfull number', 'location', 'date accessioned', 'not for loan', 'damaged', 'item lost', 'withdrawn', 'to branch', 'found', 'date last borrowed', 'due date',  'ytd', 'lifetime circs' );
        my $tsv = join("\t", @columns) . "\n";

        while (my @row = $sth->fetchrow_array) {
            $tsv .= join("\t", @row) . "\n";
        }

        return $c->render( status => 200, format => "text", text => $tsv );
    } catch {
        $c->unhandled_exception($_);
    };
}

sub items_delta {
    warn "Koha::Plugin::Com::ByWaterSolutions::LibraryIQ::API::items_delta";
    my $c = shift->openapi->valid_input or return;

    return try {

        my $query = q{
 SELECT i.itemnumber,
       i.barcode,
       i.biblionumber,
       isbn,
       i.ccode,
       i.itype,
       i.holdingbranch,
       i.homebranch,
       itemcfullnumber,
       i.location,
       dateaccessioned,
       i.notforloan,
       i.damaged,
       i.itemlost,
       i.withdrawn,
       bt.tobranch,
       r.found,
       i.datelastborrowed,
       i.onloan,
       (SELECT Count(*)
        FROM   statistics s
        WHERE  s.type IN ( 'issue', 'renew' )
               AND i.itemnumber = s.itemnumber
               AND Date(s.datetime) >= Concat( Date_format( Last_day( Now() - INTERVAL 1 month), '%Y-' ), '01-01') ) AS YTD,
       i.issues + Ifnull(i.renewals, 0) AS lifetime
FROM   items i
       JOIN biblioitems bi
         ON i.biblionumber = bi.biblionumber
       LEFT JOIN branchtransfers bt
              ON bt.itemnumber = i.itemnumber
                 AND bt.datesent IS NOT NULL
                 AND bt.datearrived IS NULL
       LEFT JOIN reserves r
              ON r.itemnumber = i.itemnumber
       LEFT JOIN authorised_values a
              ON a.authorised_value = i.ccode
                 AND a.category = 'CCODE'
       LEFT JOIN authorised_values a2
              ON a2.authorised_value = i.location
                 AND a2.category = 'LOC'  
WHERE  i.timestamp > Now() - INTERVAL 3 day  
        };

        my $dbh = C4::Context->dbh;
        my $sth = $dbh->prepare($query);
        $sth->execute();

        my @columns = ( 'item number', 'barcode', 'biblio number', 'isbn', 'collection code', 'item type', 'holding branch','home branch', 'cfull number', 'location', 'date accessioned', 'not for loan', 'damaged', 'item lost', 'withdrawn', 'to branch', 'found', 'date last borrowed', 'due date',  'ytd', 'lifetime circs' );
        my $tsv = join("\t", @columns) . "\n";

        while (my @row = $sth->fetchrow_array) {
            $tsv .= join("\t", @row) . "\n";
        }

        return $c->render( status => 200, format => "text", text => $tsv );
    } catch {
        $c->unhandled_exception($_);
    };
}

sub circulation_full {
    warn "Koha::Plugin::Com::ByWaterSolutions::LibraryIQ::API::circulation_full";
    my $c = shift->openapi->valid_input or return;

    return try {

        my $query = q{
SELECT s.itemnumber,
       i.barcode,
       i.biblionumber,
       s.datetime,
       branch,
       s.borrowernumber AS PatronID
FROM   statistics s
       JOIN items i
         ON s.itemnumber = i.itemnumber
WHERE  type IN ( 'issue', 'renew' )
       AND s.datetime > Now() - INTERVAL 2 year  
        };

        my $dbh = C4::Context->dbh;
        my $sth = $dbh->prepare($query);
        $sth->execute();

        my @columns = ( 'item number', 'barcode', 'biblio number',  'datetime', 'branch', 'patron id' );
        my $tsv = join("\t", @columns) . "\n";

        while (my @row = $sth->fetchrow_array) {
            $tsv .= join("\t", @row) . "\n";
        }

        return $c->render( status => 200, format => "text", text => $tsv );
    } catch {
        $c->unhandled_exception($_);
    };
}

sub circulation_delta {
    warn "Koha::Plugin::Com::ByWaterSolutions::LibraryIQ::API::circulation_delta";
    my $c = shift->openapi->valid_input or return;

    return try {

        my $query = q{
SELECT s.itemnumber,
       i.barcode,
       i.biblionumber,
       s.datetime,
       branch,
       s.borrowernumber AS PatronID
FROM   statistics s
       JOIN items i
         ON s.itemnumber = i.itemnumber
WHERE  type IN ( 'issue', 'renew' )
       AND s.datetime > Now() - INTERVAL 3 day
        };

        my $dbh = C4::Context->dbh;
        my $sth = $dbh->prepare($query);
        $sth->execute();

        my @columns = ( 'item number', 'barcode', 'biblio number',  'datetime', 'branch', 'patron id' );
        my $tsv = join("\t", @columns) . "\n";

        while (my @row = $sth->fetchrow_array) {
            $tsv .= join("\t", @row) . "\n";
        }

        return $c->render( status => 200, format => "text", text => $tsv );
    } catch {
        $c->unhandled_exception($_);
    };
}

sub patrons_full {
    warn "Koha::Plugin::Com::ByWaterSolutions::LibraryIQ::API::patrons_full";
    my $c = shift->openapi->valid_input or return;

    return try {

        my $query = q{
SELECT borrowernumber AS Patronid, dateexpiry AS ExpirationDate, branchcode, 
(SELECT count(i.datetime) FROM statistics i WHERE i.borrowernumber=b.borrowernumber AND date(i.datetime) >= CONCAT(DATE_FORMAT(LAST_DAY(NOW() - INTERVAL 1 MONTH),'%Y-'),'01-01') AND i.type IN ('issue','renew')) AS YTDYearCount,
(SELECT count(i.datetime) FROM statistics i WHERE i.borrowernumber=b.borrowernumber AND i.datetime > now()-interval 1 year AND i.type IN ('issue','renew')) AS PreviousYearCount,
(SELECT count(i.datetime) FROM statistics i WHERE i.borrowernumber=b.borrowernumber AND i.type IN ('issue','renew')) AS LifetimeCount,
updated_on AS LastActivityDate, 
(SELECT max(i.datetime) FROM statistics i WHERE i.borrowernumber=b.borrowernumber AND i.type IN ('issue','renew')) AS LastCheckoutDate, dateenrolled AS RegistrationDate, address AS StreetOne, city, state, zipcode, b.categorycode, c.description
FROM borrowers b
JOIN categories c ON (b.categorycode = c.categorycode)
WHERE address <> '' AND city <> '' AND state <> '' AND zipcode <> ''
        };

        my $dbh = C4::Context->dbh;
        my $sth = $dbh->prepare($query);
        $sth->execute();

        my @columns = ( 'patron id', 'expiration date', 'branch code', 'ytd year count', 'previous year count', 'lifetime count', 'last activity date', 'last checkout date', 'registration date', 'street one', 'city', 'state', 'zip', 'patron code', 'patron type' );
        my $tsv = join("\t", @columns) . "\n";

        while (my @row = $sth->fetchrow_array) {
            $tsv .= join("\t", @row) . "\n";
        }

        return $c->render( status => 200, format => "text", text => $tsv );
    } catch {
        $c->unhandled_exception($_);
    };
}

sub patrons_delta {
    warn "Koha::Plugin::Com::ByWaterSolutions::LibraryIQ::API::patrons_delta";
    my $c = shift->openapi->valid_input or return;

    return try {

        my $query = q{
SELECT borrowernumber AS Patronid, dateexpiry AS ExpirationDate, branchcode, 
(SELECT count(i.datetime) FROM statistics i WHERE i.borrowernumber=b.borrowernumber AND date(i.datetime) >= CONCAT(DATE_FORMAT(LAST_DAY(NOW() - INTERVAL 1 MONTH),'%Y-'),'01-01') AND i.type IN ('issue','renew')) AS YTDYearCount,
(SELECT count(i.datetime) FROM statistics i WHERE i.borrowernumber=b.borrowernumber AND i.datetime > now()-interval 1 year AND i.type IN ('issue','renew')) AS PreviousYearCount,
(SELECT count(i.datetime) FROM statistics i WHERE i.borrowernumber=b.borrowernumber AND i.type IN ('issue','renew')) AS LifetimeCount,
updated_on AS LastActivityDate, 
(SELECT max(i.datetime) FROM statistics i WHERE i.borrowernumber=b.borrowernumber AND i.type IN ('issue','renew')) AS LastCheckoutDate, dateenrolled AS RegistrationDate, address AS StreetOne, city, state, zipcode, b.categorycode, c.description
FROM borrowers b
JOIN categories c ON (b.categorycode = c.categorycode)
WHERE address <> '' AND city <> '' AND state <> '' AND zipcode <> '' AND (DATE(b.updated_on) >= DATE_SUB(CURDATE(), INTERVAL 3 DAY) OR DATE(b.lastseen) >= DATE_SUB(CURDATE(), INTERVAL 3 DAY) OR b.date_renewed >= DATE_SUB(CURDATE(), INTERVAL 3 DAY) OR b.dateenrolled >= DATE_SUB(CURDATE(), INTERVAL 3 DAY))
        };

        my $dbh = C4::Context->dbh;
        my $sth = $dbh->prepare($query);
        $sth->execute();

        my @columns = ( 'patron id', 'expiration date', 'branch code', 'ytd year count', 'previous year count', 'lifetime count', 'last activity date', 'last checkout date', 'registration date', 'street one', 'city', 'state', 'zip', 'patron code', 'patron type' );
        my $tsv = join("\t", @columns) . "\n";

        while (my @row = $sth->fetchrow_array) {
            $tsv .= join("\t", @row) . "\n";
        }

        return $c->render( status => 200, format => "text", text => $tsv );
    } catch {
        $c->unhandled_exception($_);
    };
}

sub holds_delta {
    warn "Koha::Plugin::Com::ByWaterSolutions::LibraryIQ::API::holds_delta";
    my $c = shift->openapi->valid_input or return;

    return try {

        my $query = q{
SELECT r.biblionumber,
       r.branchcode,
       Count(r.reserve_id),
       Curdate()
FROM   reserves r
WHERE  cancellationdate IS NULL
       AND suspend_until IS NULL
       AND waitingdate IS NULL
       AND suspend = 0
GROUP  BY biblionumber,
          r.branchcode  
        };

        my $dbh = C4::Context->dbh;
        my $sth = $dbh->prepare($query);
        $sth->execute();

        my @columns = ( 'biblio number', 'branch code', 'count', 'report date' );
        my $tsv = join("\t", @columns) . "\n";

        while (my @row = $sth->fetchrow_array) {
            $tsv .= join("\t", @row) . "\n";
        }

        return $c->render( status => 200, format => "text", text => $tsv );
    } catch {
        $c->unhandled_exception($_);
    };
}

sub circulation_in_house_full {
    warn "Koha::Plugin::Com::ByWaterSolutions::LibraryIQ::API::circulation_in_house_full";
    my $c = shift->openapi->valid_input or return;

    return try {

        my $query = q{
SELECT s.itemnumber,
       i.barcode,
       i.biblionumber,
       s.datetime,
       branch,
       s.borrowernumber AS PatronID
FROM   statistics s
       JOIN items i
         ON s.itemnumber = i.itemnumber
WHERE  type = 'localuse'
       AND s.datetime > Now() - INTERVAL 2 year  
        };

        my $dbh = C4::Context->dbh;
        my $sth = $dbh->prepare($query);
        $sth->execute();

        my @columns = ( 'item number', 'barcode', 'biblio number',  'datetime', 'branch', 'patron id' );
        my $tsv = join("\t", @columns) . "\n";

        while (my @row = $sth->fetchrow_array) {
            $tsv .= join("\t", @row) . "\n";
        }

        return $c->render( status => 200, format => "text", text => $tsv );
    } catch {
        $c->unhandled_exception($_);
    };
}

sub circulation_in_house_delta {
    warn "Koha::Plugin::Com::ByWaterSolutions::LibraryIQ::API::circulation_in_house_delta";
    my $c = shift->openapi->valid_input or return;

    return try {

        my $query = q{
 SELECT s.itemnumber,
       i.barcode,
       i.biblionumber,
       s.datetime,
       branch,
       s.borrowernumber AS PatronID
FROM   statistics s
       JOIN items i
         ON s.itemnumber = i.itemnumber
WHERE  type = 'localuse'
       AND s.datetime > Now() - INTERVAL 3 day  
        };

        my $dbh = C4::Context->dbh;
        my $sth = $dbh->prepare($query);
        $sth->execute();

        my @columns = ( 'item number', 'barcode', 'biblio number',  'datetime', 'branch', 'patron id' );
        my $tsv = join("\t", @columns) . "\n";

        while (my @row = $sth->fetchrow_array) {
            $tsv .= join("\t", @row) . "\n";
        }

        return $c->render( status => 200, format => "text", text => $tsv );
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
