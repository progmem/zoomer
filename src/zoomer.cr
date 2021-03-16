require "option_parser"
require "log"
require "file_utils"
require "./zoom_sample"

module Zoomer
  # Extract pages of bytes from the audio ROM
  def extract_pages(filename)
    Log.info { "Reading in %s" % filename }
    pages = [] of Bytes
    file  = File.open filename, "r"

    begin
      while true
        Log.info { "Extracting page %d" % pages.size }

        # Read into a new page of data.
        page = Bytes.new 0x40000
        file.read_fully(page)

        # Store that page in our collection of pages.
        pages << page
      end
    rescue IO::EOFError
      # No more bytes to read
      file.close
    end

    pages
  end

  # Extract samples from a page of data
  def extract_samples(page : Bytes, page_idx)
    samples = [] of ZoomSample
    # Each page starts with a number of headers that the CPU uses.
    # We'll keep track of both the current and max offsets.
    offset = 0
    offset_max : Int32? = nil

    while offset_max.nil? || offset < offset_max
      # Our positions and flags are stored in 4 bytes each
      ranges = {
        start: (   offset...offset+4),
        end:   ( 4+offset...offset+8),
        loop:  ( 8+offset...offset+12),
        flags: (12+offset...offset+16)
      }

      # Read the data in using our offsets
      data = ranges.values.map{|r| page[r]}.map do |range|
        IO::ByteFormat::LittleEndian.decode(Int32, range)
      end

      # Separate out our four bytes so we can better work with them
      pos_start, pos_end, pos_loop, flags = data

      # If our position start is -1, the page is empty
      if pos_start == -1
        Log.warn { "Page %d contains no samples, skipping" % [page_idx] }
        return samples
      end

      # Our loop position can be converted from addess to sample
      pos_loop -= pos_start
      # Our end position indicates the last address to be read
      # Increment it by 4 to make sure that last sample is included
      pos_end += 4

      Log.info { "Extracting sample %02d-%04d" % [page_idx, samples.size] }

      # Now we can extract our sample
      samples << ZoomSample.new(page[pos_start...pos_end], pos_loop, "%02d-%04d" % [page_idx, samples.size])

      # Capture our first offset as the max
      offset_max ||= pos_start
      # Increment the offset by 16 bytes
      offset += 16
    end

    samples
  end

  in_file : String? = nil

  parser = OptionParser.parse do |parser|
    parser.banner = "Usage: zoomer [input_file]"

    parser.unknown_args do |args|
      unless args.size == 1
        puts parser
        exit 0
      end

      in_file = args.last
    end
  end

  extend self

  # We need a place to store samples
  samples = [] of ZoomSample

  # Grab all of our pages so we can iterate through them
  pages   = extract_pages in_file.to_s
  
  # For each page, extract the sample from it
  pages.each.with_index do |page, idx|
    Log.info { "Extracting samples from page %d:" % idx }

    samples += extract_samples(page, idx)
  end

  # For every sample, save it
  FileUtils.mkdir_p "output" 

  samples.each do |sample|
    filebase = Path[in_file.to_s].basename
    filename = "output/%s_%s.wav" % [filebase, sample.tag]
    Log.info { "Saving sample %s" % filename }
    sample.to_wav filename
  end
end
