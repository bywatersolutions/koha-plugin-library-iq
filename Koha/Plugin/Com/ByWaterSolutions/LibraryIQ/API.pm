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
        my $title_sql = _get_title_sql();

        my $query = qq{
SELECT b.biblionumber,
       bi.isbn,
       bi.itemtype,
       $title_sql,
       b.author,
       copyrightdate,
       publishercode
FROM   biblio b
       JOIN biblioitems bi
         ON bi.biblionumber = b.biblionumber  
       JOIN biblio_metadata bm
         ON bm.biblionumber = b.biblionumber
        };

        my $dbh = C4::Context->dbh;
        my $sth = $dbh->prepare($query);
        $sth->execute();

        my @columns = (
            'biblio number',
            'isbn',
            'item type',
            'title',
            'author',
            'copyright date',
            'publisher code'
        );
        my $tsv = join( "\t", @columns ) . "\n";

        while ( my @row = $sth->fetchrow_array ) {
            $tsv .= join( "\t", @row ) . "\n";
        }

        return $c->render( status => 200, format => "text", text => $tsv );
    }
    catch {
        warn "LibraryIQ Plugin ERROR: $_";
        $c->unhandled_exception($_);
    };
}

sub records_delta {
    warn "Koha::Plugin::Com::ByWaterSolutions::LibraryIQ::API::records_delta";
    my $c = shift->openapi->valid_input or return;

    my $title_sql = _get_title_sql();

    return try {

        my $query = qq{
SELECT b.biblionumber,
       bi.isbn,
       bi.itemtype,
       $title_sql,
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

        my @columns = (
            'biblio number',
            'isbn',
            'item type',
            'title',
            'author',
            'copyright date',
            'publisher code'
        );
        my $tsv = join( "\t", @columns ) . "\n";

        while ( my @row = $sth->fetchrow_array ) {
            $tsv .= join( "\t", @row ) . "\n";
        }

        return $c->render( status => 200, format => "text", text => $tsv );
    }
    catch {
        warn "LibraryIQ Plugin ERROR: $_";
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
       i.itemcallnumber,
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
       i.issues + Ifnull(i.renewals, 0) AS lifetime,
        i.datelastseen AS last_inventoried_date,
  i.`timestamp`   AS last_item_update,
  COALESCE(
  NULLIF(
    GREATEST(
      COALESCE(i.withdrawn_on, DATE '1900-01-01'),
      COALESCE(i.itemlost_on, DATE '1900-01-01'),
      COALESCE(i.damaged_on, DATE '1900-01-01')
      -- add notforloan_on, restricted_on if your schema has them
    ),
    DATE '1900-01-01'
  ),
  (
    SELECT MAX(al.`timestamp`)
    FROM action_logs al
    WHERE al.object = i.itemnumber
      AND al.module IN ('CATALOGUING','CIRCULATION')
      AND al.action IN ('MODIFY','SET_STATUS','UPDATE')
      AND al.info REGEXP '(damaged|itemlost|withdrawn|notforloan|restricted)'
  )
) AS last_status_change_date

       

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

        my @columns = (
            'item number',
            'barcode',
            'biblio number',
            'isbn',
            'collection code',
            'item type',
            'holding branch',
            'home branch',
            'cfull number',
            'location',
            'date accessioned',
            'not for loan',
            'damaged',
            'item lost',
            'withdrawn',
            'to branch',
            'found',
            'date last borrowed',
            'due date',
            'ytd',
            'lifetime circs',
            'last inventoried date',
            'last item update',
            'last status change date'
        );
        my $tsv = join( "\t", @columns ) . "\n";

        while ( my @row = $sth->fetchrow_array ) {
            $tsv .= join( "\t", @row ) . "\n";
        }

        return $c->render( status => 200, format => "text", text => $tsv );
    }
    catch {
        warn "LibraryIQ Plugin ERROR: $_";
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
       i.itemcallnumber,
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
       i.issues + Ifnull(i.renewals, 0) AS lifetime,
        i.datelastseen AS last_inventoried_date,
  i.`timestamp`   AS last_item_update,
  COALESCE(
  NULLIF(
    GREATEST(
      COALESCE(i.withdrawn_on, DATE '1900-01-01'),
      COALESCE(i.itemlost_on, DATE '1900-01-01'),
      COALESCE(i.damaged_on, DATE '1900-01-01')
      -- add notforloan_on, restricted_on if your schema has them
    ),
    DATE '1900-01-01'
  ),
  (
    SELECT MAX(al.`timestamp`)
    FROM action_logs al
    WHERE al.object = i.itemnumber
      AND al.module IN ('CATALOGUING','CIRCULATION')
      AND al.action IN ('MODIFY','SET_STATUS','UPDATE')
      AND al.info REGEXP '(damaged|itemlost|withdrawn|notforloan|restricted)'
  )
) AS last_status_change_date

       

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

        my @columns = (
            'item number',
            'barcode',
            'biblio number',
            'isbn',
            'collection code',
            'item type',
            'holding branch',
            'home branch',
            'cfull number',
            'location',
            'date accessioned',
            'not for loan',
            'damaged',
            'item lost',
            'withdrawn',
            'to branch',
            'found',
            'date last borrowed',
            'due date',
            'ytd',
            'lifetime circs',
            'last inventoried date',
            'last item update',
            'last status change date'
        );
        my $tsv = join( "\t", @columns ) . "\n";

        while ( my @row = $sth->fetchrow_array ) {
            $tsv .= join( "\t", @row ) . "\n";
        }

        return $c->render( status => 200, format => "text", text => $tsv );
    }
    catch {
        warn "LibraryIQ Plugin ERROR: $_";
        $c->unhandled_exception($_);
    };
}

sub circulation_full {
    warn
      "Koha::Plugin::Com::ByWaterSolutions::LibraryIQ::API::circulation_full";
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

        my @columns = (
            'item number', 'barcode', 'biblio number', 'datetime',
            'branch',      'patron id'
        );
        my $tsv = join( "\t", @columns ) . "\n";

        while ( my @row = $sth->fetchrow_array ) {
            $tsv .= join( "\t", @row ) . "\n";
        }

        return $c->render( status => 200, format => "text", text => $tsv );
    }
    catch {
        warn "LibraryIQ Plugin ERROR: $_";
        $c->unhandled_exception($_);
    };
}

