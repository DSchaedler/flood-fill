# frozen_string_literal: true

PIXELS_PER_TICK = 1000
PIXELS_PER_TICK_MAX = 5000
PIXELS_PER_TICK_MIN = 1
PIXEL_PER_TICK_INC = 25
CALC_TIME_MIN = 0.010
CALC_TIME_MAX = 0.015
PIXEL_SIZE = 1

def reset_all(_args)
  $p_per_tick = nil
  $triangle = nil
  $lines = nil
  $center = nil
  $pixels = nil
  $pixels_holding = nil
  $passes = nil
  $gtk.reset seed: Time.now.to_i
end

def tick(args) # rubocop:disable Metrics/AbcSize
  args.gtk.log_level = :off
  args.render_target(:pixels).clear_before_render = false unless args.state.tick_count.zero?

  tick_zero(args) if args.state.tick_count.zero?

  $p_per_tick ||= PIXELS_PER_TICK

  if $pixels_holding.length > 0
    pre_time = Time.now
    flood_fill(args)
    calc_time = Time.now - pre_time
    if calc_time > CALC_TIME_MAX
      $p_per_tick -= PIXEL_PER_TICK_INC unless $p_per_tick <= PIXELS_PER_TICK_MIN
    elsif calc_time < CALC_TIME_MIN
      $p_per_tick += PIXEL_PER_TICK_INC unless $p_per_tick >= PIXELS_PER_TICK_MAX
    end
  end

  args.outputs.labels << { x: 0, y: 360, text: "calc time: #{calc_time}" }
  args.outputs.labels << { x: 0, y: 340, text: "p_per_tick: #{$p_per_tick}" }

  args.outputs.sprites << { x: 0, y: 0, w: 1280, h: 720, path: :pixels }

  reset_button(args)

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
  center[:x] = center[:x] - ( (center[:x] % PIXEL_SIZE) + ($triangle[0][:x] % PIXEL_SIZE))
  center[:y] = center[:y] - ( (center[:y] % PIXEL_SIZE) + ($triangle[0][:y] % PIXEL_SIZE))

  $pixels_holding[center] = center

  $pixels.each do |key_x, value|
    value.each_key do |key_y|
      args.render_target(:pixels).solids << { x: key_x, y: key_y, w: PIXEL_SIZE, h: PIXEL_SIZE }
    end
  end
end

def reset_button(args)
  button_box = { x: args.grid.center_x - 50, y: args.grid.top - 50, w: 100, h: 50 }
  args.outputs.borders << button_box
  args.outputs.labels << { x: args.grid.center_x, y: args.grid.top - 15, text: 'Reset', alignment_enum: 1 }

  reset_all(args) if args.inputs.mouse.up.inside_rect? button_box
end

def pick_vertecies(_args)
  point = {}
  max_x = 1280 / PIXEL_SIZE
  max_y = 720 / PIXEL_SIZE
  point[0] = { x: (1..max_x).to_a.sample * PIXEL_SIZE, y: (1..max_y).to_a.sample * PIXEL_SIZE }
  point[1] = { x: (1..max_x).to_a.sample * PIXEL_SIZE, y: (1..max_y).to_a.sample * PIXEL_SIZE }
  point[2] = { x: (1..max_x).to_a.sample * PIXEL_SIZE, y: (1..max_y).to_a.sample * PIXEL_SIZE }
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
  ystep = y1 < y2 ? PIXEL_SIZE : -PIXEL_SIZE

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
    x1 += PIXEL_SIZE
  end
  pixels
end

def flood_fill(args)
  # $pixels_to_check = $pixels_holding.dup

  times = $p_per_tick
  pixels_to_rt = []

  while times.positive?

    break if $pixels_holding.size.zero?

    pixel = $pixels_holding.shift[0]
    $pixels[pixel[:x]] ||= {}
    $pixels[pixel[:x]][pixel[:y]] = true
    pixels_to_rt << PixelNew.new(pixel[:x], pixel[:y])

    next_pixel0 = { x: pixel[:x] - PIXEL_SIZE, y: pixel[:y] }
    $pixels[next_pixel0[:x]] ||= {}
    $pixels_holding[next_pixel0] = next_pixel0 unless $pixels_holding.include?(next_pixel0) || $pixels[next_pixel0[:x]][next_pixel0[:y]]

    next_pixel1 = { x: pixel[:x] + PIXEL_SIZE, y: pixel[:y] }
    $pixels[next_pixel1[:x]] ||= {}
    $pixels_holding[next_pixel1] = next_pixel1 unless $pixels_holding.include?(next_pixel1) || $pixels[next_pixel1[:x]][next_pixel1[:y]]

    next_pixel2 = { x: pixel[:x], y: pixel[:y] - PIXEL_SIZE }
    $pixels[next_pixel2[:x]] ||= {}
    $pixels_holding[next_pixel2] = next_pixel2 unless $pixels_holding.include?(next_pixel2) || $pixels[next_pixel2[:x]][next_pixel2[:y]]

    next_pixel3 = { x: pixel[:x], y: pixel[:y] + PIXEL_SIZE }
    $pixels[next_pixel3[:x]] ||= {}
    $pixels_holding[next_pixel3] = next_pixel3 unless $pixels_holding.include?(next_pixel3) || $pixels[next_pixel3[:x]][next_pixel3[:y]]

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
    ffi.draw_sprite(@x, @y, PIXEL_SIZE, PIXEL_SIZE, 'pixel')
    #ffi.draw_sprite(@x, @y, PIXEL_SIZE, PIXEL_SIZE, 'sprites/circle.png')
  end
end
