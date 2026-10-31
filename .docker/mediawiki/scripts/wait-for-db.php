#!/usr/bin/env php
<?php
declare( strict_types=1 );

$type = strtolower( trim( (string)( getenv( 'WG_DB_TYPE' ) ?: 'mysql' ) ) );

if ( $type === 'sqlite' ) {
    exit( 0 ); // SQLite has no external database service to wait for.
}
if ( $type !== 'mysql' ) {
    fwrite( STDERR, "Unsupported database type: $type\n" );
    exit( 1 );
}

$host = getenv( 'WG_DB_SERVER' );
$user = getenv( 'WG_DB_USER' );
$name = getenv( 'WG_DB_NAME' );
$password = getenv( 'WG_DB_PASSWORD' );
if ( !$host || !$user || !$name || $password === false ) {
    fwrite( STDERR, "Missing MySQL connection settings\n" );
    exit( 1 );
}

$timeout = filter_var(
    getenv( 'WAIT_FOR_DB_TIMEOUT' ) ?: '60',
    FILTER_VALIDATE_INT,
    [ 'options' => [ 'min_range' => 1, 'max_range' => 600 ] ]
);
if ( $timeout === false ) {
    fwrite( STDERR, "WAIT_FOR_DB_TIMEOUT must be between 1 and 600 seconds\n" );
    exit( 1 );
}

mysqli_report( MYSQLI_REPORT_OFF );
$deadline = microtime( true ) + $timeout;
fwrite( STDOUT, "Waiting for MySQL database connection...\n" );

do {
    $connection = mysqli_init();
    $connection->options( MYSQLI_OPT_CONNECT_TIMEOUT, 2 );
    $ready = @$connection->real_connect( $host, $user, $password, $name );
    if ( $ready ) {
        $connection->close();
        fwrite( STDOUT, "MySQL database connection ready\n" );
        exit( 0 );
    }
    $connection->close();
    $remaining = $deadline - microtime( true );
    if ( $remaining > 0 ) {
        usleep( (int)( min( 1.0, $remaining ) * 1000000 ) );
    }
} while ( $remaining > 0 );

fwrite( STDERR, "MySQL database unavailable after $timeout seconds\n" );
exit( 1 );
