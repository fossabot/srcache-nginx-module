# vi:filetype=

use lib 'lib';
use Test::Nginx::Socket;

#repeat_each(2);

plan tests => repeat_each() * (4 * blocks());

$ENV{TEST_NGINX_MEMCACHED_PORT} ||= 11211;

no_shuffle();

run_tests();

__DATA__

=== TEST 1: basic fetch
--- config
    location /foo {
        default_type text/css;
        srcache_fetch GET /memc;
        srcache_store PUT /memc;

        echo hello;
    }

    location /memc {
        internal;

        set $memc_key 'foooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo';
        set $memc_exptime 300;
        memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
    }
--- request
GET /foo
--- response_headers
Content-Type: text/css
Content-Length:
--- response_body
hello
--- timeout: 15



=== TEST 2: internal redirect in fetch subrequest
--- config
    location /foo {
        default_type text/css;
        srcache_fetch GET /fetch;

        echo hello;
    }
    location /fetch {
        echo_exec /bar;
    }
    location /bar {
        default_type 'text/css';
        echo bar;
    }
--- request
GET /foo
--- response_headers
Content-Type: text/css
Content-Length: 4
--- response_body
bar



=== TEST 3: flush all
--- config
    location /flush {
        set $memc_cmd 'flush_all';
        memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
    }
--- response_headers
Content-Type: text/plain
Content-Length: 4
--- request
GET /flush
--- response_body eval: "OK\r\n"



=== TEST 4: internal redirect in main request (no caching happens) (cache miss)
--- config
    location /foo {
        default_type text/css;
        srcache_fetch GET /memc $uri;
        srcache_store PUT /memc $uri;

        echo_exec /bar;
    }

    location /bar {
        default_type text/javascript;
        echo hello;
    }

    location /memc {
        internal;

        set $memc_key $query_string;
        set $memc_exptime 300;
        memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
    }
--- request
GET /foo
--- response_headers
Content-Type: text/javascript
! Content-Length
--- response_body
hello



=== TEST 5: internal redirect happends in the main request (cache miss as well)
--- config
    location /foo {
        default_type text/css;
        srcache_fetch GET /memc $uri;
        #srcache_store PUT /memc $uri;

        echo world;
    }

    location /memc {
        internal;

        set $memc_key $query_string;
        set $memc_exptime 300;
        memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
    }
--- request
GET /foo
--- response_headers
Content-Type: text/css
!Content-Length
--- response_body
world



=== TEST 6: flush all
--- config
    location /flush {
        set $memc_cmd 'flush_all';
        memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
    }
--- response_headers
Content-Type: text/plain
Content-Length: 4
--- request
GET /flush
--- response_body eval: "OK\r\n"



=== TEST 7: internal redirect in store subrequest
--- config
    location /foo {
        default_type text/css;
        srcache_store GET /store;

        echo blah;
    }
    location /store {
        echo_exec /set-value;
    }
    location /set-value {
        set $memc_key foo;
        set $memc_value bar;
        set $memc_cmd set;

        memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
    }
--- request
GET /foo
--- response_headers
Content-Type: text/css
!Content-Length
--- response_body
blah



=== TEST 8: internal redirect in store subrequest (check if value has been stored)
--- config
    location /foo {
        default_type text/css;
        srcache_fetch GET /fetch;

        echo blah;
    }
    location /fetch {
        set $memc_key foo;
        set $memc_cmd get;

        memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
    }
--- request
GET /foo
--- response_headers
Content-Type: text/css
Content-Length: 3
--- response_body chop
bar

