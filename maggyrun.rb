#!/Users/matthew/.rvm/rubies/ruby-1.9.3-p286/bin/ruby
require './maggy.rb'

front = "INTPUT1"
back = "INPUT2"
outname = "OUTNAME"

maggy = FrontGrowsDownBack.new(front, back, outname, 10)
maggy.create_frames
maggy.create_animation
Maggy.create_small_animation(outname, 500, 64, maggy.log)
maggy.write_log