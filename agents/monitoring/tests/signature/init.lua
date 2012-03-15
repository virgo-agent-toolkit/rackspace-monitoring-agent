--[[
Copyright 2012 Rackspace

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]

local crypto = require('crypto')
local fs = require('fs')

exports = {}

local ca_cert = fs.readFileSync("tests/ca/ca.crt")
local cert_to_verify = fs.readFileSync("tests/ca/server.crt")
local signature = fs.readFileSync("monitoring.zip.sig")
local message = fs.readFileSync("monitoring.zip")

-- Verify the CA signed the server key
local ca = assert(crypto.x509_ca())
ca:add_pem(ca_cert)
assert(ca:verify_pem(cert_to_verify) == true)

local x509 = crypto.x509_cert()
x509:from_pem(cert_to_verify)

local kpub = x509:pubkey()

exports['test_x509_sig_fails_on_bad_message'] = function(test, asserts)
  -- Test streaming verification fails on bad message
  v = crypto.verify.new('sha256')
  v:update(message .. 'x')
  verified = v:final(signature, kpub)
  asserts.ok(not verified)

  test.done()
end

exports['test_x509_sig_fails_on_bad_sig'] = function(test, asserts)
  -- Test streaming verification fails on bad sig
  v = crypto.verify.new('sha256')
  v:update(message)
  verified = v:final(signature .. 'x', kpub)
  asserts.ok(not verified)

  test.done()
end

exports['test_x509_sig_verify_works'] = function(test, asserts)
  -- Test streaming verification
  v = crypto.verify.new('sha256')
  v:update(message)
  verified = v:final(signature, kpub)
  asserts.ok(verified)

  test.done()
end

return exports
