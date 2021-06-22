require "pdf-reader"

class Receiver
  def initialize(output)
    @output = output
  end

  def begin_text_object
    @x = 0.0
    @y = 0.0
  end

  def move_text_position(x, y)
    @x += x
    @y += y
  end

  def show_text(string)
    @output << string + '|' + @x.to_s + '|' + @y.to_s
  end
end

def get_pdf_text_infos(dir_path)
  output = []

  receiver = Receiver.new(output)
  Dir.glob(File.join(dir_path, '*.pdf')) do |file_path|
    PDF::Reader.open(file_path) do |reader|
      output << 'DOCUMENT_START'
      reader.pages.each do |page|
        output << 'PAGE_START'
        page.walk(receiver)
        output << 'PAGE_FINISH'
      end
      output << 'DOCUMENT_FINISH'
    end
  end

  output
end
