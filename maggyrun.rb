#!/usr/bin/ruby

require 'maggy'

front = ARGV[0]
back = ARGV[1]
outname = ARGV[2]
formula = ARGV[3]
num = ARGV[4] || 10
delay = ARGV[5] || 10

maggy = Maggy.new(front, back, outname, formula, num, delay)
maggy.create_frames
maggy.create_animation
maggy.write_log