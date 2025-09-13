# Crayola 64 color palette (representative subset of the full 128)
# For a full implementation, you would include all 128 colors
CRAYOLA_COLORS = [
  { name: "Red", hex: "#EE204D" },
  { name: "Blue", hex: "#1F75FE" },
  { name: "Yellow", hex: "#FCE883" },
  { name: "Green", hex: "#1CAC78" },
  { name: "Orange", hex: "#FF7538" },
  { name: "Purple", hex: "#9C51B6" },
  { name: "Brown", hex: "#AF593E" },
  { name: "Black", hex: "#000000" },
  { name: "White", hex: "#FFFFFF" },
  { name: "Pink", hex: "#FC74FD" },
  { name: "Gray", hex: "#95918C" },
  { name: "Turquoise Blue", hex: "#6CDAE7" },
  { name: "Violet", hex: "#732E6C" },
  { name: "Sky Blue", hex: "#76D7EA" },
  { name: "Forest Green", hex: "#5FA777" },
  { name: "Maroon", hex: "#C32148" },
  { name: "Navy Blue", hex: "#1974D2" },
  { name: "Tan", hex: "#FA9A85" },
  { name: "Silver", hex: "#C9C0BB" },
  { name: "Gold", hex: "#E7C697" },
  { name: "Magenta", hex: "#F653A6" },
  { name: "Lime Green", hex: "#32CD32" },
  { name: "Aqua", hex: "#00FFFF" },
  { name: "Hot Pink", hex: "#FF69B4" },
  { name: "Dark Blue", hex: "#003366" },
  { name: "Light Blue", hex: "#ADD8E6" },
  { name: "Yellow Green", hex: "#C5E384" },
  { name: "Orange Red", hex: "#FF4500" },
  { name: "Dark Green", hex: "#228B22" },
  { name: "Light Green", hex: "#90EE90" },
  { name: "Salmon", hex: "#FA8072" },
  { name: "Peach", hex: "#FFCBA4" },
  { name: "Lavender", hex: "#E6E6FA" },
  { name: "Coral", hex: "#FF7F50" },
  { name: "Crimson", hex: "#DC143C" },
  { name: "Indigo", hex: "#4B0082" },
  { name: "Mint Green", hex: "#98FB98" },
  { name: "Royal Blue", hex: "#4169E1" },
  { name: "Teal", hex: "#008080" },
  { name: "Khaki", hex: "#F0E68C" },
  { name: "Plum", hex: "#DDA0DD" },
  { name: "Olive", hex: "#808000" },
  { name: "Beige", hex: "#F5F5DC" },
  { name: "Ivory", hex: "#FFFFF0" },
  { name: "Chocolate", hex: "#D2691E" },
  { name: "Sienna", hex: "#A0522D" },
  { name: "Peru", hex: "#CD853F" },
  { name: "Saddle Brown", hex: "#8B4513" },
  { name: "Dark Orange", hex: "#FF8C00" },
  { name: "Dark Red", hex: "#8B0000" },
  { name: "Dark Violet", hex: "#9400D3" },
  { name: "Medium Blue", hex: "#0000CD" },
  { name: "Light Coral", hex: "#F08080" },
  { name: "Pale Green", hex: "#98FB98" },
  { name: "Light Yellow", hex: "#FFFFE0" },
  { name: "Dark Cyan", hex: "#008B8B" },
  { name: "Medium Purple", hex: "#9370DB" },
  { name: "Deep Pink", hex: "#FF1493" },
  { name: "Medium Sea Green", hex: "#3CB371" },
  { name: "Light Steel Blue", hex: "#B0C4DE" },
  { name: "Pale Turquoise", hex: "#AFEEEE" },
  { name: "Medium Orchid", hex: "#BA55D3" },
  { name: "Light Salmon", hex: "#FFA07A" },
  { name: "Powder Blue", hex: "#B0E0E6" }
].freeze

