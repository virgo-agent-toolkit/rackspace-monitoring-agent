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

exports = {}
no = {}

local message = 'This message will be signed'
local message1 = 'This message '
local message2 = 'will be signed'

local RSA_PUBLIC_KEY = [[
-----BEGIN PUBLIC KEY-----
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA0Py2Gaq9lsxS7gN4UoF1
7iV9fI/NW+tgtfgjLqDrNpyvFqlBchhKVeoA2wdaRWpHuDPWLnwUQNRYu4YVLuAt
/32oG9AYzgBEjNMLGdAaqGGSl8HCdnXQh2hJD24WRa1Odcj+o1kIoUKi5BklBZd+
HzTEjbinLUZgCAYxohaIC8yLsZGy6Ez35pAu4XokP9HMxVM9tZN6HwHI//givYkK
v7R6a9iY0fLIHwmEoc4yVw7zNtBqzLLUHROjLCqqvIoiZkn7Z4k3080WCD1Q0hQt
0SKsf+DCDGS3zaE5EeyVvfBVelqz2v4kFzNf+0lEA411UnPEMkfZt+x2Gwr2UAOb
ag961p46Ba+QgifQpyXNQ3bCapqMghfSz6PHeGYeFPNWQKzVLNQSjnPBc0i0h+Ac
kAFJRzYXWZsh1Jq2TCvTiw+1Irm1m9Ltuv+W85hvhLuB1AY3runMLQN0eQ0gvjbk
cKCKtpoKy4rHtVTiy+8hzL1zaWYu3Bny7BgPiKciiMbo7TkDzWVX0hIfjcgJAzVo
gLC1/TVEQkoImomAvzPGXQpbLlX843juVeBCSwdkBAjjlMoJyGcv6wfO91tkG8PW
xUjPQQcJCr8/VSoK10jdUjrQocb3u+ud27n/6eQZOpvwsbn5q3mr2+zUIon/9k8D
bgPEhk6nrCq5rN6A7eCcdwMCAwEAAQ==
-----END PUBLIC KEY-----
]]

local RSA_PRIV_KEY = [[
-----BEGIN RSA PRIVATE KEY-----
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
-----END RSA PRIVATE KEY-----
]]

exports['test_sha256_hash'] = function(test, asserts)
  local hash = 'da0fd2505f0fc498649d6cf9abc7513be179b3295bb1838091723b457febe96a'

  local d = crypto.digest.new("sha256")
  d:update(message1)
  d:update(message2)
  local ret = d:final()
  asserts.equals(hash, ret)

  d:reset(d)
  d:update(message1)
  ret = d:final()
  asserts.ok(hash ~= ret)

  test.done()
end

exports['test_rsa_verify'] = function(test, asserts)
  local kpriv = crypto.pkey.from_pem(RSA_PRIV_KEY, true)
  local kpub = crypto.pkey.from_pem(RSA_PUBLIC_KEY)

  asserts.equals(kpriv:to_pem(true), RSA_PRIV_KEY)
  asserts.equals(kpub:to_pem(), RSA_PUBLIC_KEY)

  sig = crypto.sign('sha256', message, kpriv)

  local v = crypto.verify.new('sha256')
  v:update(message1)
  v:update(message2)
  local verified = v:final(sig, kpub)
  asserts.ok(verified)

  test.done()
end

exports['test_rsa_verify'] = function(test, asserts)
  local kpriv = crypto.pkey.from_pem(RSA_PRIV_KEY, true)
  local kpub = crypto.pkey.from_pem(RSA_PUBLIC_KEY)

  -- Ensure keys are read properly
  asserts.equals(kpriv:to_pem(true), RSA_PRIV_KEY)
  asserts.equals(kpub:to_pem(), RSA_PUBLIC_KEY)

  sig = crypto.sign('sha256', message, kpriv)

  -- Test streaming verification
  v = crypto.verify.new('sha256')
  v:update(message1)
  v:update(message2)
  verified = v:final(sig, kpub)
  asserts.ok(verified)

  nv = crypto.verify.new('sha256')
  nv:update(message1)
  nv:update(message2 .. 'x')
  nverified = nv:final(sig, kpub)
  asserts.ok(not nverified)

   -- Test full buffer verify
  verified = crypto.verify('sha256', message, sig, kpub)
  asserts.ok(verified)

  nverified = crypto.verify('sha256', message..'x', sig, kpub)
  asserts.ok(not nverified)

  test.done()
