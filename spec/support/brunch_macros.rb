module BrunchMacros
  def self.included(klass)
    class << klass
      include ClassMethods
    end
  end

  def described_method
    @example.metadata[:full_description][/#(\w+)/, 1] or raise "couldn't find method in description"
  end

  module ClassMethods

    class Calling
      def initialize(spec, args)
        @spec = spec
        @args = args
      end

      def it_requires(attribute)
        @spec.it_requires(attribute) {@spec.subject.send(@spec.described_method, *args)}
      end
    end

    def called_with(*args)
      Calling.new(self, args)
    end

    def it_requires(attribute, &block)
      context "when #{attribute} is nil" do
        before do
          subject.send(attribute.to_s + "=",  nil)
        end

        it "should raise an ArgumentError with \"#{attribute} is required for this operation\"" do
          (block || lambda {subject.send(described_method)}).should raise_error(ArgumentError, "#{attribute} is required for this operation")
        end
      end
    end
  end
end