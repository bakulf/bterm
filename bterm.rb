#!/usr/bin/env ruby

=begin
  bterm - my terminal
=end

require "gtk2"
require "vte.so"
require "yaml"
require "shellwords"

# regular expressions to highlight links in terminal. This code was
# lovely stolen from the great gnome-terminal project, thank you =)
USERCHARS = '-[:alnum:]'
PASSCHARS = '-[:alnum:],?;.:/!%$^*&~"#\''
HOSTCHARS = '-[:alnum:]'
HOST      = '[' + HOSTCHARS + ']+(\\.[' + HOSTCHARS + ']+)*'
PORT      = '(:[:digit:]{1,5})?'
PATHCHARS =  '-[:alnum:]_$.+!*(),;:@&=?/~#%'
SCHEME    = '(news:|telnet:|nntp:|file:/|https?:|ftps?:|webcal:)'
USER      = '[' + USERCHARS + ']+(:[' + PASSCHARS + ']+)?'
URLPATH   = '/[' + PATHCHARS + ']*[^]\'.}>) \t\r\n,\\"]'

TERMINAL_MATCH_EXPRS = [
  SCHEME + '//(' + USER + '@)?' + HOST + PORT + '(' + URLPATH + ')?/?',
  '(www|ftp)[' + HOSTCHARS + ']*\.' + HOST + PORT + '(' +URLPATH + ')?/?',
  '(mailto:)?[' + USERCHARS + '][' + USERCHARS + '.]*@[' + HOSTCHARS + ']+\.' + HOST,
]


