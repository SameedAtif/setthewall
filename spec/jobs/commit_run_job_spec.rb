require "rails_helper"

RSpec.describe CommitRunJob do
  it "replays the staged style spec into knowledge_base for a style run" do
    run = PipelineRunRecord.create!(run_id: "run-cj-style", kb_version: "test", scope: "style",
                                    style_slug: "cjfoo", scene_spec_id: "s")
    staging = Rails.root.join("tmp", "runs", "run-cj-style", "staging", "style_specs")
    staging.mkpath
    File.write(staging.join("cjfoo.yml"), "slug: cjfoo\n")

    allow_any_instance_of(described_class).to receive(:commit_kb)
    allow_any_instance_of(described_class).to receive(:publish_piece)

    target = Pipeline::KB_ROOT.join("style_specs", "cjfoo.yml")

    described_class.perform_now(run_id: "run-cj-style")

    expect(target.exist?).to be(true)
    expect(run.reload.status).to eq("committed")
    expect(run.reload.mode).to eq("committed")
  ensure
    FileUtils.rm_f(Rails.root.join("knowledge_base", "style_specs", "cjfoo.yml"))
    FileUtils.rm_rf(Rails.root.join("tmp", "runs", "run-cj-style"))
  end

  it "marks a piece run committed without touching style specs" do
    run = PipelineRunRecord.create!(run_id: "run-cj-piece", kb_version: "test", scope: "piece",
                                    style_slug: "cjfoo", scene_spec_id: "s")
    allow_any_instance_of(described_class).to receive(:publish_piece)

    described_class.perform_now(run_id: "run-cj-piece")

    expect(run.reload.status).to eq("committed")
    expect(KnowledgeBase::StyleSpec.all.map(&:slug)).not_to include("cjfoo")
  end
end
