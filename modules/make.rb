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
  number = false
  make = false

  begin
    if Float(pid)
      number = true
    end
  rescue
  end

  return [] unless number

  begin
    make = File.readlink("/proc/#{pid}/exe").end_with? 'make'
  rescue
  end

  return [] unless make

  return [ pid ] + check_ppid(pid)
end

def check_ppid(pid)
  file = File.new("/proc/#{pid}/status", 'r')
  while true do
    begin
      line = file.gets
    rescue
      return []
    end

    break if line.nil?

    if line.start_with? 'PPid:'
      parent = line.split[1].to_i
      return [] if parent == 0
      return [ parent ] + check_ppid(parent)
    end
  end

  []
end

GLib::Timeout.add 3000 do
  valid_pids = []
  Dir.entries('/proc').each do |dir|
    pids = check_make dir
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
