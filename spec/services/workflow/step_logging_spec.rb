require "rails_helper"

# Unique name so the constant defined here doesn't collide with other specs.
class StepLoggingProbeStep < Steps::Base
  step id: "LOG_PROBE", mechanism: :lookup, ownership: "[AGENT-READY]"

  def perform = ok({ "ok" => true })
end

RSpec.describe Workflow::StepLogging do
  it "routes step logs to the thread-local sink and restores the previous sink" do
    messages = []
    sink = ->(message, level:) { messages << [message, level] }

    described_class.with_logger(sink) do
      StepLoggingProbeStep.call(piece: nil)
      expect(described_class.log("inside")).to be_truthy
    end

    expect(messages.map(&:first)).to include("Running StepLoggingProbeStep", "Step result: ok", "inside")
    expect(described_class.log("outside")).to be_nil
  end
end
