def path
  terminal = @@bterm.terminal_current
  return if terminal.nil?

  file = "/proc/#{terminal[:pid]}/cwd"
  begin
    pwd = File.readlink file
  rescue
    return
  end

  @@bterm.notification.show pwd
end
