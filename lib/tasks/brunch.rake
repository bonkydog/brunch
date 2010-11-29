require File.expand_path("../brunch", File.dirname(__FILE__))

if ENV["FOG_MOCK"] == "true"
  Fog.mock!
end


module Rake

  class BrunchTask < Task

    def the_brunch
      @@the_brunch ||= Brunch.new
    end

    def brunch_method_name
      name.gsub(/^brunch:/, '').gsub(/:/, "_")
    end

    def needed?
      the_brunch.send(brunch_method_name).nil?
    end

    def execute(args=nil)
      method = the_brunch.method("make_#{brunch_method_name}") || the_brunch.method(brunch_method_name)
      if @actions.empty?
        case method.arity
          when 0
            @actions << Proc.new {method.call}
          when 1, -1
            @actions << Proc.new {method.call(args)}
          else
            raise "bad brunch method arity: #{method.arity}"
        end
      end
      super
    end
  end 
end

def brunch(*args, &block)
  Rake::BrunchTask.define_task(*args, &block)
end


namespace :brunch do

  brunch :host_keys

  brunch :host_key_script => :host_keys

  namespace :prototype do

    brunch :script => :host_keys

    brunch :server => :script

    brunch :image => :server

  end

  brunch :server, [:image_id] => :host_key_script

  brunch :destroy_everything

end