end

exports['test_rsa_bogus_key'] = function(test, asserts)
  local bogus = crypto.pkey.from_pem(1)
  asserts.is_nil(bogus)
  test.done()
end

local ca_cert = [[-----BEGIN CERTIFICATE-----
MIIG1jCCBL6gAwIBAgIJALZOkAY0D6wQMA0GCSqGSIb3DQEBBQUAMIGiMQswCQYD
VQQGEwJVUzETMBEGA1UECBMKQ2FsaWZvcm5pYTEWMBQGA1UEBxMNU2FuIEZyYW5j
aXNjbzEOMAwGA1UEChMFVmlyZ28xEDAOBgNVBAsTB0hhY2tlcnMxGDAWBgNVBAMT
D0JyYW5kb24gUGhpbGlwczEqMCgGCSqGSIb3DQEJARYbYnJhbmRvbi5waGlsaXBz
QGV4YW1wbGUuY29tMB4XDTEyMDEyNjIyMDAxOFoXDTIyMDEyMzIyMDAxOFowgaIx
CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpDYWxpZm9ybmlhMRYwFAYDVQQHEw1TYW4g
RnJhbmNpc2NvMQ4wDAYDVQQKEwVWaXJnbzEQMA4GA1UECxMHSGFja2VyczEYMBYG
A1UEAxMPQnJhbmRvbiBQaGlsaXBzMSowKAYJKoZIhvcNAQkBFhticmFuZG9uLnBo
aWxpcHNAZXhhbXBsZS5jb20wggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoIC
AQC5YVbGpZHLeWDu30o9UUF2yrqizDzbuDshWT8RlVQDdYvvKNFMFt8OCmgabl2k
8T19zMqnWof72iviZDsLGxOmMbMUFvk1TN7cMfWNsD6P/ja4BYxh90Jt8y65yC/T
6Xm1NLqFyhhOPWvzHvhAuvHg5qWvcyzsx3wDoh+dr3hVIJfxq9Ufu8t4JzOjJplQ
8kwklW6CafrcYF85YJqhxObWeL6gYWnYd3AzDE/S4j7C/nNNQah0NZvu6cO/Sc9l
qAw9gI5a6f9Pd7VFAzW7b8jRZ6pMmkNM9rm83i8tjiBgXDIBHZVEhtkC+5Kp0mU6
ywn/regQGGJ46cInLpCEnDbFhmzOgg4wvNtiy7JT+zyaFQYM0dHPs4JQRfGIc4LO
3M4r5na1qcbNQFQVVbMtsNETg+TrUyrmXDEO9PwwOXU1Khgnrk4A1UWZlf+n5dds
K6KhlRxD+nMzyR+lBPH9vdBtbzoOdy/D/mm6SMKkUIAXWdrPb8ucRMQkxusvq0Dv
8UikFV2Y16r7uqXqiOWCXEKrKMT+cAArCRBzUIoAIWTH4MKoEu9tYRzJcYM+EBc8
nXrvnUBdE8GNiWW444SPoCTM7SakHnQC34YY6WbEctQhGG2QW1fcPycWO5Aqr4WW
8hrbqjb6X15Y/J5OwqM0n3MrrNNv1nhHqaAVYIQYYlNH2QIDAQABo4IBCzCCAQcw
HQYDVR0OBBYEFLgWlUKomtnlKUEJZHAwCL3pSJt1MIHXBgNVHSMEgc8wgcyAFLgW
lUKomtnlKUEJZHAwCL3pSJt1oYGopIGlMIGiMQswCQYDVQQGEwJVUzETMBEGA1UE
CBMKQ2FsaWZvcm5pYTEWMBQGA1UEBxMNU2FuIEZyYW5jaXNjbzEOMAwGA1UEChMF
VmlyZ28xEDAOBgNVBAsTB0hhY2tlcnMxGDAWBgNVBAMTD0JyYW5kb24gUGhpbGlw
czEqMCgGCSqGSIb3DQEJARYbYnJhbmRvbi5waGlsaXBzQGV4YW1wbGUuY29tggkA
tk6QBjQPrBAwDAYDVR0TBAUwAwEB/zANBgkqhkiG9w0BAQUFAAOCAgEAgoSv+w9R
Zlm7XxOD1xKo0AcgtJq6uWic14Y/sVaabN9GPGZVyPI9zywiAPbi9zpBozEWykXz
RA3Tac5Y1xLS+1PCRJcgWiAzIVP0wX0nIj+rxBcXxJ5t7+CiNTQ0BSD3IDgtiWkb
hFYzrUZiTluDs5erR0fatOE4deYLewGErU69rtW+blyCouGzcvBSn/ZmTUhq+VkP
LRfzc1dcHxKw25WL5+O59FkJ3Ytpk7u9xxumNxsugar8ssfs+/Qu5wytVQ1+jPQC
9CFu6n0GNPK3A7ebfUDc7qfUGhvM6YoAvSGK0iRgdDvdqR+47+3UKZ56H7cJufSQ
wNAAWu3CagAXCmQaIKX2C8PS5FxnKymXSZTUVQ55NBcNRrYEfF0+ba6xW9ehSD5N
G2C5FjA7z8eV+FjTDJPBVLZrwutDpyciGT4mpH6ul8rMFTxJuNjzCMT278CEgy5l
IYrjS9B16k/wDfSxtDWyy6laaRnvf7vI+mTTUxZJZVd7ADeW9+Fxx/fddBsFuONw
d81hvMemWe0uz/9SZyb0bmq+ox4zvzS2N05us3vIcZNaIrsG6baVFiTA6js503K5
KjXgcfC980pnPG37oH41aaAHZEpTGgkpVp92dsHlwkrOjtZO2Tt+c4IUiflkPEvt
QKI92udYACbXW5hT8jwyOo/ugwFMMpNmLvM=
-----END CERTIFICATE-----]]