# Here, my terminal
class BTerm
  attr_accessor :notification
  attr_accessor :mutex

  def init
    @configuration = [
      { :key => 'cwd',                         :default => "previous", :internal => true,
        :func => 'set_cwd',                    :type => :string,
        :msg => "The current work directory for the new terminal.\n" +
                "It can be: 'previous' (the last path in the previous terminal),\n" +
                "           'home' (your home directory),\n" +
                "           '/a/custom/path'.\n" },
      { :key => 'audible_bell',                :default => false,
        :func => 'set_audible_bell',           :type => :boolean,
        :msg => "Controls whether or not the terminal will beep when\n" +
                "the child outputs the \"bl\" sequence." },
      { :key => 'visible_bell',                :default => false,
        :func => 'set_visible_bell',           :type => :boolean,
        :msg => "Controls whether or not the terminal will present a visible\n" +
                "bell to the user when the child outputs the \"bl\" sequence.\n" +
                "The terminal will clear itself to the default foreground\n" +
                "color and then repaint itself." },
      { :key => 'scroll_background',           :default => false,
        :func => 'set_scroll_background',      :type => :boolean,
        :msg => "Controls whether or not the terminal will scroll the\n" +
                "background image (if one is set) when the text in the window\n" +
                "must be scrolled." },
      { :key => 'scroll_on_output',            :default => false,
        :func => 'set_scroll_on_output',       :type => :boolean,
        :msg => "Controls whether or not the terminal will forcibly scroll to\n" +
                "the bottom of the viewable history when the new data is\n" +
                "received from the child." },
      { :key => 'scrollback_lines',            :default => 1024,
        :func => 'set_scrollback_lines',       :type => :integer,
        :msg => "Sets the length of the scrollback buffer used by the terminal." },
      { :key => 'scroll_on_keystroke',         :default => true,
        :func => 'set_scroll_on_keystroke',    :type => :boolean,
        :msg => "Controls whether or not the terminal will forcibly scroll to\n" +
                "the bottom of the viewable history when the user presses\n" +
                "a key. Modifier keys do not trigger this behavior." },
      { :key => 'color_dim',                   :default => "#ffffff",
        :func => 'set_color_dim',              :type => :color,
        :msg => "Sets the color used to draw dim text in the default foreground color." },
      { :key => 'color_bold',                  :default => "#ffffff",
        :func => 'set_color_bold',             :type => :color,
        :msg => "Sets the color used to draw bold text in the default foreground color." },
      { :key => 'color_foreground',            :default => "#ffffff",
        :func => 'set_color_foreground',       :type => :color,
        :msg => "Sets the foreground color used to draw normal text." },
      { :key => 'color_background',            :default => "#000000",
        :func => 'set_color_background',       :type => :color,
        :msg => "Sets the background color for text which does not have\n" +
                "a specific background color assigned. Only has effect when\n" +
                "no background image is set and when the terminal is not transparent." },
      { :key => 'colors',                      :default => "#000000000000:#cccc00000000:#4e4e9a9a0606:#c4c4a0a00000:#34346565a4a4:#757550507b7b:#060698209a9a:#d3d3d7d7cfcf:#555557575353:#efef29292929:#8a8ae2e23434:#fcfce9e94f4f:#72729f9fcfcf:#adad7f7fa8a8:#3434e2e2e2e2:#eeeeeeeeecec", :internal => true,
        :func => 'set_colors',                 :type => :string,
        :msg => "The terminal widget uses a 28-color model comprised of\n" +
                "the default foreground and background colors, the bold\n" +
                "foreground color, the dim foreground color, an eight\n" +
                "color palette, bold versions of the eight color palette,\n" +
                "and a dim version of the the eight color palette." },
      { :key => 'color_cursor',                :default => "#ffffff",
        :func => 'set_color_cursor',           :type => :color,
         :msg => "Sets the background color for text which is under the cursor." },
      { :key => 'color_highlight',             :default => "#00000f",
        :func => 'set_color_highlight',        :type => :color,
        :msg => "Sets the background color for text which is highlighted.\n" +
                "If nil, highlighted text (which is usually highlighted because\n" +
                "it is selected) will be drawn with foreground and background\n" +
                "colors reversed." },
      { :key => 'background_opacity',          :default => 0.95,
        :func => 'set_background_opacity',     :type => :float,
        :msg => "Sets the background opacity." },
      { :key => 'background_transparent',      :default => false,
        :func => 'set_background_transparent', :type => :boolean,
        :msg => "Sets the terminal's background image to the pixmap stored in\n" +
                "the root window, adjusted so that if there are no windows below\n" +
                "your application, the widget will appear to be transparent." },
      { :key => 'cursor_blinks',               :default => true,
        :func => 'set_cursor_blinks',          :type => :boolean,
        :msg => "Sets whether or not the cursor will blink." },
      { :key => 'font',                        :default => 'Monospace 11',
        :func => 'set_font',                   :type => :string,
        :msg => "Sets the font used for rendering all text displayed by the terminal." },
      { :key => 'backspace_binding',           :default => 'ASCII_DELETE',
        :func => 'set_backspace_binding',      :type => :string, :internal => true,
        :msg => "Modifies the terminal's backspace key binding, which controls\n" +
                "what string or control sequence the terminal sends to its\n" +
                "child when the user presses the backspace key.\n" +
                "ASCII_DELETE - ASCII_BACKSPACE - AUTO - DELETE_SEQUENCE - TTY" },
      { :key => 'delete_binding',              :default => 'DELETE_SEQUENCE',
        :func => 'set_delete_binding',         :type => :string, :internal => true,
        :msg => "Modifies the terminal's delete key binding, which controls\n" +
                "what string or control sequence the terminal sends to its\n" +
                "child when the user presses the delete key.\n" +
                "ASCII_DELETE - ASCII_BACKSPACE - AUTO - DELETE_SEQUENCE - TTY" },
      { :key => 'word_chars',                  :default => '-A-Za-z0-9,./?%&amp;#:_',
        :func => 'set_word_chars',             :type => :string,
        :msg => "When the user double-clicks to start selection, the terminal\n" +
                "will extend the selection on word boundaries. It will treat\n" +
                "characters included in spec as parts of words, and all other\n" +
                "characters as word separators. Ranges of characters can be\n" +
                "specified by separating them with a hyphen.\n" },
      { :key => 'mouse_autohide',              :default => 'true',
        :func => 'set_mouse_autohide',         :type => :boolean,
        :msg => "Changes the value of the terminal's mouse autohide setting.\n" +
                "When autohiding is enabled, the mouse cursor will be hidden\n" +
                "when the user presses a key and shown when the user moves the mouse." }
    ]

    @hotkeys = [
      { :key => 'new_terminal',   :value => 'ctrl shift T',     :func => 'terminal_new'    },
      { :key => 'prev_terminal',  :value => 'ctrl shift Left',  :func => 'terminal_prev'   },
      { :key => 'next_terminal',  :value => 'ctrl shift Right', :func => 'terminal_next'   },
      { :key => 'close_terminal', :value => 'ctrl shift W',     :func => 'terminal_close'  },
      { :key => 'copy',           :value => 'ctrl shift C',     :func => 'terminal_copy'   },
      { :key => 'paste',          :value => 'ctrl shift V',     :func => 'terminal_paste'  },
      { :key => 'detach',         :value => 'ctrl shift D',     :func => 'terminal_detach' },
      { :key => 'attach',         :value => 'ctrl shift A',     :func => 'terminal_attach' },
    ]

    @hotkeys_custom = [
      { :event => 'ctrl shift F', :code => 'process_exec "firefox"' },
      { :event => 'ctrl shift E', :code => 'terminal_new "ssh www.server.org"' },
    ]

    @notification_config = [
      { :key => 'markup',  :value => "<span font_desc=\"Purisa 30\" foreground=\"red\">%s</span>",
        :msg => 'Read http://developer.gnome.org/pango/unstable/PangoMarkupFormat.html' },
      { :key => 'timeout', :value => 1500,
        :msg => 'This value is in milliseconds.' },
    ]

    @matches = { :rules => [], :event => 'ctrl 1',
                 :msg => "Open the specified application, when this event is triggered.\n" +
                         "1 means mouse button 1, 2 button 2 (3 is the right one)... ctrl and shift are supported" }
    TERMINAL_MATCH_EXPRS.each do |expr|
      @matches[:rules].push({ :regexp => expr, :app => 'gnome-open' })
    end

    read_config

    @hooks = { :terminal_new => [],
               :terminal_close => [],
               :terminal_show => [],
               :window_created => [],
               :notification_received => [] }

    setup_notifications
    load_modules

    @terminals = []
    @detached_terminals = []

    create_window
    create_hotkeys
    create_notification

    terminal_new ARGV
  end

  def run
    @window.show_all
  end

  def terminal_new(cmd = nil)
    terminal = Vte::Terminal.new
    @terminals.push({ :terminal => terminal, :pid => 0, :cwd => nil })

    terminal.signal_connect("child-exited") do |widget|
      pos = terminal_pos widget
      terminal_kill pos if pos != -1
      terminal_kill_detached widget
    end

    terminal.signal_connect("window-title-changed") do |widget|
      update_window_title(widget.window_title) if widget == @window.children[0]
    end

    @configuration.each do |c|
      next if @settings.nil? or @settings[c[:key]].nil?

      if c.include? :internal and c[:internal] == true
        send(c[:func], terminal, @settings[c[:key]])
      else
        terminal.send(c[:func], @settings[c[:key]])
      end
    end

    if @matches[:rules].is_a? Array
      @matches[:rules].each do |m|
        tag = terminal.match_add m['regexp']
        terminal.match_set_cursor tag, Gdk::Cursor::HAND2
      end
    end

    terminal.signal_connect("button-press-event") do |widget, event|
      button_pressed widget, event
    end

    options = {}

    if not @terminals.last[:cwd].nil?
      options[:working_directory] = @terminals.last[:cwd]
    end

    # String
    if cmd.is_a? String and not cmd.empty?
      argv = []
      cmd.split(' ').each do |c| argv.push c.strip end
      options[:argv] = argv

    # Array
    elsif cmd.is_a? Array and not cmd.empty?
      options[:argv] = cmd
    end

    @terminals.last[:pid] = terminal.fork_command options

    @hooks[:terminal_new].each do |cb|
      cb.call(@terminals.last[:terminal], @terminals.last[:pid])
    end

    terminal.show

    terminal_show @terminals.length - 1
  end

  def register_hooks(hook, cb)
    if not @hooks.include? hook
      puts "Hook #{hook} doesn't exist."
      return
    end

    @hooks[hook].push cb
  end

  def append_notification(what)
    @notifications.push what
  end

  def terminal_current
    pos = terminal_pos
    return @terminals[pos]
  end