sub circulation_delta {
    warn
      "Koha::Plugin::Com::ByWaterSolutions::LibraryIQ::API::circulation_delta";
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

        my @columns = (
            'item number', 'barcode', 'biblio number', 'datetime',
            'branch',      'patron id'
        );
        my $tsv = join( "\t", @columns ) . "\n";

        while ( my @row = $sth->fetchrow_array ) {
            $tsv .= join( "\t", @row ) . "\n";
        }

        return $c->render( status => 200, format => "text", text => $tsv );
    }
    catch {
        warn "LibraryIQ Plugin ERROR: $_";
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

        my @columns = (
            'patron id',
            'expiration date',
            'branch code',
            'ytd year count',
            'previous year count',
            'lifetime count',
            'last activity date',
            'last checkout date',
            'registration date',
            'street one',
            'city',
            'state',
            'zip',
            'patron code',
            'patron type'
        );
        my $tsv = join( "\t", @columns ) . "\n";

        while ( my @row = $sth->fetchrow_array ) {
            $tsv .= join( "\t", @row ) . "\n";
        }

        return $c->render( status => 200, format => "text", text => $tsv );
    }
    catch {
        warn "LibraryIQ Plugin ERROR: $_";
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

        my @columns = (
            'patron id',
            'expiration date',
            'branch code',
            'ytd year count',
            'previous year count',
            'lifetime count',
            'last activity date',
            'last checkout date',
            'registration date',
            'street one',
            'city',
            'state',
            'zip',
            'patron code',
            'patron type'
        );
        my $tsv = join( "\t", @columns ) . "\n";

        while ( my @row = $sth->fetchrow_array ) {
            $tsv .= join( "\t", @row ) . "\n";
        }

        return $c->render( status => 200, format => "text", text => $tsv );
    }
    catch {
        warn "LibraryIQ Plugin ERROR: $_";
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

        my @columns =
          ( 'biblio number', 'branch code', 'count', 'report date' );
        my $tsv = join( "\t", @columns ) . "\n";

        while ( my @row = $sth->fetchrow_array ) {
            $tsv .= join( "\t", @row ) . "\n";
        }

        return $c->render( status => 200, format => "text", text => $tsv );
    }
    catch {
        warn "LibraryIQ Plugin ERROR: $_";
        $c->unhandled_exception($_);
    };
}