local cert_to_verify = [[-----BEGIN CERTIFICATE-----
MIIFxTCCA60CAQEwDQYJKoZIhvcNAQEFBQAwgaIxCzAJBgNVBAYTAlVTMRMwEQYD
VQQIEwpDYWxpZm9ybmlhMRYwFAYDVQQHEw1TYW4gRnJhbmNpc2NvMQ4wDAYDVQQK
EwVWaXJnbzEQMA4GA1UECxMHSGFja2VyczEYMBYGA1UEAxMPQnJhbmRvbiBQaGls
aXBzMSowKAYJKoZIhvcNAQkBFhticmFuZG9uLnBoaWxpcHNAZXhhbXBsZS5jb20w
HhcNMTIwMTI2MjIwMjI0WhcNMjIwMTIzMjIwMjI0WjCBrTELMAkGA1UEBhMCVVMx
EzARBgNVBAgTCkNhbGlmb3JuaWExFjAUBgNVBAcTDVNhbiBGcmFuY2lzY28xGjAY
BgNVBAoTEVZpcmdvIFRlc3QgU2lnbmVyMQ8wDQYDVQQLEwZIYWNrZXIxGDAWBgNV
BAMTD0JyYW5kb24gUGhpbGlwczEqMCgGCSqGSIb3DQEJARYbYnJhbmRvbi5waGls
aXBzQGV4YW1wbGUuY29tMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA
0Py2Gaq9lsxS7gN4UoF17iV9fI/NW+tgtfgjLqDrNpyvFqlBchhKVeoA2wdaRWpH
uDPWLnwUQNRYu4YVLuAt/32oG9AYzgBEjNMLGdAaqGGSl8HCdnXQh2hJD24WRa1O
dcj+o1kIoUKi5BklBZd+HzTEjbinLUZgCAYxohaIC8yLsZGy6Ez35pAu4XokP9HM
xVM9tZN6HwHI//givYkKv7R6a9iY0fLIHwmEoc4yVw7zNtBqzLLUHROjLCqqvIoi
Zkn7Z4k3080WCD1Q0hQt0SKsf+DCDGS3zaE5EeyVvfBVelqz2v4kFzNf+0lEA411
UnPEMkfZt+x2Gwr2UAObag961p46Ba+QgifQpyXNQ3bCapqMghfSz6PHeGYeFPNW
QKzVLNQSjnPBc0i0h+AckAFJRzYXWZsh1Jq2TCvTiw+1Irm1m9Ltuv+W85hvhLuB
1AY3runMLQN0eQ0gvjbkcKCKtpoKy4rHtVTiy+8hzL1zaWYu3Bny7BgPiKciiMbo
7TkDzWVX0hIfjcgJAzVogLC1/TVEQkoImomAvzPGXQpbLlX843juVeBCSwdkBAjj
lMoJyGcv6wfO91tkG8PWxUjPQQcJCr8/VSoK10jdUjrQocb3u+ud27n/6eQZOpvw
sbn5q3mr2+zUIon/9k8DbgPEhk6nrCq5rN6A7eCcdwMCAwEAATANBgkqhkiG9w0B
AQUFAAOCAgEAOJfGCRbeByGWHxU1DWTmkqG97NoROUw0Gq9BO3WvxbFCvMettDPz
SF6uUu+C7u5uQ5rCqAB1nDe2uCDljvB6XKBjfk/jbhFBa+56JDKmXxjXRaSLFpX2
NxByCb48Hir5021Qcebz+ojScwS6O/jpj/sOlGipssICJExBQs0ywlFKbLsM7zRs
v+s0MO5C8cgFO5Yz0KdOXep8rXStaM9N0IZApG+bywBI+1yQbOqP+BUJ95drmXfe
meDJR1/srhxRUicgq1psE2xsd9UEx6AdoakUDv7T2owtVw3PJavNQCW+8ql67DQj
7epQTQ5wVty1ED5PyfHYOlC0LNlUNmoADegUwyYcQ4246ayfqcnJxacQXIpWylF/
mGHQcR4AmVYsr26UkDYXcwb7BDxH0eb3w5s7X0hwtFzd8jwx3Vagdf4fafm4Vahz
XDiDXVMTZqyncIBu4/8PFfgqgLra/MhHODbLamndPMeHAn0zNXk5HEkiNRhHymSe
oTKkB4Ol10/kEWvOswU/LS69w7HDFgJAnnEi2+XCTHMim8kDcbhoGr2rlL1cT7yL
B3P11S3lepH+PFTFfU19IlrDGfXDxlKNWR9XNVqtQw/qnN+T7XZFW2tuDiMecCYj
64Qm7mwOJZDp1eFU0GiTuF7r7ZMBWTDDe98eOFOOiUZ3m+m43SGVb+U=
-----END CERTIFICATE-----]]