private
  def read_config
    filename = ENV['HOME'] + '/.bterm.yml'

    # No config? Let's create it:
    if not File.exist? filename
      file = File.open filename, 'w'

      file.write "bterm:\n"
      @configuration.each do |c|

        file.write "\n"

        c[:msg].split("\n").each do |msg|
          file.write "  # " + msg + "\n"
        end

        file.write "  " + c[:key] + ": "
        if c[:type] == :boolean
          file.write c[:default].to_s
        elsif c[:type] == :color
          file.write '"' + c[:default] + '"'
        elsif c[:type] == :float
          file.write c[:default].to_s
        elsif c[:type] == :integer
          file.write c[:default].to_s
        elsif c[:type] == :string
          file.write '"' + c[:default].to_s + '"'
        end
        file.write "\n"
      end

      file.write "\n"
      file.write "hotkeys:\n"
      @hotkeys.each do |h|
        file.write "  " + h[:key] + ": " + h[:value] + "\n"
      end

      file.write "\n"
      file.write "hotkeys_custom:\n"
      file.write "  # the code is ruby code. You can add your own modules\n"
      file.write "  # in ~/.bterm directory.\n"
      @hotkeys_custom.each do |h|
        file.write "\n"
        file.write "  - hotkey: " + h[:event] + "\n"
        file.write "    code: " + h[:code] + "\n"
      end

      file.write "\n"
      file.write "notification:\n"
      @notification_config.each do |c|
        file.write "\n"

        c[:msg].split("\n").each do |msg|
          file.write "  # " + msg + "\n"
        end

        file.write "  " + c[:key] + ": " + c[:value].to_s + "\n"
      end

      file.write "\n"
      file.write "matches:\n"

      @matches[:msg].split("\n").each do |msg|
        file.write "  # " + msg + "\n"
      end

      file.write "  event: " + @matches[:event] + "\n"
      file.write "  rules: "
      @matches[:rules].each do |m|
        file.write "\n"
        file.write "    - regexp: " + m[:regexp].gsub('"', '\\"') + "\n"
        file.write "      app: " + m[:app] + "\n"
      end

      file.close
    end

    # Loading the config:
    config = YAML.load_file(ENV['HOME'] + '/.bterm.yml')
    if config == false or config.nil? or config['bterm'].nil?
      puts "No configuration! Remove ~/.bterm.yml or fix it!"
      exit
    end

    @settings = config['bterm']

    # Validation of the types:
    @configuration.each do |c|
      next if @settings.nil? or @settings[c[:key]].nil?

      if c[:type] == :boolean
        @settings[c[:key]] = @settings[c[:key]] ? true : false
      elsif c[:type] == :color
        @settings[c[:key]] = Gdk::Color.parse(@settings[c[:key]])
      elsif c[:type] == :float
        @settings[c[:key]] = @settings[c[:key]].to_f
      elsif c[:type] == :integer
         @settings[c[:key]] = @settings[c[:key]].to_i
      elsif c[:type] == :string
        # Nothing
      end
    end

    # Hot keys configuration:
    @hotkeys.each do |h|
      next if config['hotkeys'].nil? or config['hotkeys'][h[:key]].nil?
      h[:value] = config['hotkeys'][h[:key]]
    end

    # custom hot keys
    @hotkeys_custom = []
    if not config['hotkeys_custom'].nil?
      config['hotkeys_custom'].each do |h|
        @hotkeys_custom.push({ :event => h['hotkey'], :code => h['code'] })
      end
    end

    # notification
    @notification_config.each do |n|
       next if config['notification'].nil? or config['notification'][n[:key]].nil?
       n[:value] = config['notification'][n[:key]]
    end

    # matches
    @matches = {}
    if not config['matches'].nil?
      @matches[:rules] = config['matches']['rules'] if not config['matches']['rules'].nil?
      @matches[:event] = config['matches']['event'] if not config['matches']['event'].nil?
    end
  end

  def load_modules
    dirname = ENV['HOME'] + '/.bterm'

    # Directory + example
    if not File.exist? dirname
      Dir.mkdir dirname
      f =File.open dirname + '/example.rb', 'w'
      f.write "# Something useful for the custom hotkeys\n"
      f.write "def process_exec(cmd)\n  job = fork do\n   exec cmd\n  end\n\n  Process.detach job\nend\n\n"
      f.write "def terminal_new(cmd = nil)\n  @@bterm.terminal_new\nend\n\n"
      f.close
    end

    # Let's load the modules
    d = Dir.open dirname
    while file = d.read do
      next if file.start_with? '.'
      begin
        require dirname + '/' + file
      rescue
        puts "Error loading " + dirname + '/' + file
      end
    end
  end

  # Creation of the main window
  def create_window
    @window = Gtk::Window.new("BTerm - the baku's terminal")
    @window.fullscreen
    @window.decorated = false

    colormap = @window.screen.rgba_colormap
    @window.set_colormap @window.screen.rgba_colormap if not colormap.nil?

    @window.signal_connect("destroy") do |widget|
      Gtk.main_quit
    end

    @window.set_events(Gdk::Event::FOCUS_CHANGE_MASK)
    @window.signal_connect("focus-out-event") do |widget, data|
      @notification.hide
    end

    @hooks[:window_created].each do |cb|
      cb.call(@window)
    end

  end

  # Configuration of the hotkeys
  def create_hotkeys
    ag = Gtk::AccelGroup.new

    @hotkeys.each do |h|
      mask, char = parse_hotkey h[:value]

      if char
        ag.connect(char, mask, Gtk::ACCEL_VISIBLE) do
          send h[:func]
          true
        end
      end
    end

    @hotkeys_custom.each do |h|
      mask, char = parse_hotkey h[:event]

      if char
        ag.connect(char, mask, Gtk::ACCEL_VISIBLE) do
          eval(h[:code])
          true
        end
      end
    end

    @window.add_accel_group(ag)
  end

  def set_mask(mask, what)
    if mask.nil?
      return what
    end
    return mask | what
  end

  def parse_hotkey(str)
    mask = nil
    char = nil

    str.split.each do |p|
      p.strip!

      if p.downcase == 'ctrl'
        mask = set_mask(mask, Gdk::Window::CONTROL_MASK)
      elsif p.downcase == 'shift'
        mask = set_mask(mask, Gdk::Window::SHIFT_MASK)
      elsif p.downcase == 'mod1'
        mask = set_mask(mask, Gdk::Window::MOD1_MASK)
      elsif p.downcase == 'mod2'
        mask = set_mask(mask, Gdk::Window::MOD2_MASK)
      elsif p.downcase == 'mod3'
        mask = set_mask(mask, Gdk::Window::MOD3_MASK)
      else
        char = Gdk::Keyval.from_name(p)
      end
    end

    return [ mask, char ]
  end

  def create_notification
    @notification = Notification.new(@notification_config)
  end

  def destroy
    @notification.destroy
    @window.destroy
  end

  #### TERMINALS ####

  def notify(pos = nil)
    msg = ''

    if pos.nil?
      msg = 'nothing more than this...'
    else
      msg = (pos + 1).to_s + ' of ' + @terminals.length.to_s
    end

    msg += "\n" + @detached_terminals.length.to_s + ' detached' if not @detached_terminals.empty?

    @notification.show msg
  end

  # Just an helper
  def terminal_pos(terminal = nil)
    terminal = @window.children[0] if terminal.nil?

    @terminals.each_with_index do |t, pos|
      return pos if t[:terminal] == terminal
    end

    return -1
  end

  # prev
  def terminal_prev
    if @terminals.length <= 1
      notify
      return
    end

    pos = terminal_pos - 1
    pos = @terminals.length - 1 if pos == -1
    terminal_show pos
  end

  # next
  def terminal_next
    if @terminals.length <= 1
      notify
      return
    end

    pos = terminal_pos + 1
    pos = 0 if pos == @terminals.length
    terminal_show pos
  end

  # close
  def terminal_close
    terminal_kill terminal_pos
  end

  # real kill
  def terminal_kill(pos)
    @hooks[:terminal_close].each do |cb|
      cb.call(@terminals[pos][:terminal], @terminals[pos][:pid])
    end

    @terminals[pos][:terminal].destroy
    @terminals.delete_at(pos)

    # we can quit
    if @terminals.empty? and @detached_terminals.empty?
      destroy

    # something detached...
    elsif @terminals.empty?
      terminal_attach

    # let's show the next one:
    else
      terminal_show pos
    end
  end

  # show the selected terminal
  def terminal_show(pos)
    pos = @terminals.length - 1 if pos >= @terminals.length

    # Notification
    notify pos

    if @window.children.length and
       @window.children[0] == @terminals[pos][:terminal]
      return
    end

    if @window.children.length > 0
      @window.remove @window.children[0]
    end

    @window.add @terminals[pos][:terminal]
    @terminals[pos][:terminal].grab_focus

    @hooks[:terminal_show].each do |cb|
      cb.call(@terminals[pos][:terminal], @terminals[pos][:pid])
    end
  end

  def terminal_copy
    terminal = @terminals[terminal_pos][:terminal]
    terminal.copy_clipboard if terminal.has_selection?
  end

  def terminal_paste
    terminal = @terminals[terminal_pos][:terminal]
    terminal.paste_clipboard
  end

  def terminal_kill_detached(terminal)
    @detached_terminals.each_with_index do |t, pos|
      if t[:terminal] == terminal
        terminal.destroy
        @detached_terminals.delete_at pos
        return
      end
    end
  end

  def terminal_detach
    pos = terminal_pos
    @detached_terminals.push(@terminals[pos])
    @terminals.delete_at pos

    terminal_new if @terminals.empty?
    terminal_show pos

    @notification.show('terminal detached')
  end

  def terminal_attach
    if @detached_terminals.empty?
      @notification.show('nothing to attach')
      return
    end

    last = @terminals.length
    @terminals += @detached_terminals.dup
    @detached_terminals = []
    terminal_show last

    @notification.show('detached terminal shown...')
  end

  def update_window_title(title)
    @window.title = title if title
  end

  # Buttons
  def button_pressed(terminal, event)
    string = terminal.match_check(event.x / terminal.char_width, event.y / terminal.char_height)
    return if string.nil? or string.empty?

    match = true
    @matches[:event].split(' ').each do |p|
      break if not match
      p.strip!
      if p.downcase == 'ctrl'
        match = event.state.control_mask?
      elsif p.downcase == 'shift'
        match = event.state.shift_mask?
      else
        match = event.button == p.to_i
      end
    end

    if match
      string, tag = string
      process_exec @matches[:rules][tag]['app'] + ' ' + Shellwords.escape(string)
    end
  end

  # Custom configuration

  def set_cwd(terminal, what)
    cwd = nil

    case what
      when 'home' then
        cwd = ENV['HOME']

      when 'previous' then
        if @window.children.length > 0
          cwd = get_path @terminals[terminal_pos][:pid]
        end

      else
        cwd = what
    end

    @terminals.last[:cwd] = cwd
  end

  def get_path(pid)
    begin
      return File.readlink("/proc/#{pid}/cwd")
    rescue
      return nil
    end
  end

  def set_colors(terminal, what)
    colors = []
    what.split(':').each do |c|
      colors.push(Gdk::Color.parse(c))
    end

    terminal.set_colors(@settings['color_foreground'],
                        @settings['color_background'], colors);
  end

  def set_backspace_binding(terminal, what)
    if what == 'ASCII_DELETE'
      terminal.set_backspace_binding Vte::Terminal::EraseBinding::ASCII_DELETE
    elsif what == 'ASCII_BACKSPACE'
      terminal.set_backspace_binding Vte::Terminal::EraseBinding::ASCII_BACKSPACE
    elsif what == 'AUTO'
      terminal.set_backspace_binding Vte::Terminal::EraseBinding::AUTO
    elsif what == 'DELETE_SEQUENCE'
      terminal.set_backspace_binding Vte::Terminal::EraseBinding::DELETE_SEQUENCE
    elsif what == 'TTY'
      terminal.set_backspace_binding Vte::Terminal::EraseBinding::TTY
    end
  end

  def set_delete_binding(terminal, what)
    if what == 'ASCII_DELETE'
      terminal.set_delete_binding Vte::Terminal::EraseBinding::ASCII_DELETE
    elsif what == 'ASCII_BACKSPACE'
      terminal.set_delete_binding Vte::Terminal::EraseBinding::ASCII_BACKSPACE
    elsif what == 'AUTO'
      terminal.set_delete_binding Vte::Terminal::EraseBinding::AUTO
    elsif what == 'DELETE_SEQUENCE'
      terminal.set_delete_binding Vte::Terminal::EraseBinding::DELETE_SEQUENCE
    elsif what == 'TTY'
      terminal.set_delete_binding Vte::Terminal::EraseBinding::TTY
    end
  end

  def setup_notifications
    @mutex = Mutex.new
    @notifications = []

    GLib::Timeout.add 200 do
      @mutex.lock
      @notifications.each do |n|
        if n.start_with? 'notify '
          @notification.show n[7..-1]
        elsif n.start_with? 'show'
          @window.show
          @window.present
        else
          @hooks[:notification_received].each do |cb|
            cb.call(n)
          end
        end
      end
      @notifications.clear
      @mutex.unlock
    end
  end