sub circulation_in_house_full {
    warn
"Koha::Plugin::Com::ByWaterSolutions::LibraryIQ::API::circulation_in_house_full";
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

        my @columns = (
            'item number', 'barcode', 'biblio number', 'datetime',
            'branch',      'patron id'
        );
        my $tsv = join( "\t", @columns ) . "\n";

        while ( my @row = $sth->fetchrow_array ) {
            $tsv .= join( "\t", @row ) . "\n";
        }

        return $c->render( status => 200, format => "text", text => $tsv );
    }
    catch {
        warn "LibraryIQ Plugin ERROR: $_";
        $c->unhandled_exception($_);
    };
}

sub circulation_in_house_delta {
    warn
"Koha::Plugin::Com::ByWaterSolutions::LibraryIQ::API::circulation_in_house_delta";
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

        my @columns = (
            'item number', 'barcode', 'biblio number', 'datetime',
            'branch',      'patron id'
        );
        my $tsv = join( "\t", @columns ) . "\n";

        while ( my @row = $sth->fetchrow_array ) {
            $tsv .= join( "\t", @row ) . "\n";
        }

        return $c->render( status => 200, format => "text", text => $tsv );
    }
    catch {
        warn "LibraryIQ Plugin ERROR: $_";
        $c->unhandled_exception($_);
    };
}

sub requested_holds_full {
    warn
"Koha::Plugin::Com::ByWaterSolutions::LibraryIQ::API::requested_holds_full";
    my $c = shift->openapi->valid_input or return;

    return try {

        my $query = q{
SELECT 
        r.biblionumber AS BibliographicRecordID,
        r.reserve_id AS HoldRequestID,
        r.branchcode AS pickupLocation,
        r.reservedate AS RequestedDate,
        Now() AS ReportDate
    FROM reserves r
    WHERE r.biblionumber IS NOT NULL 
        AND r.branchcode IS NOT NULL 
        AND r.reservedate >= Now() - INTERVAL 2 year
        AND r.reservedate < Now()

    UNION ALL

    SELECT 
        res.biblionumber AS BibliographicRecordID,
        res.reserve_id AS HoldRequestID,
        res.branchcode AS pickupLocation,
        res.reservedate AS RequestedDate,
        Now() AS ReportDate
    FROM old_reserves res    
    WHERE res.biblionumber IS NOT NULL 
        AND res.branchcode IS NOT NULL 
        AND res.reservedate >= Now() - INTERVAL 2 year
        AND res.reservedate < Now()
        };

        my $dbh = C4::Context->dbh;
        my $sth = $dbh->prepare($query);
        $sth->execute();

        my @columns = (
            'BibliographicRecordID', 'HoldRequestID',
            'pickupLocation',        'RequestedDate',
            'ReportDate'
        );
        my $tsv = join( "\t", @columns ) . "\n";

        while ( my @row = $sth->fetchrow_array ) {
            $tsv .= join( "\t", @row ) . "\n";
        }

        return $c->render( status => 200, format => "text", text => $tsv );
    }
    catch {
        warn "LibraryIQ Plugin ERROR: $_";
        $c->unhandled_exception($_);
    };
}

