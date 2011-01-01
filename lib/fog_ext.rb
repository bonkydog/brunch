require 'fog'

class Fog::AWS::Compute::Server < Fog::Model

  def got_brunchified?
    wait_for(60 * 30, 10) { brunchified? }
  end

  def brunchified?
    return true if Fog.mocking?
    self.username = 'ubuntu'
    result = ssh('ls ~ubuntu/.brunch_done').last
    result.status == 0 && result.stdout.include?("brunch_done")
  rescue Exception => e
    false
  end
end