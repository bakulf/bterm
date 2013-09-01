require 'gtk2'

@current_terminal = nil

@compiling_sentences = [
  "It's always fun to see code compiling",
  "Still compiling...",
  "Compiled languages are so fun!",
];

@stop_compiling_sentences = [
  "Compilation is finished"
];

#def do_stuff(terminal)
#  return if @current_terminal.nil? or
#            @current_terminal[:terminal] != terminal or
#            @current_terminal[:compiling] == false
#  line = terminal.get_text(get_attrs=false).split("\n").last
#  puts line
#end

def terminal_new(terminal, pid)
#  terminal.signal_connect("text-inserted") do |widget|
#    do_stuff widget
#  end
end

def terminal_show(terminal, pid)
  @current_terminal = { :terminal => terminal, :pid => pid.to_i, :compiling => false }
end

def is_make_running(what)
  number = true if Float(what) rescue false
  return false if number != true

  make = File.readlink("/proc/#{what}/exe").end_with? 'make' rescue false
  return false if make != true

  file = File.new("/proc/#{what}/status", 'r')
  while line = file.gets do
    if line.start_with? 'PPid:'
      return line.split[1].to_i == @current_terminal[:pid]
    end
  end

  false
end

GLib::Timeout.add 1000 do
  if not @current_terminal.nil?

    compiling = false

    Dir.entries('/proc').each do |dir|
      if is_make_running dir
        compiling = true
        break
      end
    end

    if compiling != @current_terminal[:compiling]
      @current_terminal[:compiling] = compiling

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