sub requested_holds_delta {
    warn
"Koha::Plugin::Com::ByWaterSolutions::LibraryIQ::API::requested_holds_delta";
    my $c = shift->openapi->valid_input or return;

    return try {

        my $query = q{
SELECT 
        r.biblionumber AS BibliographicRecordID,
        r.reserve_id AS HoldRequestID,
        r.branchcode AS pickupLocation,
        r.reservedate AS RequestedDate,
        Now() AS ReportDate
    FROM reserves r
    WHERE r.biblionumber IS NOT NULL 
        AND r.branchcode IS NOT NULL 
        AND r.reservedate >= Now() - INTERVAL 1 week
        AND r.reservedate < Now()

    UNION ALL

    SELECT 
        res.biblionumber AS BibliographicRecordID,
        res.reserve_id AS HoldRequestID,
        res.branchcode AS pickupLocation,
        res.reservedate AS RequestedDate,
        Now() AS ReportDate
    FROM old_reserves res    
    WHERE res.biblionumber IS NOT NULL 
        AND res.branchcode IS NOT NULL 
        AND res.reservedate >= Now() - INTERVAL 1 week
        AND res.reservedate < Now()
        };

        my $dbh = C4::Context->dbh;
        my $sth = $dbh->prepare($query);
        $sth->execute();

        my @columns = (
            'BibliographicRecordID', 'HoldRequestID',
            'pickupLocation',        'RequestedDate',
            'ReportDate'
        );
        my $tsv = join( "\t", @columns ) . "\n";

        while ( my @row = $sth->fetchrow_array ) {
            $tsv .= join( "\t", @row ) . "\n";
        }

        return $c->render( status => 200, format => "text", text => $tsv );
    }
    catch {
        warn "LibraryIQ Plugin ERROR: $_";
        $c->unhandled_exception($_);
    };
}

sub fulfilled_holds_full {
    warn
"Koha::Plugin::Com::ByWaterSolutions::LibraryIQ::API::fulfilled_holds_full";
    my $c = shift->openapi->valid_input or return;

    return try {

        my $query = q{
SELECT 
        res.biblionumber AS BibliographicRecordID,
        res.reserve_id AS HoldRequestID,
        res.branchcode as pickupLocation,
        res.waitingdate AS FulfilledDate,
        Now() AS ReportDate
    FROM old_reserves res
        LEFT JOIN borrowers b ON res.borrowernumber = b.borrowernumber
        LEFT JOIN deletedborrowers db ON res.borrowernumber = db.borrowernumber
        LEFT JOIN biblio bib ON res.biblionumber = bib.biblionumber
        LEFT JOIN deletedbiblio dbib ON res.biblionumber = dbib.biblionumber
        LEFT JOIN items i ON res.itemnumber = i.itemnumber
        LEFT JOIN deleteditems di ON res.itemnumber = di.itemnumber
        LEFT JOIN branches br ON res.branchcode = br.branchcode
    WHERE res.biblionumber IS NOT NULL 
        AND res.branchcode IS NOT NULL 
        AND res.found = 'F'  
        AND res.waitingdate >= Now() - INTERVAL 2 year
        AND res.waitingdate < Now()
        };

        my $dbh = C4::Context->dbh;
        my $sth = $dbh->prepare($query);
        $sth->execute();

        my @columns = (
            'BibliographicRecordID', 'HoldRequestID',
            'pickupLocation',        'FulfilledDate',
            'ReportDate'
        );
        my $tsv = join( "\t", @columns ) . "\n";

        while ( my @row = $sth->fetchrow_array ) {
            $tsv .= join( "\t", @row ) . "\n";
        }

        return $c->render( status => 200, format => "text", text => $tsv );
    }
    catch {
        warn "LibraryIQ Plugin ERROR: $_";
        $c->unhandled_exception($_);
    };
}

