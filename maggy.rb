require 'rmagick'
require 'pry'

class Maggy
  @@output_path = "output"
  @@debug = true

  attr_accessor :num
  attr_accessor :delay
  attr_accessor :width
  attr_accessor :height
  attr_accessor :formula
  attr_accessor :log

  def initialize(front, back, outname, num=10)
    @front = Magick::Image.read(front).first
    @back = Magick::Image.read(back).first
    @outname = outname
    @num = num
    @delay = 10
    @output_paths = []
    @log = []

    setup
    ensure_dirs    
    compute_width
    compute_height
  end
  
  def setup
  end
  
  def compute_width
    width = [@front.columns, @back.columns].min
  end

  def compute_height
    height = [@front.rows, @back.rows].min
  end  
  
  def output_path  
    @@output_path
  end
  
  def output_path=(path)
    @@output_path = path
  end

  def self.debug
    @@debug
  end
  
  def self.debug=(value)
    @@debug = value
  end
    
  def create_frames
    ensure_dirs
    create_zero_frame
    (1..num).to_a.each do |i|
      
      self.class.run_command("convert #{@front.base_filename} #{@back.base_filename} -fx \"#{generate(i, num)}\" #{frame_output_path(i)}", @log)
      @output_paths[i] = frame_output_path(i)
    end
  end

  def zero_frame
    :black
  end

  def create_zero_frame
    send("create_#{zero_frame}_frame", 0)
  end
    
  def create_black_frame(num)
    create_frame("-size #{width}x#{height} xc:black", num)
  end

  def create_white_frame(num)
    create_frame("-size #{size} xc:white", num)
  end

  def create_front_frame(num)
    create_frame(@front.base_filename, num)
  end

  def create_back_frame(num)
    create_frame(@back.base_filename, num)
  end

  def create_frame(command, num)
    ensure_dirs
    self.class.run_command("convert #{command} #{frame_output_path(num)}", @log)
    @output_paths[num] = frame_output_path(num)    
  end

  def get_formula(frame)
    # self.send(@formula.to_s, frame)
    formula.generate(frame, num)
  end

  def front_level_exposes_back(frame)
    spread = 1/@num.to_f
    max = frame/@num.to_f + spread
    min = (frame-1)/@num.to_f - spread
    "(intensity >= #{min} && intensity <= #{max}) ? v : #{background}"  
  end

  def fill_front_black_over_back(frame)
    max = 1
    min = (frame-1)/@num.to_f
    "(intensity >= #{min} && intensity <= #{max}) ? v : 0"  
  end

  def fill_front_over_back(frame)
    max = 1
    min = (frame-1)/@num.to_f
    "(intensity >= #{min} && intensity <= #{max}) ? v : u"  
  end

  def reverse_fill_front_over_back(frame)
    max = 1
    min = (@num-frame+1)/@num.to_f
    "(intensity >= #{min} && intensity <= #{max}) ? v : u"  
  end

  def self.command?(command)
    system("which #{ command} > /dev/null 2>&1")
  end

  def create_animation
    ensure_dirs
    
    self.class.run_command("convert -delay #{@delay} -loop 0 #{filename_list} #{animation_output_path}", @log)
  end

  def self.create_small_animation(outname, width=500, colors=64, log=nil)
    return false unless animation_exists?(outname)
    run_command("convert #{animation_output_path(outname)} -resize #{width} -colors #{colors} #{small_animation_output_path(outname)}", log)
  end

  def self.animation_exists?(outname)
    File.exists?(animation_output_path(outname))
  end

  def filename_list
    @output_paths.join(' ')
  end
    
  def write_log
    ensure_dirs
    File.open(log_output_path, "w") do |file|
      @log.each do |line|
        file.write(line + "\n")
      end
      file.close
    end    
  end  

  private
  
  def frame_num_str(num)
    "%03i" % num
  end

  def self.project_output_path(outname)
    @@output_path + "/" + outname
  end

  def project_output_path
    self.class.project_output_path(@outname)
  end

  def log_output_path
    project_output_path + "/#{@outname}.log"
  end

  def frames_output_path
    project_output_path + "/frames"
  end

  def frame_output_path(num, format="jpg")
    frames_output_path + "/#{@outname}-#{frame_num_str(num)}.#{format}"
  end

  def self.animation_output_path(outname)
    project_output_path(outname) + "/#{outname}.gif"
  end
  
  def animation_output_path
    self.class.animation_output_path(@outname)
  end

  def self.small_animation_output_path(outname)
    project_output_path(outname) + "/#{outname}_small.gif"  
  end

  def small_animation_output_path
    self.class.small_animation_output_path(@outname)
  end
    
  def ensure_dirs
    Dir.mkdir(output_path) unless File.directory?(output_path)
    Dir.mkdir(project_output_path) unless File.directory?(project_output_path)
    Dir.mkdir(frames_output_path) unless File.directory?(frames_output_path)
  end

  def self.run_command(str, log=nil)
    system(str)
    print str + "\n" if debug == true
    log << str unless log.nil?
  end

