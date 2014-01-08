Bourbon - testing for luvit
===========================

This is a test runner for luvit inspired by whiskey. A basic testing file looks something like this:

    local exports = {}

    exports['test_asserts_ok'] = function(test)
      asserts.ok(true)
      test.done()
    end

    exports['test_asserts_equals'] = function(test)
      asserts.equals(1, 1)
      test.done()
    end

    return exports

Usage
=====
#### Running the tests with the commaond line tool
    ./bin/bourbon -p {tests_directory}

Hacking
=======
#### Running the tests

    ./test.lua

#### TODO

 * Check the test context for leaking global variables
 * Better reporting, just follow Whiskey I would say

License
=======

Apache 2.0, for more info see [LICENSE](/racker/luvit-bourbon/blob/master/LICENSE).
