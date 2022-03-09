class FontModule
  def initialize
    @terminals = {}
    @pid = nil
  end

  def terminal_new(terminal, pid)
    @terminals[pid] = { :terminal => terminal, :scale => 1 }
  end

  def terminal_close(terminal, pid)
    @terminals.delete(pid)
    @pid = nil if pid == @pid
  end

  def terminal_show(terminal, pid)
    @pid = pid
  end

  def set_scale()
    return if @pid.nil?
    @terminals[@pid][:terminal].set_font_scale @terminals[@pid][:scale]
  end

  def plus()
    return if @pid.nil?
    @terminals[@pid][:scale] += 0.1
    set_scale();
  end

  def minus()
    return if @pid.nil?
    @terminals[@pid][:scale] -= 0.1
    set_scale();
  end

  def reset()
    return if @pid.nil?
    @terminals[@pid][:scale] = 1
    set_scale();
  end
end

$fontModule = FontModule.new

$bterm.register_hooks :terminal_new, $fontModule.method(:terminal_new)
$bterm.register_hooks :terminal_show, $fontModule.method(:terminal_show)
$bterm.register_hooks :terminal_close, $fontModule.method(:terminal_close)

def font_plus()
  $fontModule.plus
end

def font_minus()
  $fontModule.minus
end

def font_reset()
  $fontModule.reset
end
