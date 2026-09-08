require "rails_helper"

# End-to-end workflow specs: drive a PieceRecord through the full daily pipeline
# (Track C → Phase 2 → Phase 3) via the real step classes + dispatcher, stubbing only
# the external boundaries (LLM, image generation, Etsy). One example per placement
# branch so all five Phase 2 sub-steps are exercised.
RSpec.describe "full daily pipeline", type: :model do
  def synthesis_content
    { "image_generation_prompt" => "minimalist line art",
      "axis_contributions" => [], "negative_prompt" => "no watermark" }
  end

  def theme_content
    { "reads_as_one_collection" => true, "shared_thread" => "color",
      "checks" => [], "fails_count" => 0, "borderlines_count" => 0 }
  end

  def hero_content
    { "recommended_hero" => "url", "reasoning" => "clear",
      "ordering" => ["url"], "photo_count" => 1 }
  end

  def title_content
    { "title" => "Japandi minimalist line art print",
      "first_six_words" => "Japandi minimalist line art print",
      "occasion_word_included" => false, "reasoning" => "" }
  end

  def tags_content
    angles = %w[style_descriptor room_or_space_use gift_or_occasion alternate_use]
    tags = angles.flat_map.with_index do |angle, ai|
      (ai == 3 ? 4 : 3).times.map do |j|
        { "tag" => "e2e #{angle.tr('_', ' ')} #{j} wall art", "angle" => angle, "breadth" => "specific_long_tail" }
      end
    end
    { "tags" => tags, "distinct_angles_covered" => 4, "missing_angles" => [] }
  end

  def description_content
    { "essential_info_block" => "8x10 print", "engagement_block" => "For calm minimalists.",
      "positioning_claim" => "For someone building a calm, uncluttered space.",
      "tag_phrases_used" => ["minimalist wall art"],
      "full_description" => "8x10 print. For someone building a calm, uncluttered space." }
  end

  def llm_contents
    {
      Schemas::TrackC::PromptSynthesisSchema => synthesis_content,
      Schemas::Phase2::ThemeUnificationSchema => theme_content,
      Schemas::Phase3::HeroPhotoSchema => hero_content,
      Schemas::Phase3::TitleSchema => title_content,
      Schemas::Phase3::TagsSchema => tags_content,
      Schemas::Phase3::DescriptionSchema => description_content
    }
  end

  def branch_step_id(space_math)
    {
      "single" => "P2_2a", "set" => "P2_2b", "split_wall" => "P2_2c",
      "nook" => "P2_2d", "surface" => "P2_2e"
    }.fetch(space_math)
  end

  def branch_context(space_math, art_path)
    {
      "single" => {},
      "set" => { piece_count: 3, subject_energy: "formal", base_form: "tops_bottoms_alignment", anchor_url: art_path.to_s },
      "split_wall" => { split_technique: "chair_rail", zones: [{ branch: "single", piece_count: 1 }] },
      "nook" => { piece_count: 1 },
      "surface" => { piece_count: 1, heights_used: [1], surface_type: "mantel" }
    }.fetch(space_math)
  end

  def run_daily_pipeline(space_math:, mood: "calm_ordered", content_type: "minimalist_modern")
    slug = "e2e-#{SecureRandom.hex(6)}"
    scene_id = "e2e-s1"
    spec, scene = build_test_spec(slug: slug, scene_id: scene_id, space_math: space_math,
                                  mood: mood, content_type: content_type)
    build_scene_template(scene_id)
    art_path = build_art_image

    piece = create(:piece_record, style_spec_slug: slug, scene_spec_id: scene_id)
    piece.apply_spec!(spec, scene)
    piece.save!

    stub_image_adapter(urls: [art_path.to_s, art_path.to_s, art_path.to_s]) do
      stub_etsy_adapter(listing_id: "9999") do
        stub_llm(contents: llm_contents) do
          dispatch("C1", piece, candidate_count: 3)
          dispatch("C2", piece, {})
          dispatch("C2", piece, finalist_urls: [art_path.to_s])
          dispatch("C2", piece, finalist_urls: [art_path.to_s], chosen_url: art_path.to_s)

          dispatch("P2_1", piece)
          dispatch(branch_step_id(space_math), piece, branch_context(space_math, art_path))
          dispatch("P2_3", piece) if space_math == "set"
          dispatch("P2_4", piece, palette: "neutral")
          dispatch("P2_4b", piece)
          dispatch("P2_5", piece)
          dispatch("P2_6", piece)

          dispatch("P3_1", piece)
          dispatch("P3_1b", piece, provided_urls: { studio: art_path.to_s, detail: art_path.to_s })
          dispatch("P3_1b", piece, provided_urls: { studio: art_path.to_s, detail: art_path.to_s }, confirmed: true)
          dispatch("P3_2", piece)
          dispatch("P3_2", piece, confirmed: true)
          dispatch("P3_3", piece, product_type: "print")
          dispatch("P3_4", piece, product_type: "print")
          dispatch("P3_5", piece)
          dispatch("P3_5", piece, category_id: "1")
          dispatch("P3_6", piece, positioning_target: "calm minimalists", dimensions: "8x10", sizes: "One size")
          dispatch("P3_6", piece, positioning_target: "calm minimalists", confirmed: true)
          dispatch("P3_7", piece)
          dispatch("P3_7", piece, return_policy: "30 days", shipping_price_usd: 5, item_price_usd: 50, confirmed: true)
          dispatch("P3_8", piece)
        end
      end
    end

    piece.reload
  end

  context "single branch (minimalist / calm)" do
    it "runs to a published listing" do
      piece = run_daily_pipeline(space_math: "single")

      expect(piece.etsy_listing_id).to eq("9999")
      expect(piece.published_at).to be_present
      expect(piece.status).to eq("complete")
      expect(piece.frame_material_category).to eq("metal")
      expect(piece.composite_url).to be_present
      expect(piece.listing_title).to eq("Japandi minimalist line art print")
    end
  end

  context "set branch (bold / detailed)" do
    it "runs to a published listing with a theme-unified set" do
      piece = run_daily_pipeline(space_math: "set", mood: "bold_active", content_type: "detailed_representational")

      expect(piece.etsy_listing_id).to eq("9999")
      expect(piece.published_at).to be_present
      expect(piece.piece_count).to eq(3)
      expect(piece.frame_material_category).to eq("ornate_carved")
      expect(piece.arrangement_form).to eq("tops_bottoms_alignment")
    end
  end

  context "split-wall branch" do
    it "runs to a published listing" do
      piece = run_daily_pipeline(space_math: "split_wall")

      expect(piece.etsy_listing_id).to eq("9999")
      expect(piece.arrangement_form).to eq("split_wall_chair_rail")
    end
  end

  context "nook branch" do
    it "runs to a published listing" do
      piece = run_daily_pipeline(space_math: "nook")

      expect(piece.etsy_listing_id).to eq("9999")
      expect(piece.arrangement_form).to eq("nook_fit")
    end
  end

  context "surface branch" do
    it "runs to a published listing" do
      piece = run_daily_pipeline(space_math: "surface")

      expect(piece.etsy_listing_id).to eq("9999")
      expect(piece.arrangement_form).to eq("single_leaned")
    end
  end
end
