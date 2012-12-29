#!/Users/matthew/.rvm/rubies/ruby-1.9.3-p286/bin/ruby
require './maggy.rb'

front = "example/the_bow_calgary.jpg"
back = "example/alberta_tar_sands.jpg"
outname = "tar_sands"

maggy = BackSweepsOverFront.new(front, back, outname, 10)
maggy.create_frames
maggy.create_animation
Maggy.create_small_animation(outname, 500, 64, maggy.log)
maggy.write_log