end



class MaggyFormula < Maggy
  attr_accessor :front_channel
  attr_accessor :back_channel
  attr_accessor :first_frame

  def self.ref_to_code(ref)
    case ref
      when :black then "0"
      when :white then "1"
      when :front then "u"
      when :back then "v"
      else "0"
    end
  end  

  def setup
    @front_channel = :back
    @back_channel = :black
    @buffer = 1 
  end
  
  def generate(frame, num)    
    min = range_min(frame, num, @buffer)
    max = range_max(frame, num, @buffer)
    intensity_filter(min, max, self.class.ref_to_code(@front_channel), self.class.ref_to_code(@back_channel))
  end

  def zero_frame
    :black
  end

  def range_min(frame, num, buffer=1)
    spread = buffer/(2*num.to_f)
    (frame-1)/num.to_f - spread    
  end

  def range_max(frame, num, buffer=1)
    spread = buffer/(2*num.to_f)
    frame/num.to_f + spread
  end

  def intensity_filter(min, max, on, off)
    "(intensity >= #{min} && intensity <= #{max}) ? #{on} : #{off}"
  end

end

class FrontSweepsOverBack < MaggyFormula

  def setup
    @front_channel = :front
    @back_channel = :back
    @buffer = 1
  end
  
  def zero_frame
    :back
  end

end

class BackSweepsOverFront < MaggyFormula

  def setup
    @front_channel = :back
    @back_channel = :front
    @buffer = 1
  end

  def zero_frame
    :front
  end


end

class FrontFillsBack < MaggyFormula
  
  def setup
    @front_channel = :front
    @back_channel = :back
    @buffer = 0
  end

  def range_min(frame, num, buffer=1)
    0
  end

  def zero_frame
    :back
  end

end

class FrontFallsFromBack < MaggyFormula
  
  def setup
    @front_channel = :front
    @back_channel = :back
    @buffer = 0
  end

  def range_min(frame, num, buffer=1)
    0
  end

  def range_max(frame, num, buffer=1)
    (num-frame)/num.to_f
  end

  def zero_frame
    :front
  end

end

class FrontGrowsDownBack < MaggyFormula
  
  def setup
    @front_channel = :front
    @back_channel = :back
    @buffer = 0
  end

  def range_min(frame, num, buffer=1)
    (num-frame)/num.to_f
  end

  def range_max(frame, num, buffer=1)
    1
  end

  def zero_frame
    :back
  end


end

class FrontEmptiesFromBack < MaggyFormula
  
  def setup
    @front_channel = :front
    @back_channel = :back
  end

  def generate(frame, num)    
    max = (num-frame)/num.to_f
    min = 0
    intensity_filter(min, max, self.class.ref_to_code(@front_channel), self.class.ref_to_code(@back_channel))
  end

  def zero_frame
    :front
  end


end

class BackFillsFront < MaggyFormula
  
  def setup
    @front_channel = :front
    @back_channel = :back
  end

  def generate(frame, num)    
    max = 1
    min = frame/num.to_f
    intensity_filter(min, max, self.class.ref_to_code(@front_channel), self.class.ref_to_code(@back_channel))
  end

  def zero_frame
    :front
  end


end

class FrontLevelExposesBack < MaggyFormula

  def setup
    @front_channel = :back
    @back_channel = :black
    @buffer = 1
  end

  def zero_frame
    :black
  end
  
end