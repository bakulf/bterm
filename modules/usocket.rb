require 'socket'

file = '/var/run/bterm/bterm.socket'

if File.exists? file
  begin
    socket = UNIXSocket.open file
  rescue
    socket = -1
  end

  if socket != -1
    socket.write "show"
    socket.close
    exit
  end
end

thr = Thread.new do
  File.unlink file if File.exists? file
  socket = UNIXServer.open file
  if socket == -1
    msg "Error creating the unixsocket!"
  else
    while 1 do
      client = socket.accept
      line = client.read 1024
      msg line if not line.nil? and not line.empty?
      client.close
    end
  end
end

def msg(what)
  $bterm.mutex.lock
  $bterm.append_notification what
  $bterm.mutex.unlock
end
