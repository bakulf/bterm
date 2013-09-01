def clock
  @@bterm.notification.show Time.now.strftime("%a %b %d %Y %H:%M:%S")
end
