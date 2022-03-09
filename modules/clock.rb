def clock
  $bterm.notification.show Time.now.strftime("%a %b %d %Y %H:%M:%S")
end

def notification_received(what)
  clock if what == 'time'
end

$bterm.register_hooks :notification_received, method(:notification_received)