sub fulfilled_holds_delta {
    warn
"Koha::Plugin::Com::ByWaterSolutions::LibraryIQ::API::fulfilled_holds_delta";
    my $c = shift->openapi->valid_input or return;

    return try {

        my $query = q{
SELECT 
        res.biblionumber AS BibliographicRecordID,
        res.reserve_id AS HoldRequestID,
        res.branchcode as pickupLocation,
        res.waitingdate AS FulfilledDate,
        Now() AS ReportDate
    FROM old_reserves res
        LEFT JOIN borrowers b ON res.borrowernumber = b.borrowernumber
        LEFT JOIN deletedborrowers db ON res.borrowernumber = db.borrowernumber
        LEFT JOIN biblio bib ON res.biblionumber = bib.biblionumber
        LEFT JOIN deletedbiblio dbib ON res.biblionumber = dbib.biblionumber
        LEFT JOIN items i ON res.itemnumber = i.itemnumber
        LEFT JOIN deleteditems di ON res.itemnumber = di.itemnumber
        LEFT JOIN branches br ON res.branchcode = br.branchcode
    WHERE res.biblionumber IS NOT NULL 
        AND res.branchcode IS NOT NULL 
        AND res.found = 'F'  
        AND res.waitingdate >= Now() - INTERVAL 1 week
        AND res.waitingdate < Now()
        };

        my $dbh = C4::Context->dbh;
        my $sth = $dbh->prepare($query);
        $sth->execute();

        my @columns = (
            'BibliographicRecordID', 'HoldRequestID',
            'pickupLocation',        'FulfilledDate',
            'ReportDate'
        );
        my $tsv = join( "\t", @columns ) . "\n";

        while ( my @row = $sth->fetchrow_array ) {
            $tsv .= join( "\t", @row ) . "\n";
        }

        return $c->render( status => 200, format => "text", text => $tsv );
    }
    catch {
        warn "LibraryIQ Plugin ERROR: $_";
        $c->unhandled_exception($_);
    };
}

sub unfilled_holds_full {
    warn
"Koha::Plugin::Com::ByWaterSolutions::LibraryIQ::API::unfilled_holds_full";
    my $c = shift->openapi->valid_input or return;

    return try {

        my $query = q{
SELECT 
        r.biblionumber as BibliographicRecordID,
        r.reserve_id AS HoldRequestID,
        r.reservedate AS RequestedDate,
        r.branchcode AS RequestedPickupLocation
    FROM reserves r
        LEFT JOIN borrowers b ON r.borrowernumber = b.borrowernumber
        LEFT JOIN biblio bib ON r.biblionumber = bib.biblionumber
    WHERE  (r.found IS NULL OR r.found = 'T')
        AND r.suspend = 0
    ORDER BY r.priority ASC
        };

        my $dbh = C4::Context->dbh;
        my $sth = $dbh->prepare($query);
        $sth->execute();

        my @columns = (
            'BibliographicRecordID', 'HoldRequestID',
            'RequestedDate',         'RequestedPickupLocation'
        );
        my $tsv = join( "\t", @columns ) . "\n";

        while ( my @row = $sth->fetchrow_array ) {
            $tsv .= join( "\t", @row ) . "\n";
        }

        return $c->render( status => 200, format => "text", text => $tsv );
    }
    catch {
        warn "LibraryIQ Plugin ERROR: $_";
        $c->unhandled_exception($_);
    };
}

sub _get_title_template {
    my $plugin         = Koha::Plugin::Com::ByWaterSolutions::LibraryIQ->new();
    my $title_template = $plugin->retrieve_data('title_template');

    return $title_template;
}

sub _generate_title_template_sql {
    my ($title_template) = @_;

    my @marc_fields = split( ",", $title_template );

    my @parts;
    foreach my $marc_field (@marc_fields) {
        my ( $field, $subfield ) = split( /\$/, $marc_field );
        push(
            @parts, qq{
            ExtractValue(bm.metadata, '//datafield[\@tag="$field"]/subfield[\@code="$subfield"]')
        }
        );
    }

    my $parts = join( ',', @parts );

    my $sql = qq{ CONCAT_WS(" ", $parts ) AS title };

    return $sql;
}

sub _get_title_sql {
    my $title_template = _get_title_template();

    if ($title_template) {
        return _generate_title_template_sql($title_template);
    }
    else {
        return q{ title };
    }
}

1;
