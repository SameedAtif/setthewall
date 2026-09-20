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

  describe "#c1_reference_options" do
    it "flags which A1 images C1 currently uses" do
      run = create(:pipeline_run_record)
      step = create(:run_step, pipeline_run_record: run, step_id: "C1", position: 0,
                               context_override: { "reference_images" => ["https://x/b.jpg"] })
      # Set A1's result after the step is created: creating a cell mirrors run_steps into
      # step_results, which would otherwise wipe this.
      run.update_columns(
        step_results: [{ "step_id" => "A1", "status" => "ok",
                         "data" => { "candidates" => { "images" => [
                           { "url" => "https://x/a.jpg", "shot_type" => "closeup", "source_name" => "A" },
                           { "url" => "https://x/b.jpg", "shot_type" => "in_situ", "source_name" => "B" }
                         ] } } }]
      )

      options = helper.c1_reference_options(run.reload, step)

      expect(options.map { |o| o[:url] }).to eq(%w[https://x/a.jpg https://x/b.jpg])
      expect(options.find { |o| o[:url] == "https://x/b.jpg" }[:included]).to be(true)
      expect(options.find { |o| o[:url] == "https://x/a.jpg" }[:included]).to be(false)
    end
  end
end
