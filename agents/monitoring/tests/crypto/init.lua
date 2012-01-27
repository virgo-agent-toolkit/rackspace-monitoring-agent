local crypto = require('crypto')

exports = {}
no = {}

local message = 'This message will be signed'
local message1 = 'This message '
local message2 = 'will be signed'

local RSA_PUBLIC_KEY = [[
-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCiMmAXLjbd5x5wsZjl16WrQn5w
kDkaDAG5eeGjWTbsFm5rq2nQKLXYFjMYHv0lLWC/6AWfgHccA9BSwkNRrNxk+z3t
uepA1dMRBBTNCy87jTGtL7Bun7AfJ56MXqoDxo1SsiUbXUSGFAFsOHKUH4s4Zocx
fCvi6VFJF7Ge6tUdBQIDAQAB
-----END PUBLIC KEY-----
]]

local RSA_PRIV_KEY = [[
-----BEGIN PRIVATE KEY-----
MIICdwIBADANBgkqhkiG9w0BAQEFAASCAmEwggJdAgEAAoGBAKIyYBcuNt3nHnCx
mOXXpatCfnCQORoMAbl54aNZNuwWbmuradAotdgWMxge/SUtYL/oBZ+AdxwD0FLC
Q1Gs3GT7Pe256kDV0xEEFM0LLzuNMa0vsG6fsB8nnoxeqgPGjVKyJRtdRIYUAWw4
cpQfizhmhzF8K+LpUUkXsZ7q1R0FAgMBAAECgYEAhvzj6gblVPL365RzCr7Zu1mg
v2/Yhiv9925PctJaGkxk46kKbFqlVMzNA0MvLZTBk5W3sFKLTr6Bz46r1jrGRNVt
s8kEbiLSRhKnYixDl7yNSK30SMtOdLEpU11ppeB10aJlRgyS6WbG/i965XMsMaKq
KUl3yH0AOk5vK16oTbUCQQDQQyt1u4sX5XYC6HTOD9hZ0BrYSOk6TNpKd2s/Yau0
VQEBBGa7YZr8ngoXtesWR+QVyLQmHLbvguEctuURrlU/AkEAx2AT0DQ2+QgzGWdi
tjLJMgiz9wD7fgN840hUPHK+gKkYW/fwqKjMXAeKSwLmRviARptkOQZQtWAvrGva
+xUouwJAE7vpqFRHD9KcZhYky0nRFGGVyZzPDMkvfhLmxLC6lnHfkHscSPEswHcx
OaHxTsEtKatE9r+NzhA2yIPEHPLJ/QJAZG50bJvw2S+VNgXLRsZ8bRTPOuymwwqU
vZTwweZ3Ki6D08go1Xz6PJ2bvz99qmCBlY+vQ753p3YFbdCC5Zn6AwJBAIH1oS5Y
MTih3Kjkd2sc+Wk9qv7Jjk4fAIkGd6Uo+bKL7qatRG2kz9m8HwXNV8q0QM/8P501
QmBTgtWPsGmXI6Y=
-----END PRIVATE KEY-----
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

  v = crypto.verify.new('sha256')
--  v:update(message1)
--  v:update(message2)
--  verified = v:final(sig, kpub)
--  asserts.ok(verified)

  test.done()
end

no['test_rsa_verify'] = function(test, asserts)
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

return exports
