use strict;
use warnings;

use Modern::Perl "2015";
use MediaWords::CommonLibs;

use utf8;
use Test::More;
use Test::Differences;
use Test::Deep;

use Data::Dumper;

use MediaWords::Util::Bitly;

sub test_bitly_processing_is_enabled()
{
    my $config     = MediaWords::Util::Config::get_config();
    my $new_config = python_deep_copy( $config );
    $new_config->{ bitly } = {};
    my $old_bitly_enabled = $config->{ bitly }->{ enabled };

    $new_config->{ bitly }->{ enabled } = 1;
    MediaWords::Util::Config::set_config( $new_config );
    ok( MediaWords::Util::Bitly::bitly_processing_is_enabled() );

    $new_config->{ bitly }->{ enabled } = 0;
    MediaWords::Util::Config::set_config( $new_config );
    ok( !MediaWords::Util::Bitly::bitly_processing_is_enabled() );

    $new_config->{ bitly }->{ enabled } = undef;
    MediaWords::Util::Config::set_config( $new_config );
    ok( !MediaWords::Util::Bitly::bitly_processing_is_enabled() );

    # Reset configuration
    $new_config->{ bitly }->{ enabled } = $old_bitly_enabled;
    MediaWords::Util::Config::set_config( $new_config );
}

sub test_merge_story_stats()
{
    # New stats had an error, old stats didn't
    {
        my $old_stats = { data => { bitly_id => { foo => 'bar ' }, }, };
        my $new_stats = { error => 'An error occurred while fetching new stats', };
        my $expected_stats = $old_stats;

        cmp_deeply( MediaWords::Util::Bitly::merge_story_stats( $old_stats, $new_stats ), $expected_stats );
    }

    # Old stats had an error, new stats didn't
    {
        my $old_stats = { error => 'An error occurred while fetching old stats', };
        my $new_stats = { data => { bitly_id => { foo => 'bar ' }, }, };
        my $expected_stats = $new_stats;

        cmp_deeply( MediaWords::Util::Bitly::merge_story_stats( $old_stats, $new_stats ), $expected_stats );
    }

    # Both old and new stats had an error
    {
        my $old_stats = { error => 'An error occurred while fetching old stats', };
        my $new_stats = { error => 'An error occurred while fetching new stats', };
        my $expected_stats = $new_stats;

        cmp_deeply( MediaWords::Util::Bitly::merge_story_stats( $old_stats, $new_stats ), $expected_stats );
    }

    # Merge stats for different days, make sure timestamp gets copied too
    {
        my $old_stats_clicks = {
            link_clicks => [
                { dt => 1, clicks => 1 },    #
                { dt => 2, clicks => 2 },    #
                { dt => 3, clicks => 3 },    #
            ]
        };
        my $new_stats_clicks = {
            link_clicks => [
                { dt => 4, clicks => 4 },    #
                { dt => 5, clicks => 5 },    #
                { dt => 6, clicks => 6 },    #
            ]
        };
        my $old_stats = {
            data => { bitly_id => { clicks => [ $old_stats_clicks ] } },    #
            collection_timestamp => 1,                                      #
        };
        my $new_stats = {
            data => { bitly_id => { clicks => [ $new_stats_clicks ] } },    #
            collection_timestamp => 2,                                      #
        };
        my $expected_stats = {
            data => { bitly_id => { clicks => [ $old_stats_clicks, $new_stats_clicks ] } },    #
            collection_timestamp => 2,                                                         #
        };

        cmp_deeply( MediaWords::Util::Bitly::merge_story_stats( $old_stats, $new_stats ), $expected_stats );
    }
}

sub test_aggregate_story_stats()
{
    # Raw data has been fetched twice, had overlapping stats
    {
        my $stories_id = 123;

        my $old_stats_clicks = {
            link_clicks => [
                { dt => 1, clicks => 1 },      #
                { dt => 2, clicks => 10 },     #
                { dt => 3, clicks => 100 },    #
            ]
        };
        my $new_stats_clicks = {
            link_clicks => [
                { dt => 2, clicks => 1000 },      #
                { dt => 3, clicks => 10000 },     #
                { dt => 4, clicks => 100000 },    #
            ]
        };

        my $stats = {
            data => {
                bitly_id_1 => { clicks => [ $old_stats_clicks, $new_stats_clicks ] },
                bitly_id_2 => { clicks => [ $old_stats_clicks, $new_stats_clicks ] },
            }
        };

        my $expected_dates_and_clicks = {

            # Old stats:
            #     1 click from bitly_id_1 + 1 click from bitly_id_2
            MediaWords::Util::SQL::get_sql_date_from_epoch( 1 ) => 1 * 2,

            # New stats:
            #     1000 clicks from bitly_id_1 + 1000 clicks from bitly_id_2
            MediaWords::Util::SQL::get_sql_date_from_epoch( 2 ) => 1000 * 2,

            # New stats:
            #     10,000 clicks from bitly_id_1 + 10,000 clicks from bitly_id_2
            MediaWords::Util::SQL::get_sql_date_from_epoch( 3 ) => 10000 * 2,

            # New stats:
            #     100,000 clicks from bitly_id_1 + 100,000 clicks from bitly_id_2
            MediaWords::Util::SQL::get_sql_date_from_epoch( 4 ) => 100000 * 2,

        };

        my $aggregated_stats = MediaWords::Util::Bitly::aggregate_story_stats( $stories_id, undef, $stats );
        cmp_deeply( $aggregated_stats->{ dates_and_clicks }, $expected_dates_and_clicks );
    }
}

sub main()
{
    plan tests => 8;

    my $builder = Test::More->builder;
    binmode $builder->output,         ":utf8";
    binmode $builder->failure_output, ":utf8";
    binmode $builder->todo_output,    ":utf8";

    test_bitly_processing_is_enabled();
    test_merge_story_stats();
    test_aggregate_story_stats();
}

main();
