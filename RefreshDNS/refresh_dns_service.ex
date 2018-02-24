#!/usr/bin/env elixir

# What we want to do is:
# We create a file 
#   touch /tmp/refresh-dns-activated
# First try to refresh the DNS, say 10 times with 5 second intervals
# Then refresh every half hour until the program is stopped
# Program should stop when /tmp/refresh-dns-activated is removed
#
# Create executable file /opt/foo/teardown-refresh-dns.sh:

# I have two domains. Leave the 2nd blank if you only have one.
my_token_1 = "Your FreeMyIP token"
my_domain_1 = "Your FreeMyIP domain"
my_token_2 = ""
my_domain_2 = ""

teardown =
"""
#!/bin/bash
echo "Tearing down refresh-dns ..."
if [ -f /tmp/refresh-dns-activated ]; then
    rm /tmp/refresh-dns-activated
else
    echo "Refresh DNS service is not running"
fi
"""

service =
"""
[Unit]
Description=Setup foo
#After=network.target

[Service]
Type=oneshot
ExecStart=/opt/foo/setup-foo.sh
RemainAfterExit=true
ExecStop=/opt/foo/teardown-foo.sh
StandardOutput=journal

[Install]
WantedBy=multi-user.target
"""

defmodule RefreshDNS do

  @retry_interval 1 # seconds
  @ntries 10
  @refresh_interval 1800 # seconds

  def startup_loop(iter,stop) do
    ret = call_refresh_dns()
    Process.sleep(1000*@retry_interval)
    cond do
      iter == stop -> ret #IO.puts "DONE: #{ret}"
      ret == 1 -> startup_loop(iter+1,stop)
      true -> 0
    end
  end

  def cond_loop() do
    IO.puts "Looping forever and refreshing every #{@refresh_interval/60} minutes"
    if File.exists?("/tmp/refresh-dns-activated") do
      Process.sleep(1000*@refresh_interval)
      ret = call_refresh_dns()
      if ret == 1 do
        IO.puts "Refresh DNS failed, trying again in #{@refresh_interval/60} minutes"
      end  
      cond_loop()
    else
      IO.puts "No run file, exiting"
    end
  end

  def call_refresh_dns() do
    ret_ip = System.cmd "dig", ["+short","myip.opendns.com","@resolver1.opendns.com"]
    #    ret = System.cmd "echo",[Integer.to_string(iter)] 
    ip = String.trim(elem ret_ip,0)
    IO.puts "IP ADDR: #{ip}"
    #exit(:seems_bad)
    #exit(:seems_bad)
    ret_dns = System.cmd "curl", ["-s","https://freemyip.com/update?token=#{my_token_1}&domain=#{my_domain_1}.freemyip.com&myip=#{ip}"]
    if (my_domain_2 != "") do
    	ret_dns2 = System.cmd "curl", ["-s","https://freemyip.com/update?token=#{my_token_2}&domain=#{my_domain_2}.freemyip.com&myip=#{ip}"]
    	ret_str2 = String.trim(elem ret_dns2,0)
    else
        ret_str2 = "OK"
    end
    ret_str = String.trim(elem ret_dns,0)
    #IO.puts "DNS: #{inspect ret_dns} #{ret_dns2}"    
    if ret_str == "OK" and ret_str2 == "OK" do
      0
    else
      1
    end
  end

  def run_loop() do
    # create the file
    ret_rfc = System.cmd "touch", ["/tmp/refresh-dns-activated"]
    # if this failed we should abort with an error message
    err = elem ret_rfc,1

    if err==1 do
      IO.puts "Could not create run file /tmp/refresh-dns-activated: #{inspect ret_rfc}"
    else
      IO.puts "Created run file /tmp/refresh-dns-activated"
      # Now we try to refresh, 10 times with 5 seconds sleep
      ret_st = startup_loop(1,@ntries)
      if ret_st==1 do
        IO.puts "Could not refresh DNS, made #{@ntries} attempts: #{inspect ret_st}"
      else        
        IO.puts "Refreshed DNS, entering forever loop"
        # OK, all is well, enter forever loop
        cond_loop()
      end
    end
  end

end

RefreshDNS.run_loop()      
  
