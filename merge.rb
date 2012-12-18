#!/usr/bin/ruby

require 'image_merger'

front = ARGV[0]
back = ARGV[1]
outname = ARGV[2]
formula = ARGV[3]
num = ARGV[4] || 10
delay = ARGV[5] || 10

merger = ImageMerger.new(front, back, outname, formula., num, delay)
merger.create_frames
merger.create_animation
merger.write_log