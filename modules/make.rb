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

def is_make_running(pid, what)
  number = true if Float(what) rescue false
  return false if number != true

  make = File.readlink("/proc/#{what}/exe").end_with? 'make' rescue false
  return false if make != true

  file = File.new("/proc/#{what}/status", 'r')
  while line = file.gets do
    if line.start_with? 'PPid:'
      return line.split[1].to_i == pid
    end
  end

  false
end

GLib::Timeout.add 1000 do
  @terminals.each do |pid, data|
    compiling = false

    Dir.entries('/proc').each do |dir|
      running = is_make_running pid, dir rescue false
      if running
        compiling = true
        break
      end
    end

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
