# Rackspace Monitoring Client

This is a client library for the Rackspace Monitoring as a Service. It is _not_ feature
complete... yet.

## Example
    local Client = require('rackspace-monitoring').Client

    local client = Client:new('username', 'token', nil)
    client.entities.list(function(err, results)
      if err then
        p(err)
        return
      end
      p(results)
    end)

## Features

## Options

## TODO:

  * Everything else

## License

  * Apache 2.0

## Contributors

  * Ryan Phillips (rphillips) <rackspace>

