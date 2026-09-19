require "rails_helper"

RSpec.describe RunStepOutputHelper, type: :helper do
  def step_with(output)
    build_stubbed(:run_step, output: output)
  end

  it "renders an array of hashes as a table" do
    html = helper.render_step_output(step_with("findings" => [{ "theme" => "coastal", "shops" => 3 }]))

    expect(html).to include("<table")
    expect(html).to include("Theme")
    expect(html).to include("coastal")
  end

  it "renders image URLs as images" do
    html = helper.render_step_output(step_with("candidate_urls" => ["https://example.com/a.png"]))

    expect(html).to include("<img")
    expect(html).to include("https://example.com/a.png")
  end

  it "renders local image paths as images routed through the media endpoint" do
    path = Rails.root.join("tmp", "gemini_images", "img_1_ab.jpg").to_s
    html = helper.render_step_output(step_with("candidate_urls" => [path]))

    expect(html).to include("<img")
    expect(html).to include("/media/tmp/gemini_images/img_1_ab.jpg")
    expect(html).to include("data-lightbox-image")
    expect(html).to include("data-lightbox-scope")
    expect(html).not_to include(path)
  end

  it "opens image sections by default" do
    path = Rails.root.join("tmp", "gemini_images", "img_2_ab.jpg").to_s
    html = helper.render_step_output(step_with("candidate_urls" => [path]))

    expect(html).to match(/<details[^>]*open[^>]*>/)
  end

  it "renders each prompt in a prompts array as its own paragraph" do
    html = helper.render_step_output(step_with("prompts" => ["first prompt", "second prompt"]))

    expect(html.scan("whitespace-pre-wrap").size).to eq(2)
    expect(html).to include("Prompt 1")
    expect(html).to include("Prompt 2")
    expect(html).to include("first prompt")
    expect(html).to include("second prompt")
  end

  it "renders external links with a sandboxed iframe preview" do
    html = helper.render_step_output(step_with("link" => "https://example.com/page"))

    expect(html).to include("<iframe")
    expect(html).to include("sandbox")
    expect(html).to include("example.com/page")
  end

  it "renders search results as links with the query" do
    searches = [{ "query" => "coastal wall art",
                  "results" => [{ "title" => "A", "url" => "https://example.com/a" }] }]
    html = helper.render_step_output(step_with("searches" => searches))

    expect(html).to include("coastal wall art")
    expect(html).to include("https://example.com/a")
  end

  it "keeps prompt text in a collapsed block" do
    html = helper.render_step_output(step_with("prompt" => "You are a curator"))

    expect(html).to include("<details")
    expect(html).to include("You are a curator")
  end

  it "wraps every section in its own See more / Hide collapsible" do
    html = helper.render_step_output(
      step_with("Survey notes" => "sparse", "Candidates" => [{ "name" => "Warm minimal" }])
    )

    expect(html.scan("<details").size).to eq(2) # one per top-level section
    expect(html).to include("See more")
    expect(html).to include("Hide")
    expect(html).to include("Survey notes")
    expect(html).to include("Candidates")
    expect(html).to include("Warm minimal")
  end
end
