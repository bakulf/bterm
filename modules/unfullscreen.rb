@window = false

# Set the bterm to half width
def unfullscreen_height

  return unless @window

  @window.decorated = true
  @window.set_resizable(true)

  # Resize the width of the window
  width = @window.screen.width
  height = @window.screen.height

  # We need to change the minimum size of the window
  min_width = width / 4
  min_height = height / 4
  @window.set_size_request(min_width, min_height)
  #puts "height: #{width} / #{height}"

  @window.unfullscreen

  # then we can resize to a smaller size
  new_height = height / 2
  @window.move(0, 0)
  @window.resize(width, new_height)
end

# Set the bterm to half height
def unfullscreen_width

  return unless @window

  @window.decorated = true
  @window.set_resizable(true)

  # Resize the width of the window
  width = @window.screen.width
  height = @window.screen.height
 
  # We need to change the minimum size of the window
  min_width = width / 4
  min_height = height / 4
  @window.set_size_request(min_width, min_height)
  #puts "width : #{width} / #{height}"

  @window.unfullscreen

  # then we can resize to a smaller size
  new_width = width / 2 
  @window.move(0, 0)
  @window.resize( new_width , height)
end

# Restore fullwidth for bterm
def fullscreen

  return unless @window

  # Restore the original dimensions and fullscreen
  @window.set_default_size(-1, -1)
  @window.move(0,0)
  @window.fullscreen
  @window.decorated = false
end

def window_created(window)
  @window = window
end

$bterm.register_hooks :window_created, method(:window_created)
