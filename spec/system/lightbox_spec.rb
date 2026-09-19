require "rails_helper"

RSpec.describe "Image lightbox", type: :system do
  it "previews an image, navigates between images, and closes on backdrop click" do
    a = build_art_image
    b = build_art_image
    run = create(:pipeline_run_record, run_id: "run_lightbox", style_slug: "japandi", scene_spec_id: "s1")
    create(:run_step, pipeline_run_record: run, step_id: "C1", position: 0, status: "done",
                      summary: "candidates", output: { "candidate_urls" => [a.to_s, b.to_s] })

    visit run_path(run)

    thumbs = all("img[data-lightbox-image]")
    expect(thumbs.size).to eq(2)

    thumbs.first.click

    expect(page).to have_css("[data-lightbox-target='modal']:not(.hidden)")
    expect(find("[data-lightbox-target='image']")["src"]).to include(File.basename(a.to_s))
    expect(page).to have_text("1 / 2")

    find("[data-lightbox-target='next']").click
    expect(find("[data-lightbox-target='image']")["src"]).to include(File.basename(b.to_s))
    expect(page).to have_text("2 / 2")

    find("[data-lightbox-target='prev']").click
    expect(find("[data-lightbox-target='image']")["src"]).to include(File.basename(a.to_s))

    # A click whose target is the backdrop (not the figure/buttons) closes the modal.
    page.execute_script(
      "document.querySelector('[data-lightbox-target=\"modal\"]')" \
      ".dispatchEvent(new MouseEvent('click', { bubbles: true }))"
    )
    expect(page).to have_css("[data-lightbox-target='modal'].hidden", visible: :all)
  end
end
