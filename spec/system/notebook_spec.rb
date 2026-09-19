require "rails_helper"

RSpec.describe "Notebook", type: :system do
  it "renders a run's cells with execution controls" do
    run = create(:pipeline_run_record, run_id: "run_notebook_1", style_slug: "japandi", scene_spec_id: "s1")
    create(:run_step, pipeline_run_record: run, step_id: "A_IDEATE", position: 0,
                      status: "done", summary: "Surveyed styles and proposed three candidates.")

    visit runs_path

    expect(page).to have_text("run_notebook_1")
    find("summary", text: "See more").click
    expect(page).to have_text("Surveyed styles and proposed three candidates.")
    expect(page).to have_button("Regenerate this step")
    expect(page).to have_text("Add a note")
  end

  it "offers AI-suggested decisions on a paused cell" do
    run = create(:pipeline_run_record, run_id: "run_notebook_2", style_slug: "japandi", scene_spec_id: "s1")
    create(:run_step, pipeline_run_record: run, step_id: "A_IDEATE", position: 0,
                      status: "awaiting_human", message: "Pick a candidate to validate.",
                      decision_options: [
                        { "label" => "Approve — continue with Warm minimal",
                          "description" => "Proceed with the recommended candidate.",
                          "intent" => "approve", "edits" => {} },
                        { "label" => "Re-run this step", "description" => "Try again.",
                          "intent" => "retry", "edits" => {} }
                      ])

    visit run_path(run)

    expect(page).to have_text(/needs your decision/i)
    expect(page).to have_text("Approve — continue with Warm minimal")
    expect(page).to have_button("Apply decision")
    expect(page).to have_text("Something else — write your own")
  end

  it "offers to narrow A1 when the reference set spans multiple mood clusters" do
    run = create(:pipeline_run_record, run_id: "run_notebook_3", style_slug: "japandi", scene_spec_id: "s1")
    create(:run_step, pipeline_run_record: run, step_id: "A1", position: 0,
                      status: "awaiting_human", message: "Curate the reference set.", verdict: "blocked",
                      output: { "candidates" => { "mood_clusters_found" => [
                        { "label" => "Serene white-on-white" },
                        { "label" => "Earthy warm-taupe" }
                      ], "dominant_mood" => "mixed" } })

    visit run_path(run)

    expect(page).to have_text(/narrow the reference set/i)
    expect(page).to have_text("Serene white-on-white")
    expect(page).to have_button("Narrow & re-run A1")
    # A context-identical retry is not offered.
    expect(page).not_to have_text("Re-run this step")
  end

  it "presents B6's color-role decision as a single radio group" do
    run = create(:pipeline_run_record, run_id: "run_notebook_b6", style_slug: "japandi", scene_spec_id: "s1")
    create(:run_step, pipeline_run_record: run, step_id: "B6", position: 0, status: "awaiting_human",
                      message: "B6 Content Type override.", verdict: "clean",
                      output: { "observation_candidate" => "color_burst",
                                "default_override" => "line_only",
                                "override_pending" => true, "conflicts" => [] })

    visit run_path(run)

    expect(page).to have_text(/choose the color role/i)
    expect(page).to have_text("Use the documented default")
    expect(page).to have_text("Go back to an earlier step")
    expect(page).to have_text("Abandon this run")
    expect(page).to have_button("Apply decision")
    expect(page).not_to have_button("Apply & re-run B6")
  end
end
