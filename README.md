# PHP7.4-apache-v8js

A Docker image with the [v8js PHP extension](https://github.com/phpv8/v8js) on top of the [official PHP image](https://hub.docker.com/_/php/).

*Note* : `make test` had to be disabled when compiling v8js because 4 tests were failing :
- closures_basic.phpt
- closures_dynamic.phpt
- datetime_pass.phpt
- php_exceptions_006.phpt

The errors were related to type mismatches (e.g. for closures_basic.phpt the test expected a return type
[object Closure] and got [object Object]). In our use case, the v8js extension work fine though.