end

# Notification class
class Notification
  TIMEOUT = 100

  def initialize(config)
    @config = {}
    config.each do |c|
      @config[c[:key]] = c[:value]
    end

    @window = Gtk::Window.new Gtk::Window::POPUP
    @window.decorated = false
    @window.set_keep_above true
    @window.set_app_paintable true
    @window.window_position = Gtk::Window::POS_CENTER_ALWAYS

    @label = Gtk::Label.new
    @label.justify = Gtk::Justification::CENTER
    @window.add @label

    @window.signal_connect('expose-event') do expose end

    colormap = @window.screen.rgba_colormap
    @window.set_colormap @window.screen.rgba_colormap if not colormap.nil?

    @window.set_can_focus false
    @label.set_can_focus false

    @steps = 0
    @running = false
  end

  def hide
    @window.hide
  end

  def destroy
    @window.destroy
  end

  def show(text)
    @label.set_markup @config['markup'].sub("%s", text)
    @window.resize 1, 1
    @window.show_all

    @window.set_opacity 1
    @steps = @config['timeout'] / TIMEOUT

    if @running == false
      @running = true

      GLib::Timeout.add TIMEOUT do
        @steps -= 1

        if @steps == -1
          @window.hide
          @running = false
          false
        else
          @window.set_opacity @steps.to_f / (@config['timeout'] / TIMEOUT).to_f
          true
        end
      end
    end
  end

private
  def expose
    c = @window.window.create_cairo_context

    c.set_source_rgba(1.0, 1.0, 1.0, 0.0)
    c.set_operator Cairo::OPERATOR_SOURCE
    c.paint
    c.destroy

    false
  end
end

# Let's start!

@@bterm = BTerm.new
@@bterm.init
@@bterm.run
Gtk.main
