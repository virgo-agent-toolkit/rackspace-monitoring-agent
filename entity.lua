local sigarCtx = require('/sigar').ctx

local function getNetInfo()
  local netifs = sigarCtx:netifs()
  local objs = {}
  for i=1,#netifs do
    local info = netifs[i]:info()
    local name = info.name
    local obj = {}

    local info_fields = {
      'address',
      'address6',
      'broadcast',
      'flags',
      'hwaddr',
      'mtu',
      'name',
      'netmask',
      'type'
    }

    if info then
      for _, v in pairs(info_fields) do
        obj[v] = info[v]
      end
    end

    objs[name] = obj
  end
  return objs
end

return { getNetInfo = getNetInfo }
