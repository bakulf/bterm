require 'gtk2'

@terminals = {}

@compiling_sentences = [
  "It's always fun to see code compiling",
  "Still compiling...",
  "Compiled languages are so fun!",
];

@stop_compiling_sentences = [
  "Compilation is finished"
];

#def do_stuff(pid, terminal)
#  return if not @terminals.include? pid or
#            @terminals[:compiling] == false
#  line = terminal.get_text(get_attrs=false).split("\n").last
#  puts line
#end

def terminal_new(terminal, pid)
  @terminals[pid] = { :compiling => false }
#  terminal.signal_connect("text-inserted") do |widget|
#    do_stuff pid
#  end
end

def terminal_show(terminal, pid)
  if @terminals[pid][:compiling]
    @@bterm.notification.show @compiling_sentences.sample
  end
end

def terminal_close(terminal, pid)
  @terminals.delete(pid)
end

def check_make(pid)
  number = true if Float(pid) rescue false
  return [] if number != true

  make = File.readlink("/proc/#{pid}/exe").end_with? 'make' rescue false
  params = File.read("/proc/#{pid}/cmdline").unpack('Z*Z*Z*')
  mach = (params[0] == 'python' and params[2] == 'build' and params[1].split('/').last == 'mach')

  return [] if make != true and mach == false

  return [ pid ] + check_ppid(pid)
end

def check_ppid(pid)
  file = File.new("/proc/#{pid}/status", 'r')
  while line = file.gets do
    if line.start_with? 'PPid:'
      parent = line.split[1].to_i
      return [] if parent == 0
      return [ parent ] + check_pid(parent)
    end
  end

  []
end

GLib::Timeout.add 1000 do
  valid_pids = []
  Dir.entries('/proc').each do |dir|
    pids = check_make dir rescue false
    valid_pids += pids if pids.is_a? Array
  end

  @terminals.each do |pid, data|
    compiling = valid_pids.include? pid

    if compiling != data[:compiling]
      data[:compiling] = compiling

      if compiling
        @@bterm.notification.show @compiling_sentences.sample
      else
        @@bterm.notification.show @stop_compiling_sentences.sample
      end
    end
  end

  true
end

@@bterm.register_hooks :terminal_new, method(:terminal_new)
@@bterm.register_hooks :terminal_show, method(:terminal_show)
@@bterm.register_hooks :terminal_close, method(:terminal_close)
