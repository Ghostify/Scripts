cmd = `pgrep phantomjs`
puts cmd
if cmd != nil
  puts "Yay!"
else
  puts "Boo!"
end
