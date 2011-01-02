require 'spec_helper'

describe String do

  describe "#strip_lines" do
    it "should remove tabs and spaces from the ends of all lines" do
      " \t  foo\t  \n   bar \t \n".strip_lines.should == "foo\nbar\n"
    end
  end

  describe "#unindent" do
    it "should unindent a number of spaces equal to the first line's indentation" do
      <<-FOO.unindent.should == "bar\n  baz\n"
      bar
        baz
      FOO
    end
  end

end

