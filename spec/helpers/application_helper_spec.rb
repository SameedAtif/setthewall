require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#status_color" do
    it "maps each status to a badge color" do
      expect(status_color("complete")).to include("green")
      expect(status_color("awaiting_human")).to include("amber")
      expect(status_color("failed")).to include("red")
      expect(status_color("running")).to include("blue")
      expect(status_color("bogus")).to include("gray")
    end
  end
end
