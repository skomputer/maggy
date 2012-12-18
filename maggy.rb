class Maggy
  attr_accessor :formula
  attr_accessor :num
  attr_accessor :delay
  attr_accessor :debug
  attr_accessor :size
  attr_accessor :formula

  def initialize(front, back, outname, formula, num=10, delay=10)
    @front = front
    @back = back
    @outname = outname
    @formula = Kernel.const_get(formula).new
    @formula.merger = self
    @num = num
    @delay = delay

    @debug = true
    @size = "612x612"
    @frames = []
    @log = []
  end

  def use_background(type)
    @background = case type
      when :black then "0"
      when :white then "1"
      when :front then "u"
      when :back then "v"
      else "0"
    end
  end

  def background
    @background || "0"
  end
    
  def create_frames
    ensure_dirs
    create_first_frame

    (1..@num).to_a.each do |i|
      run_command "convert #{@front} #{@back} -fx \"#{get_formula(i)}\" #{frame_path(i)}"
      @frames[i] = frame_path(i)
    end
  end

  def create_first_frame
    formula.create_first_frame
  end
    
  def create_black_frame(num)
    create_frame("-size #{size} xc:black", num)
  end

  def create_white_frame(num)
    create_frame("-size #{size} xc:white", num)
  end

  def create_front_frame(num)
    create_frame(@front, num)
  end

  def create_back_frame(num)
    create_frame(@back, num)
  end

  def create_frame(command, num)
    ensure_dirs
    run_command "convert #{command} #{frame_path(num)}"
    @frames[num] = frame_path(num)    
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

  def create_animation
    ensure_dirs
    
    run_command "convert -delay #{@delay} -loop 0 #{@frames.join(' ')} #{animation_path}"
  end
  
  def write_log
    ensure_dirs
    File.open(log_path, "w") do |file|
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

  def animation_path
    "#{@outname}/#{@outname}.gif"
  end

  def log_path
    "#{@outname}/#{@outname}.log"
  end

  def frame_path(num, format="jpg")
    "#{@outname}/frames/#{@outname}-#{frame_num_str(num)}.#{format}"
  end

  def ensure_dirs
    Dir.mkdir(@outname) unless File.directory?(@outname)
    Dir.mkdir(@outname + "/frames") unless File.directory?(@outname + "/frames")
  end

  def run_command(str)
    system(str)
    print str + "\n" if debug == true
    @log << str
  end

end



class MaggyFormula
  attr_accessor :merger

  def self.ref_to_code(ref)
    case ref
      when :black then "0"
      when :white then "1"
      when :front then "u"
      when :back then "v"
      else "0"
    end
  end  

  def initialize
    @yes_match = :back
    @no_match = :black
    @buffer = 1 
  end
  
  def generate(frame, num)    
    min = range_min(frame, num, @buffer)
    max = range_max(frame, num, @buffer)
    intensity_filter(min, max, self.class.ref_to_code(@yes_match), self.class.ref_to_code(@no_match))
  end

  def create_first_frame
    merger.create_black_frame(0)
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

  def initialize
    @yes_match = :front
    @no_match = :back
    @buffer = 1
  end
  
  def create_first_frame
    merger.create_back_frame(0)
  end

end

class BackSweepsOverFront < MaggyFormula

  def initialize
    @yes_match = :back
    @no_match = :front
    @buffer = 1
  end

  def create_first_frame
    merger.create_front_frame(0)
  end

end

class FrontFillsBack < MaggyFormula
  
  def initialize
    @yes_match = :front
    @no_match = :back
    @buffer = 0
  end

  def range_min(frame, num, buffer=1)
    0
  end

  def create_first_frame
    merger.create_back_frame(0)
  end

end

class FrontFallsFromBack < MaggyFormula
  
  def initialize
    @yes_match = :front
    @no_match = :back
    @buffer = 0
  end

  def range_min(frame, num, buffer=1)
    0
  end

  def range_max(frame, num, buffer=1)
    (num-frame)/num.to_f
  end

  def create_first_frame
    merger.create_front_frame(0)
  end

end

class FrontEmptiesFromBack < MaggyFormula
  
  def initialize
    @yes_match = :front
    @no_match = :back
  end

  def generate(frame, num)    
    max = (num-frame)/num.to_f
    min = 0
    intensity_filter(min, max, self.class.ref_to_code(@yes_match), self.class.ref_to_code(@no_match))
  end

  def create_first_frame
    merger.create_front_frame(0)
  end

end

class PeelOffFront < MaggyFormula
  
  def initialize
    @yes_match = :front
    @no_match = :back
  end

  def generate(frame, num)    
    max = 1
    min = frame/num.to_f
    intensity_filter(min, max, self.class.ref_to_code(@yes_match), self.class.ref_to_code(@no_match))
  end

  def create_first_frame
    merger.create_front_frame(0)
  end

end

class FrontLevelExposesBack < MaggyFormula

  def initialize
    @yes_match = :back
    @no_match = :black
    @buffer = 1
  end

  def create_first_frame
    merger.create_black_frame(0)
  end
  
end