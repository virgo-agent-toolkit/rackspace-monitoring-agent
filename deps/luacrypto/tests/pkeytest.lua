require 'crypto'

assert(crypto.pkey, "crypto.pkey is unavaliable")

k = crypto.pkey.generate('rsa', 1024)
assert(k, "no key generated")

k:write('pub.pem', 'priv.pem')

kpub = assert(crypto.pkey.read('pub.pem'))
kpriv = assert(crypto.pkey.read('priv.pem', true))

assert(crypto.sign, "crypto.sign is unavaliable")
assert(crypto.verify, "crypto.verify is unavaliable")

message = 'This message will be signed'

sig = assert(crypto.sign('md5', message, kpriv))
verified = crypto.verify('md5', message, sig, kpub)
assert(verified, "message not verified")

nverified = crypto.verify('md5', message..'x', sig, kpub)
assert(not nverified, "message verified, when it shouldn't be")

print("OK")
