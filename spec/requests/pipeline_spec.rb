require "rails_helper"

RSpec.describe "Pipeline dashboard", type: :request do
  it "renders the dashboard" do
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Pipeline")
  end

  it "shows Track A session state (next step + decided axes)" do
    create(:track_run, track: "track_a", style_slug: "japandi-v1", status: "awaiting_human",
                       current_step: "A2",
                       context: { "style_slug" => "japandi-v1", "style_name" => "Ensō print",
                                  "mood" => "calm_ordered" })

    get root_path

    expect(response.body).to include("japandi-v1")
    expect(response.body).to include("Ensō print")
    expect(response.body).to include("A3")   # next step
    expect(response.body).to include("mood=calm_ordered")
  end

  it "queues an ideation survey" do
    expect { post pipeline_ideate_path, params: { direction: "calm", count: 3 } }
      .to have_enqueued_job(IdeateStylesJob).with(direction: "calm", count: 3)
    expect(response).to redirect_to(root_path)
  end

  it "renders the surveys turbo frame with running status" do
    create(:ideation_survey, status: "running", progress: "researching")
    create(:ideation_survey, status: "complete", candidates: [{ "name" => "Warm minimal" }])

    get pipeline_surveys_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="surveys"')
    expect(response.body).to include("researching")
    expect(response.body).to include("Warm minimal")
  end

  it "queues Track A" do
    expect { post pipeline_track_a_path, params: { style_slug: "x", style_name: "X" } }
      .to have_enqueued_job(StartTrackJob).with(track: "track_a", style_slug: "x", style_name: "X")
    expect(response).to redirect_to(root_path)
  end

  it "queues Track B with the scene image path" do
    expect { post pipeline_track_b_path, params: { style_slug: "x", scene: "s1" } }
      .to have_enqueued_job(StartTrackJob).with(
        track: "track_b", style_slug: "x", scene_template_id: "s1",
        scene_image: "scene_templates/assets/s1.png"
      )
  end

  it "starts the daily pipeline" do
    spec, = build_test_spec
    stub_singleton(Workflow::PreflightCheck, :call!,
                   ->(*_a, **_k) { Workflow::PreflightCheck::Result.new(kb_version: "abc", dirty: false) }) do
      post pipeline_daily_path, params: { style: spec.slug, scene: "s1" }
    end
    expect(response).to redirect_to(root_path)
    expect(PieceRecord.count).to eq(1)
  end

  it "alerts when the daily pipeline refuses a dirty KB" do
    stub_singleton(Workflow::PipelineRun, :start_daily, ->(**) { raise Workflow::DirtyKnowledgeBaseError, "dirty KB" }) do
      post pipeline_daily_path, params: { style: "x", scene: "s1" }
    end
    expect(response).to redirect_to(root_path)
    expect(flash[:alert]).to eq("dirty KB")
  end

  it "refreshes stats" do
    expect(Performance::EtsyStatsFetcher).to receive(:call).with(date: Date.current)
    post pipeline_refresh_stats_path
    expect(response).to redirect_to(root_path)
  end

  it "exports the weekly report" do
    post pipeline_export_path
    expect(response).to redirect_to(root_path)
  ensure
    Dir[Rails.root.join("tmp/evolution/*.json")].each { |f| File.delete(f) rescue nil }
  end

  it "proposes KB edits for an explicit cycle" do
    expect { post pipeline_propose_path, params: { cycle: "cycle_x" } }
      .to have_enqueued_job(ProposeJob).with(cycle_id: "cycle_x")
    expect(response).to redirect_to(kb_proposals_path)
  end

  it "proposes against the latest export when no cycle is given" do
    cycle = "cycle_99991231_zzz"
    path = Rails.root.join("tmp", "evolution", "#{cycle}_data.json")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "{}")
    expect { post pipeline_propose_path }
      .to have_enqueued_job(ProposeJob).with(cycle_id: cycle)
  ensure
    File.delete(path) rescue nil
  end

  it "alerts when proposing with no export" do
    post pipeline_propose_path
    expect(response).to redirect_to(root_path)
    expect(flash[:alert]).to include("No export found")
  end
end
