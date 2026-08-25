require "rails_helper"

RSpec.describe "RubyLLM persistence models" do
  it "defines the generated chat/message/model/tool-call models" do
    expect(Chat.new).to be_a(Chat)
    expect(Message.new).to be_a(Message)
    expect(Model.new).to be_a(Model)
    expect(ToolCall.new).to be_a(ToolCall)
  end
end

RSpec.describe ApplicationMailer do
  it "sets the mailer layout" do
    expect(ApplicationMailer._layout).to eq("mailer")
  end
end

RSpec.describe "domain error classes" do
  it "defines the cross-file error constants" do
    expect(Compositor::TemplateError).to be_a(Class)
    expect(KbEvolution::ProposalGenerationError).to be_a(Class)
    expect(KbEvolution::ProposalListSchema).to be_a(Class)
  end
end
