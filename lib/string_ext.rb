class String
  def strip_lines
    self.gsub(/^ +| +$/, '')
  end
end