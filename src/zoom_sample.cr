class ZoomSample
  @samples = [] of Int16

  getter tag : String

  def initialize(@raw_data : Bytes, @loop_pos : Int32, @tag : String)
    parse
  end

  # Unpack the four 8-bit samples into four 16-bit samples
  # Per MAME documentation (src/devices/sound/zsg2.cpp):
  # 
  # The samples are compressed with a 2:1 ratio.  Each block of 4-bytes becomes 4 
  # 16-bits samples.  Reading the 4 bytes as a *little-endian* 32bits values, the 
  # structure is:
  # 
  # 42222222 51111111 60000000 ssss3333
  # 
  # 's' is a 4-bit scale value. '0000000', '1111111', '2222222' and '6543333' are 
  # signed 7-bits values corresponding to the 4 samples. To compute the final 
  # 16bits value, left-align and shift right by s.
  def parse
    (@raw_data.size // 4).times do |iter|
      samples = [] of Int16
      
      # Extract 4 bytes of raw data in little-endian.
      slice = @raw_data + (iter * 4)
      packed_sample = IO::ByteFormat::LittleEndian.decode UInt32, slice

      # The first, second, and third samples can all be shifted.
      samples << ((packed_sample >> 8)  & 0x7f).to_i16
      samples << ((packed_sample >> 16) & 0x7f).to_i16
      samples << ((packed_sample >> 24) & 0x7f).to_i16

      # Reconstruct the fourth sample
      samples << ((packed_sample & 0x0f      ).to_i16 +
                 ((packed_sample & 0x80000000) >> 27) +
                 ((packed_sample & 0x800000  ) >> 18) +
                 ((packed_sample & 0x8000    ) >>  9))

      # Extract the scaling factor and recalculate the samples.
      scale = (packed_sample & 0xf0) >> 4
      samples.map! do |s|
        s <<= 9
        s >>= scale
      end

      # Store our samples.
      @samples += samples
    end
  end

  # Write a PCM WAV file.
  def to_wav(filename)
    f = File.open filename, "w"

    # Grab the size of our data, used in a couple of locations.
    size_in_bytes = (@samples.size * 2)

    ### Write the WAV file out.
    ## RIFF Header
    # Chunk ID
    f.printf "RIFF"
    # Chunk Size
    f.write_bytes UInt32.new(36 + size_in_bytes + 68), IO::ByteFormat::LittleEndian
    # Format
    f.printf "WAVE"

    ## fmt Subchunk
    f.printf "fmt "
    # Subchunk Size
    f.write_bytes UInt32.new(16),     IO::ByteFormat::LittleEndian
    # Audio Format
    f.write_bytes UInt16.new(1),      IO::ByteFormat::LittleEndian
    # Number of Channels
    f.write_bytes UInt16.new(1),      IO::ByteFormat::LittleEndian
    # Sample Rate (based on MAME documentation)
    f.write_bytes UInt32.new(32552),  IO::ByteFormat::LittleEndian
    # Byte Rate
    f.write_bytes UInt32.new(32552*2),IO::ByteFormat::LittleEndian
    # Block Align
    f.write_bytes UInt16.new(2),      IO::ByteFormat::LittleEndian
    # Block Align
    f.write_bytes UInt16.new(16),     IO::ByteFormat::LittleEndian

    ## data Subchunk
    f.printf "data"
    # Subchunk Size
    f.write_bytes UInt32.new(size_in_bytes), IO::ByteFormat::LittleEndian
    # Subchunk Data
    write_raw_pcm f

    ## smpl Subchunk (loop data)
    f.printf "smpl"
    # Subchunk Size
    f.write_bytes UInt32.new(60),   IO::ByteFormat::LittleEndian
    # Manufacturer
    f.write_bytes UInt32.new(0),    IO::ByteFormat::LittleEndian
    # Product
    f.write_bytes UInt32.new(0),    IO::ByteFormat::LittleEndian
    # Sample Period, in nanoseconds, approx. 1/sample_rate
    f.write_bytes UInt32.new(30720),IO::ByteFormat::LittleEndian
    # MIDI Unity Note
    # TODO: I'm using what was provided in a sample file, what's a good way of determining this?
    f.write_bytes UInt32.new(60),   IO::ByteFormat::LittleEndian
    # MIDI Pitch Fraction
    f.write_bytes UInt32.new(0),    IO::ByteFormat::LittleEndian
    # SMPTE Format
    f.write_bytes UInt32.new(0),    IO::ByteFormat::LittleEndian
    # SMPTE Offset
    f.write_bytes UInt32.new(0),    IO::ByteFormat::LittleEndian
    # Number of Sample Loops
    f.write_bytes UInt32.new(1),    IO::ByteFormat::LittleEndian
    # Sampler Data
    f.write_bytes UInt32.new(0),    IO::ByteFormat::LittleEndian
    ## Sample Loop Data
    # Cue Point ID
    f.write_bytes UInt32.new(0),    IO::ByteFormat::LittleEndian
    # Type
    # TODO: Using "loop forward" here by default
    #       Other options are "ping-pong" (1) and "loop backwards" (2)
    #       Is some of this looping info part of the flags used in the header?
    f.write_bytes UInt32.new(0),                IO::ByteFormat::LittleEndian
    # Start
    f.write_bytes UInt32.new(@loop_pos),        IO::ByteFormat::LittleEndian
    # End
    f.write_bytes UInt32.new(@samples.size - 1),IO::ByteFormat::LittleEndian
    # Fraction
    f.write_bytes UInt32.new(0),                IO::ByteFormat::LittleEndian
    # PlayCount
    f.write_bytes UInt32.new(0),                IO::ByteFormat::LittleEndian

    f.close
  end

  # Write a raw PCM audio file (no headers)
  def to_pcm(filename)
    f = File.open filename, "w"
    write_raw_pcm f
    f.close
  end

  # Write the raw PCM data
  private def write_raw_pcm(file)
    @samples.each do |word|
      file.write_bytes word, IO::ByteFormat::LittleEndian
    end
  end
end