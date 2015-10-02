--[[
Copyright 2014 Rackspace

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

return {
  require('./run'),
  require('./read'),
  require('./nginx_config'),
  require('./connections'),
  require('./iptables'),
  require('./ip6tables'),
  require('./autoupdates'),
  require('./passwd'),
  require('./pam'),
  require('./cron'),
  require('./kernel_modules'),
  require('./cpu'),
  require('./disk'),
  require('./filesystem'),
  require('./login'),
  require('./memory'),
  require('./network'),
  require('./nil'),
  require('./packages'),
  require('./procs'),
  require('./system'),
  require('./who'),
  require('./date'),
  require('./sysctl'),
  require('./sshd'),
  require('./fstab'),
  require('./fileperms'),
  require('./services'),
  require('./deleted_libs'),
  require('./cve'),
  require('./last_logins'),
  require('./remote_services'),
  require('./ip4routes'),
  require('./ip6routes'),
  require('./apache2'),
  require('./fail2ban'),
  require('./lsyncd'),
  require('./wordpress'),
  require('./magento'),
  require('./php'),
  require('./postfix')
}
