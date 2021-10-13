# frozen_string_literal: true

PIXELS_PER_TICK = 1000
PIXELS_PER_TICK_MAX = 5000
PIXELS_PER_TICK_MIN = 1
PIXEL_PER_TICK_INC = 25
PIXEL_SIZE = 1

def tick(args) # rubocop:disable Metrics/AbcSize
  args.gtk.log_level = :off
  args.render_target(:pixels).clear_before_render = false

  tick_zero(args) if args.state.tick_count.zero?

  $p_per_tick ||= PIXELS_PER_TICK

  pre_time = Time.now
  flood_fill(args)  
  calc_time = Time.now - pre_time
  if calc_time > 0.02
    $p_per_tick -= PIXEL_PER_TICK_INC unless $p_per_tick <= PIXELS_PER_TICK_MIN
  elsif calc_time < 0.01
    $p_per_tick += PIXEL_PER_TICK_INC unless $p_per_tick >= PIXELS_PER_TICK_MAX
  end
  args.outputs.labels << {x: 0, y: 700, text: "calc time: #{calc_time}"}
  args.outputs.labels << {x: 0, y: 680, text: "p_per_tick: #{$p_per_tick}"}

  args.outputs.sprites << { x: 0, y: 0, w: 1280, h: 720, path: :pixels }
  args.outputs.debug << args.gtk.framerate_diagnostics_primitives
end

def tick_zero(args) # rubocop:disable Metrics/AbcSize
  $triangle ||= pick_vertecies(args)
  $lines ||= make_lines(args, $triangle)
  $center ||= get_center($triangle)

  $pixels ||= {}
  bressenham(args, $lines[0])
  bressenham(args, $lines[1])
  bressenham(args, $lines[2])

  $pixels_holding ||= {}
  center = { x: $center[:x], y: $center[:y] }
  $pixels_holding[center] = center

  $pixels.each do |key_x, value|
    value.each_key do |key_y|
      args.render_target(:pixels).solids << { x: key_x, y: key_y, w: 1, h: 1 }
    end
  end

  $passes ||= 100
end

def pick_vertecies(_args)
  point = {}
  point[0] = { x: (1..1279).to_a.sample, y: (1..719).to_a.sample }
  point[1] = { x: (1..1279).to_a.sample, y: (1..719).to_a.sample }
  point[2] = { x: (1..1279).to_a.sample, y: (1..719).to_a.sample }
  point
end

def make_lines(_args, point) # rubocop:disable Metrics/AbcSize
  lines = []
  lines << { x: point[0].x, y: point[0].y, x2: point[1].x, y2: point[1].y }
  lines << { x: point[1].x, y: point[1].y, x2: point[2].x, y2: point[2].y }
  lines << { x: point[2].x, y: point[2].y, x2: point[0].x, y2: point[0].y }
end

def get_center(point) # rubocop:disable Metrics/AbcSize
  { x: ((point[0].x + point[1].x + point[2].x) / 3).to_i, y: ((point[0].y + point[1].y + point[2].y) / 3).to_i }
end

def bressenham(_args, line)
  x1 = line[:x]
  y1 = line[:y]
  x2 = line[:x2]
  y2 = line[:y2]

  steep = (y2 - y1).abs > (x2 - x1).abs

  if steep
    x1, y1 = y1, x1
    x2, y2 = y2, x2
  end

  if x1 > x2
    x1, x2 = x2, x1
    y1, y2 = y2, y1
  end

  deltax = x2 - x1
  deltay = (y2 - y1).abs
  error = deltax / 2
  ystep = y1 < y2 ? 1 : -1

  pixels = {}
  y = y1
  while x1 < x2
    if steep
      pixel_x = y
      pixel_y = x1
    else
      pixel_x = x1
      pixel_y = y
    end
    $pixels[pixel_x] ||= {}
    $pixels[pixel_x][pixel_y] = true
    error -= deltay
    if error.negative?
      y += ystep
      error += deltax
    end
    x1 += 1
  end
  pixels
end

def flood_fill(args)
  # $pixels_to_check = $pixels_holding.dup

  times = $p_per_tick
  pixels_to_rt = []

  return if $pixels_holding.empty?


  while times.positive?

    break unless $pixels_holding.first

    key, pixel = $pixels_holding.first
    $pixels[pixel[:x]] ||= {}
    $pixels[pixel[:x]][pixel[:y]] = true
    pixels_to_rt << PixelNew.new(pixel[:x], pixel[:y])

    $pixels_holding.shift

    next_pixel0 = { x: pixel[:x] - PIXEL_SIZE, y: pixel[:y] }
    $pixels[next_pixel0[:x]] ||= {}
    $pixels_holding[next_pixel0] = next_pixel0 unless $pixels[next_pixel0[:x]][next_pixel0[:y]] || $pixels_holding.include?(next_pixel0)

    next_pixel1 = { x: pixel[:x] + PIXEL_SIZE, y: pixel[:y] }
    $pixels[next_pixel1[:x]] ||= {}
    $pixels_holding[next_pixel1] = next_pixel1 unless $pixels[next_pixel1[:x]][next_pixel1[:y]] || $pixels_holding.include?(next_pixel1)

    next_pixel2 = { x: pixel[:x], y: pixel[:y] - PIXEL_SIZE }
    $pixels[next_pixel2[:x]] ||= {}
    $pixels_holding[next_pixel2] = next_pixel2 unless $pixels[next_pixel2[:x]][next_pixel2[:y]] || $pixels_holding.include?(next_pixel2)

    next_pixel3 = { x: pixel[:x], y: pixel[:y] + PIXEL_SIZE }
    $pixels[next_pixel3[:x]] ||= {}
    $pixels_holding[next_pixel3] = next_pixel3 unless $pixels[next_pixel3[:x]][next_pixel3[:y]] || $pixels_holding.include?(next_pixel3)

    times -= 1
  end


  args.render_target(:pixels).sprites << pixels_to_rt
end

# Class to remove erronious draw calls
class PixelNew
  attr_sprite
  def initialize(x, y)
    @x = x
    @y = y
  end

  def draw_override(ffi)
    ffi.draw_sprite(@x, @y, 1, 1, 'sprites/pixel.png')
  end
end