class ImageProcessingService
  def initialize(image)
    @image = image
  end

  def process!
    @image.update!(status: "processing")

    begin
      # Download and process the original image
      original_blob = @image.original_image.blob
      temp_file = download_blob_to_tempfile(original_blob)

      # Load image with ChunkyPNG
      png_image = ChunkyPNG::Image.from_file(temp_file.path)

      # Store original dimensions
      @image.update!(
        width: png_image.width,
        height: png_image.height,
        pixel_size: calculate_pixel_size(png_image.width, png_image.height)
      )

      # Create pixelated version
      pixelated_image = pixelate_image(png_image, @image.pixel_size)
      pixelated_file = save_image_to_tempfile(pixelated_image, "pixelated")
      @image.pixelated_image.attach(
        io: File.open(pixelated_file.path),
        filename: "pixelated_#{original_blob.filename}",
        content_type: "image/png"
      )

      # Create paint by number version
      paint_by_number_data = create_paint_by_number(pixelated_image)
      paint_file = save_paint_by_number_to_tempfile(paint_by_number_data, "paint_by_number")
      @image.paint_by_number_image.attach(
        io: File.open(paint_file.path),
        filename: "paint_by_number_#{original_blob.filename}",
        content_type: "image/png"
      )

      @image.update!(
        status: "completed",
        color_count: paint_by_number_data[:color_count]
      )

    rescue => e
      @image.update!(status: "failed")
      Rails.logger.error "Image processing failed: #{e.message}"
      raise e
    ensure
      # Clean up temp files
      temp_file&.close
      temp_file&.unlink
      pixelated_file&.close
      pixelated_file&.unlink
      paint_file&.close
      paint_file&.unlink
    end
  end

  private

  def download_blob_to_tempfile(blob)
    tempfile = Tempfile.new([ "original", ".png" ])
    tempfile.binmode
    blob.download do |chunk|
      tempfile.write(chunk)
    end
    tempfile.close

    # Convert to PNG if it's not already
    if blob.content_type != "image/png"
      require "mini_magick"
      image = MiniMagick::Image.open(tempfile.path)
      png_tempfile = Tempfile.new([ "converted", ".png" ])
      image.format "png"
      image.write png_tempfile.path
      tempfile.unlink
      png_tempfile
    else
      tempfile
    end
  end

  def calculate_pixel_size(width, height)
    # Calculate pixel size to aim for roughly 50x50 grid
    target_cells = 50
    pixel_size = [ width / target_cells, height / target_cells ].max
    [ pixel_size, 1 ].max # Minimum pixel size of 1
  end

  def pixelate_image(png_image, pixel_size)
    width = png_image.width
    height = png_image.height

    pixelated = ChunkyPNG::Image.new(width, height, ChunkyPNG::Color::TRANSPARENT)

    (0...height).step(pixel_size) do |y|
      (0...width).step(pixel_size) do |x|
        # Get the average color of the pixel block
        colors = []

        pixel_size.times do |dy|
          pixel_size.times do |dx|
            px = x + dx
            py = y + dy
            next if px >= width || py >= height

            colors << png_image[px, py]
          end
        end

        next if colors.empty?

        # Calculate average color
        avg_color = average_color(colors)

        # Fill the pixel block with the average color
        pixel_size.times do |dy|
          pixel_size.times do |dx|
            px = x + dx
            py = y + dy
            next if px >= width || py >= height

            pixelated[px, py] = avg_color
          end
        end
      end
    end

    pixelated
  end

  def average_color(colors)
    return ChunkyPNG::Color::TRANSPARENT if colors.empty?

    total_r = total_g = total_b = total_a = 0

    colors.each do |color|
      total_r += ChunkyPNG::Color.r(color)
      total_g += ChunkyPNG::Color.g(color)
      total_b += ChunkyPNG::Color.b(color)
      total_a += ChunkyPNG::Color.a(color)
    end

    count = colors.length
    avg_r = total_r / count
    avg_g = total_g / count
    avg_b = total_b / count
    avg_a = total_a / count

    ChunkyPNG::Color.rgba(avg_r, avg_g, avg_b, avg_a)
  end

  def create_paint_by_number(pixelated_image)
    width = pixelated_image.width
    height = pixelated_image.height

    # Extract unique colors and map them to Crayola colors
    unique_colors = Set.new
    color_map = {}

    # First pass: collect unique colors
    (0...height).each do |y|
      (0...width).each do |x|
        color = pixelated_image[x, y]
        next if ChunkyPNG::Color.a(color) == 0 # Skip transparent

        unique_colors.add(color)
      end
    end

    # Map each unique color to the closest Crayola color
    color_number = 1
    unique_colors.each do |color|
      closest_crayola = find_closest_crayola_color(color)
      color_map[color] = {
        number: color_number,
        crayola: closest_crayola,
        original_color: color
      }
      color_number += 1
    end

    # Create the paint by number image
    paint_image = ChunkyPNG::Image.new(width, height, ChunkyPNG::Color::WHITE)

    (0...height).each do |y|
      (0...width).each do |x|
        color = pixelated_image[x, y]
        next if ChunkyPNG::Color.a(color) == 0 # Skip transparent

        if color_map[color]
          # Draw the number in the center of the pixel block
          draw_number_in_block(paint_image, x, y, color_map[color][:number], @image.pixel_size)
        end
      end
    end

    {
      image: paint_image,
      color_map: color_map,
      color_count: color_map.length
    }
  end

  def find_closest_crayola_color(target_color)
    target_r = ChunkyPNG::Color.r(target_color)
    target_g = ChunkyPNG::Color.g(target_color)
    target_b = ChunkyPNG::Color.b(target_color)

    closest_color = nil
    min_distance = Float::INFINITY

    CRAYOLA_COLORS.each do |crayola|
      # Convert hex to RGB
      hex = crayola[:hex].gsub("#", "")
      r = hex[0..1].to_i(16)
      g = hex[2..3].to_i(16)
      b = hex[4..5].to_i(16)

      # Calculate Euclidean distance in RGB space
      distance = Math.sqrt(
        (target_r - r) ** 2 +
        (target_g - g) ** 2 +
        (target_b - b) ** 2
      )

      if distance < min_distance
        min_distance = distance
        closest_color = crayola
      end
    end

    closest_color
  end

  def draw_number_in_block(image, x, y, number, pixel_size)
    # For simplicity, just draw a single pixel with the number
    # In a real implementation, you'd want to draw actual numbers
    # For now, we'll use different shades of gray to represent different numbers
    gray_value = [ (number * 10) % 256, 255 ].min
    color = ChunkyPNG::Color.grayscale(gray_value)

    # Draw in the center of the pixel block
    center_x = x + pixel_size / 2
    center_y = y + pixel_size / 2

    if center_x < image.width && center_y < image.height
      image[center_x, center_y] = color
    end
  end

  def save_image_to_tempfile(image, prefix)
    tempfile = Tempfile.new([ prefix, ".png" ])
    image.save(tempfile.path)
    tempfile
  end

  def save_paint_by_number_to_tempfile(paint_data, prefix)
    tempfile = Tempfile.new([ prefix, ".png" ])
    paint_data[:image].save(tempfile.path)
    tempfile
  end
end
