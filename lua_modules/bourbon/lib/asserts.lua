local asserts = {}

asserts.assert = assert

asserts.equal = function(a, b)
  bourbon_assert(a == b)
end
asserts.ok = function(a)
  asserts.assert(a)
end
asserts.equals = function(a, b)
  asserts.assert(a == b)
end
asserts.array_equals = function(a, b)
  asserts.assert(#a == #b)
  for k=1, #a do
    asserts.assert(a[k] == b[k])
  end
end
asserts.not_nil = function(a)
  asserts.assert(a ~= nil)
end

return asserts