local bad_cert = [[-----BEGIN CERTIFICATE-----
MIIFxTCCA60CAQEwDQYJKoZIhvcNAQEFBQAwgaIxCzAJBgNVBAYTAlVTMRMwEQYD
VQQIEwpDYWxpZm9ybmlhMRYwFAYDVQQHEw1TYW4gRnJhbmNpc2NvMQ4wDAYDVQQK
EwVWaXJnbzEQMA4GA1UECxMHSGFja2VyczEYMBYGA1UEAxMPQnJhbmRvbiBQaGls
aXBzMSowKAYJKoZIhvcNAQkBFhticmFuZG9uLnBoaWxpcHNAZXhhbXBsZS5jb20w
HhcNMTIwMTI2MjIwMjI0WhcNMjIwMTIzMjIwMjI0WjCBrTELMAkGA1UEBhMCVVMx
EzARBgNVBAgTCkNhbGlmb3JuaWExFjAUBgNVBAcTDVNhbiBGcmFuY2lzY28xGjAY
BgNVBAoTEVZpcmdvIFRlc3QgU2lnbmVyMQ8wDQYDVQQLEwZIYWNrZXIxGDAWBgNV
BAMTD0JyYW5kb24gUGhpbGlwczEqMCgGCSqGSIb3DQEJARYbYnJhbmRvbi5waGls
aXBzQGV4YW1wbGUuY29tMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA
0Py2Gaq9lsxS7gN4UoF17iV9fI/NW+tgtfgjLqDrNpyvFqlBchhKVeoA2wdaRWpH
uDPWLnwUQNRYu4YVLuAt/32oG9AYzgBEjNMLGdAaqGGSl8HCdnXQh2hJD24WRa1O
dcj+o1kIoUKi5BklBZd+HzTEjbinLUZgCAYxohaIC8yLsZGy6Ez35pAu4XokP9HM
xVM9tZN6HwHI//givYkKv7R6a9iY0fLIHwmEoc4yVw7zNtBqzLLUHROjLCqqvIoi
Zkn7Z4k3080WCD1Q0hQt0SKsf+DCDGS3zaE5EeyVvfBVelqz2v4kFzNf+0lEA411
UnPEMkfZt+x2Gwr2UAObag961p46Ba+QgifQpyXNQ3bCapqMghfSz6PHeGYeFPNW
QKzVLNQSjnPBc0i0h+AckAFJRzYXWZsh1Jq2TCvTiw+1Irm1m9Ltuv+W85hvhLuB
1AY3runMLQN0eQ0gvjbkcKCKtpoKy4rHtVTiy+8hzL1zaWYu3Bny7BgPiKciiMbo
7TkDzWVX0hIfjcgJAzVogLC1/TVEQkoImomAvzPGXQpbLlX843juVeBCSwdkBAjj
lMoJyGcv6wfO91tkG8PWxUjPQQcJCr8/VSoK10jdUjrQocb3u+ud27n/6eQZOpvw
sbn5q3mr2+zUIon/9k8DbgPEhk6nrCq5rN6A7eCcdwMCAwEAATANBgkqhkiG9w0B
AQUFAAOCAgEAOJfGCRbeByGWHxU1DWTmkqG97NoROUw0Gq9BO3WvxbFCvMettDPz
SF6uUu+C7u5uQ5rCqAB1nDe2uCDljvB6XKBjfk/jbhFBa+56JDKmXxjXRaSLFpX2
NxByCb48Hir5021Qcebz+ojScwS6O/jpj/sOlGipssICJExBQs0ywlFKbLsM7zRs
v+s0MO5C8cgFO5Yz0KdOXep8rXStaM9N0IZApG+bywBI+1yQbOqP+BUJ95drmXfe
meDJR1/srhxRUicgq1psE2xsd9UEx6AdoakUDv7T2owtVw3PJavNQCW+8ql67DQj
7epQTQ5wVty1ED5PyfHYOlC0LNlUNmoADegUwyYcQ4246ayfqcnJxacQXIpWylF/
mGHQcR4AmVYsr26UkDYXcwb7BDxH0eb3w5s7X0hwtFzd8jwx3Vagdf4fafm4Vahz
XDiDXVMTZqyncIBu4/8PFfgqgLra/MhHODbLamndPMeHAn0zNXk5HEkiNRhHymSe
oTKkB4Ol10/kEWvOswU/LS69w7HDFgJAnnEi2+XCTHMim8kDcbhoGr3rlL1cT7yL
B3P11S3lepH+PFTFfU19IlrDGfXDxlKNWR9XNVqtQw/qnN+T7XZFW2tuDiMecCYj
64Qm7mwOJZDp1eFU0GiTuF7r7ZMBWTDDe98eOFOOiUZ3m+m43SGVb+U=
-----END CERTIFICATE-----]]

exports['test_x509_verify'] = function(test, asserts)
  ca = assert(crypto.x509_ca())

  assert(ca.add_pem)
  asserts.ok(ca:add_pem(ca_cert))
  asserts.is_nil(ca:add_pem("FOBAR"))

  asserts.ok(ca:verify_pem(cert_to_verify))
  asserts.ok(ca:verify_pem(bad_cert) == false)
  test.done()
end

return exports
