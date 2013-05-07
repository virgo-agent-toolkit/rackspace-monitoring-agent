#!/usr/bin/env expect
#exp_internal 1
set timeout 10

set config [lindex $argv 0]
set agent [lindex $argv 1]
set zip [lindex $argv 2]

if { $config == "" || $agent == ""|| $zip == ""} {
  puts "Usage: </absolute/path/to/config> </absolute/path/to/agent> <absolute/path/to/zip>"
  exit 1
}
set fp [open $config "r"]
set data [read $fp]
set data [split $data "\n"]
set user [lindex $data 0]
set key [lindex $data 1]

if { $user == "" || $key == ""} {
  puts "$config must contain exactly:\nusername\npassword"
  exit 1
}

spawn -noecho "$agent" -z "$zip" --setup
expect "Username: "
send "$user\r"
expect "API Key or Password: "
send "$key\r"

expect {
  timeout {
    puts "timed out.  Maybe an agent is already running?"
    exit 1
  }
  "Select Option (e.g., 1, 2): " {
    send "1\r"
  }
  -indices -re {Agent already associated Entity with id=([a-zA-Z0-9]+) and label=} {
    set entity_id $expect_out(1,string)
    wait
    puts "\ndeleteing entity: $entity_id"
    wait
    eval spawn "raxmon-entities-delete --id=$entity_id"
    wait
    spawn -noecho /racker/virgo/monitoring-agent -z /racker/virgo/monitoring.zip --setup
    expect "Username: "
    send "$user\r"
    expect "API Key or Password: "
    send "$key\r"
    expect "Select Option (e.g., 1, 2): "
    send "1\r"
  }
}

set entity_id ""

expect {
   timeout { puts "could not find entity id"; exit 1}
  -indices -re {New Entity Created: ([a-zA-Z0-9]+)} { set entity_id $expect_out(1,string) }
}

if { $entity_id == ""} {
  puts "could not find entity id"
  exit 1
}

puts "all done"
