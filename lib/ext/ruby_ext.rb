class String
  def strip_lines
    gsub(/(^[ \t]*)|([ \t]*$)/, '')
  end

  def unindent
    first_line_indentation = self[/\A( *)/,1]
    gsub(/^#{first_line_indentation}/, '')
  end
end

require "tempfile"
class Tempfile
  def self.with(content)
    f = open("temp")
    begin
      f.write(content)
      f.close
      yield f.path
    ensure
      f.unlink
    end
  end
end