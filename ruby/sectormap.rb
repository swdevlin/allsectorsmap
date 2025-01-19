require 'chunky_png'
require 'yaml'
require 'mini_magick'

SECTORS_ACROSS = 17
SECTORS_VERTICAL = 14
PIXEL_SIZE = 4

STAR_COLOUR = ChunkyPNG::Color::rgb(140,140,140)

class SectorLabel
  attr_accessor :x, :y, :name

  def initialize(x, y, name)
    @x = x
    @y = y
    @name = name
  end
end

labels = []

def add_stars(image, sector_definitions_path, sector_config)
  sector_path = File.join(sector_definitions_path, sector_config['name'])
  x_offset = (26 + sector_config['X']) * PIXEL_SIZE * 32
  y_offset = (-1 - sector_config['Y']) * PIXEL_SIZE * 40
  puts "x #{sector_config['X']} y #{sector_config['Y']} #{sector_config['name']}"
  Dir.foreach(sector_path) do |file_name|
    next unless file_name.match(/^\d{4}\.txt$/)

    xx = file_name[0..1].to_i
    yy = file_name[2..3].to_i

    if xx.between?(1, 32) && yy.between?(1, 40)
      x_start = (xx - 1) * PIXEL_SIZE + x_offset
      y_start = (yy - 1) * PIXEL_SIZE + y_offset
      (0..1).each do |dx|
        (0..1).each do |dy|
          image[x_start + dx, y_start + dy] = STAR_COLOUR
        end
      end
    else
      puts "Invalid coordinates in file name: #{file_name}"
    end
  end
end

def draw_grid(image)
  sector_colour = ChunkyPNG::Color.rgb(172, 172, 172)
  subsector_colour = ChunkyPNG::Color.rgb(40, 40, 40)

  image_width = SECTORS_ACROSS * 32 * PIXEL_SIZE
  image_height = SECTORS_VERTICAL * 40 * PIXEL_SIZE

  xstep = if PIXEL_SIZE > 2 then 8 * PIXEL_SIZE else 32 * PIXEL_SIZE end
  ystep = if PIXEL_SIZE > 2 then 10 * PIXEL_SIZE else 40 * PIXEL_SIZE end

  (0...image_width).step(xstep).each do |x|
    (0...image_height).each do |y|
      colour = if x % (32*PIXEL_SIZE) == 0 then sector_colour else subsector_colour end
      image[x, y] = colour if x > 0
    end
  end

  (0...image_height).step(ystep).each do |y|
    (0...image_width).each do |x|
      colour = if y % (40*PIXEL_SIZE) == 0 then sector_colour else subsector_colour end
      image[x, y] = colour if y > 0
    end
  end
end

def generate_sectors_image(sector_definitions_path, sector_output_path, output_path)
  unless Dir.exist?(sector_definitions_path)
    puts "Folder does not exist: #{sector_definitions_path}"
    return
  end

  labels = []
  image = ChunkyPNG::Image.new(32 * SECTORS_ACROSS * PIXEL_SIZE, 40 * SECTORS_VERTICAL * PIXEL_SIZE, ChunkyPNG::Color::BLACK)

  Dir.foreach(sector_definitions_path) do |file_name|
    next unless file_name.match(/\.yaml$/)
    sector_config = YAML.load_file(File.join(sector_definitions_path, file_name))

    labels << SectorLabel.new(sector_config['X'], sector_config['Y'], sector_config['abbreviation'])

    add_stars(image, sector_output_path, sector_config)
  end

  draw_grid(image)

  # Save the image
  image.save(output_path)
  add_sector_labels(output_path, labels)
  puts "Image saved to #{output_path}"
end

def add_sector_labels(output_path, labels)
  rotation = -45
  point_size = 20

  MiniMagick::Tool::Convert.new do |convert|
    convert.background 'none'
    convert.pointsize point_size.to_s
    convert.fill 'red'
    labels.each do |label|
      x = (26 + label.x) * PIXEL_SIZE * 32 + 16 * PIXEL_SIZE
      y = (-1 - label.y) * PIXEL_SIZE * 40 + 20 * PIXEL_SIZE

      # Calculate approximate text dimensions
      text_width = label.name.length * point_size * 0.6 # Approx. width of the text
      text_height = point_size                         # Approx. height of the text

      # Offset to centre text
      x_offset = -text_width / 2
      y_offset = text_height / 2

      # Adjust for rotation
      rad = Math::PI * rotation / 180.0 # Convert rotation to radians
      rotated_x_offset = x_offset * Math.cos(rad) - y_offset * Math.sin(rad)
      rotated_y_offset = x_offset * Math.sin(rad) + y_offset * Math.cos(rad)

      convert.draw "translate #{x+rotated_x_offset},#{y+rotated_y_offset} rotate #{rotation} text 0,0 '#{label.name}'"
    end
    convert << output_path
    convert << "labels.png"
  end
end

if __FILE__ == $PROGRAM_NAME
  if ARGV.length != 2
    puts "Usage: ruby sectorsmap.rb <path_to_sector_definitions>"
    exit
  end

  sector_definitions_path = ARGV[0]
  sector_output_path = ARGV[1]
  output_path = "./sectors.png"
  output_path
  generate_sectors_image(sector_definitions_path, sector_output_path, output_path)
end
