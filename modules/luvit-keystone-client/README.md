# Luvit Bindings to the Openstack Keystone API

This is a client library for the Openstack Keystone API. It is _not_ feature
complete... yet.

## Example

    local KeystoneClient = require('keystone').Client
    local authUrl = 'https://identity.api.rackspacecloud.com/v2.0'
    local options = {
      username = 'userId',
      apikey = 'apikey'
    }
    local client = KeystoneClient:new(authUrl, options)
    client:tenantIdAndToken(function(err, obj)
      if err then
        p(err)
        return
      end
      p(obj.token)
      p(obj.expires)
      p(obj.tenantId)
    end)

## Features

  * Token Support
  * Tenant ID Support

## Options

  * username [required] - 'String'
  * password [optional] - 'String'
  * apikey   [optional] - 'String'

  One of password or apikey is required

## TODO:

  * Everything else

## License

Apache 2.0

## Contributors

  * Ryan Phillips (rphillips) <rackspace>

