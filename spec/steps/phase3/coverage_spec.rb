require "rails_helper"

RSpec.describe Steps::TrackC::GenerateArt do
  it "fails when candidate_count is below one" do
    piece = build_piece
    piece.save!
    result = described_class.call(piece: piece, context: { candidate_count: 0 })
    expect(result).to be_failed
  end

  it "pauses for the manual adapter" do
    piece = build_piece
    piece.save!
    log_path = nil
    stub_llm(content: { "scene_description" => "a calm plaster surface" }) do
      stub_singleton(ImageGeneration::Adapter, :build, -> { ImageGeneration::ManualAdapter.new }) do
        result = described_class.call(piece: piece, context: { candidate_count: 2 })
        expect(result).to be_awaiting_human
        expect(result.data[:prompt_files].size).to eq(2)
        log_path = result.data[:image_prompt_log]
      end
    end
  ensure
    File.delete(log_path) if log_path && File.exist?(log_path)
  end

  it "writes a durable image-prompt log and exposes the prompts" do
    piece = build_piece
    piece.save!
    content = { "scene_description" => "plaster surface with soft ridges" }
    stub_llm(content: content) do
      stub_singleton(ImageGeneration::Adapter, :build, -> { ImageGeneration::ManualAdapter.new }) do
        result = described_class.call(piece: piece, context: { candidate_count: 2 })

        expect(result).to be_awaiting_human
        prompts = result.data[:prompts]
        expect(prompts.size).to eq(2)
        expect(prompts.first).to include("plaster surface with soft ridges")
        expect(prompts.first).to include("no watermark, no signature") # negative clause from the rule file

        log_path = result.data[:image_prompt_log]
        expect(File.exist?(log_path)).to be(true)
        records = File.readlines(log_path).map { |line| JSON.parse(line) }
        expect(records.size).to eq(2)
        expect(records.first["scene_description"]).to eq("plaster surface with soft ridges")
        expect(records.first["image_generation_prompt"]).to include("plaster surface with soft ridges")
        expect(records.first["ok"]).to be(true)
      ensure
        File.delete(log_path) if log_path && File.exist?(log_path)
      end
    end
  end

  it "fails a candidate whose synthesis is not the parsed schema" do
    piece = build_piece
    piece.save!
    log_path = nil
    stub_llm(content: "not a hash") do
      stub_singleton(ImageGeneration::Adapter, :build, -> { ImageGeneration::ManualAdapter.new }) do
        result = described_class.call(piece: piece, context: { candidate_count: 2 })

        expect(result).to be_failed
        expect(result.message).to include("no candidates")
        log_path = result.data[:image_prompt_log]
      end
    end
  ensure
    File.delete(log_path) if log_path && File.exist?(log_path)
  end

  it "passes A1 reference images to the adapter as style references" do
    piece = build_piece
    piece.save!
    ref = build_art_image.to_s
    adapter = double("adapter", name: "fake")
    allow(adapter).to receive(:generate).and_return(
      ImageGeneration::Result.new(urls: ["u"], provider: "fake", model: "fake",
                                  estimated_cost_usd: 0.0, raw_response: nil)
    )
    log_path = nil
    stub_llm(content: { "scene_description" => "surface" }) do
      stub_singleton(ImageGeneration::Adapter, :build, -> { adapter }) do
        result = described_class.call(piece: piece,
                                      context: { candidate_count: 1, reference_images: [ref] })
        expect(result).to be_ok
        log_path = result.data[:image_prompt_log]
      end
    end

    expect(adapter).to have_received(:generate).with(prompt: anything, n: 1, style_reference: [ref])
  ensure
    File.delete(log_path) if log_path && File.exist?(log_path)
  end

  it "builds an original piece in the reference set's tradition" do
    piece = build_piece
    piece.save!
    log_path = nil
    stub_llm(content: { "scene_description" => "surface" }) do
      stub_singleton(ImageGeneration::Adapter, :build, -> { ImageGeneration::ManualAdapter.new }) do
        result = described_class.call(piece: piece, context: {
          candidate_count: 1,
          reference_essence: { mood: "calm_ordered", qualities: ["flat printed surface imitating plaster"] }
        })
        log_path = result.data[:image_prompt_log]

        expect(result).to be_awaiting_human
        expect(result.data[:prompts].first).to include("same tradition as the reference set")
        expect(result.data[:prompts].first).to include("flat printed surface imitating plaster")
      end
    end
  ensure
    File.delete(log_path) if log_path && File.exist?(log_path)
  end

  it "keeps mood out of content and content_type out of subject" do
    tpl = Pipeline::KB_ROOT.join("prompts", "c1_generation_prompt_synthesis.md").read
    expect(tpl).not_to include("energy and palette")
    expect(tpl).not_to include("lead with the subject matter")
    expect(tpl).to include("PALETTE ONLY")
  end

  it "passes exactly one subject and pattern to the scene synthesis prompt" do
    spec, = build_test_spec(slug: "c1-scene")
    KnowledgeBase::StyleSpecWriter.write_subject_research(
      spec.slug,
      shops_sampled: 8, recurring_subjects: [{ "subject" => "cottage", "recurs_across_shops" => 5 },
                                             { "subject" => "moth", "recurs_across_shops" => 4 }],
      rejected_subjects: []
    )
    KnowledgeBase::StyleSpecWriter.write_scene_research(
      spec.slug,
      shops_sampled: 8,
      scene_patterns: [{ "pattern_id" => "p1", "narrative_structure" => "n", "light_logic" => "l",
                         "temporal_quality" => "t", "recurs_across_shops" => 5 }],
      rejected_patterns: []
    )
    spec = KnowledgeBase::StyleSpec.load("c1-scene")
    piece = build_piece(slug: "c1-scene")
    piece.save!

    step = described_class.new(piece: piece, context: {})
    prompt = step.send(:build_synthesis_prompt,
                       { subject: { "subject" => "cottage" },
                         pattern: { "narrative_structure" => "n", "light_logic" => "l", "temporal_quality" => "t" } })

    expect(prompt).to include("cottage")
    expect(prompt).not_to include("moth")
  end
end

RSpec.describe Steps::TrackA::BuildReferenceSet do
  it "flags an empty candidate set" do
    stub_reasoned_runner(content: { "images" => [], "closeup_count" => 0, "total_count" => 0, "sources_used" => [] }) do
      result = described_class.call(piece: nil, context: { style_name: "Japandi" })
      expect(result.data[:issues]).to include("no candidate images returned")
    end
  end

  it "scripts the named retailer and Pinterest queries in code, scoped by domain" do
    step = described_class.new(piece: nil, context: { style_name: "Japandi" })
    queries = step.send(:scripted_queries)

    expect(queries.map { |q| q[:query] }).to include(
      "Japandi", "Japandi wall art", "Japandi gallery wall", "Japandi living room"
    )
    expect(queries.find { |q| q[:include_domains] == ["westelm.com"] }[:query]).to eq("Japandi")
    expect(queries.count { |q| q[:include_domains] == ["pinterest.com"] }).to eq(3)
    expect(queries).to all(include(include_images: true))
  end
end

RSpec.describe Steps::TrackA::ValidateStyle do
  it "scripts the marketplace sample scoped to Etsy" do
    step = described_class.new(piece: nil, context: { style_name: "Japandi" })
    expect(step.send(:scripted_queries)).to eq(
      [{ query: "Japandi wall art", include_domains: ["etsy.com"] }]
    )
  end
end

RSpec.describe Steps::Phase3::DraftTitle do
  it "pauses for a title that fails validation" do
    piece = build_piece
    piece.save!
    stub_llm(content: { "title" => "Beautiful stunning print", "first_six_words" => "Beautiful stunning print", "occasion_word_included" => false, "reasoning" => "" }) do
      result = described_class.call(piece: piece, context: {})
      expect(result).to be_awaiting_human
      expect(result.data[:errors]).not_to be_empty
    end
  end
end

RSpec.describe Steps::Phase3::PublishAndLog do
  it "fails when there are no photos" do
    piece = create(:piece_record, listing_title: "t", listing_tags: ["x"],
                                  listing_attributes: { "rp" => "x" }, listing_description: "d", listing_category: "1")
    result = described_class.call(piece: piece, context: {})
    expect(result).to be_failed
  end

  it "fails when Etsy raises" do
    piece = create(:piece_record, listing_title: "t", listing_tags: ["x"],
                                  listing_attributes: { "rp" => "x" }, listing_description: "d",
                                  listing_category: "1", photos: { "studio" => "s" })
    adapter = double("adapter")
    allow(adapter).to receive(:create_listing).and_raise(Etsy::ApiError, "boom")
    stub_singleton(Etsy::Adapter, :build, -> { adapter }) do
      result = described_class.call(piece: piece, context: {})
      expect(result).to be_failed
    end
  end
end

RSpec.describe Steps::Phase3::ShippingAndReturns do
  it "warns on inflated shipping" do
    piece = create(:piece_record)
    result = described_class.call(piece: piece, context: {
      return_policy: "30 days", shipping_price_usd: 50, item_price_usd: 100, confirmed: true
    })
    expect(result).to be_ok
    expect(result.data[:warnings]).not_to be_empty
  end
end

RSpec.describe Steps::Phase3::FillAttributes do
  it "fails when the taxonomy fetch returns zero nodes" do
    piece = create(:piece_record)
    adapter = double("adapter")
    allow(adapter).to receive(:fetch_category_tree).and_return([])
    stub_singleton(Etsy::Adapter, :build, -> { adapter }) do
      result = described_class.call(piece: piece, context: {})
      expect(result).to be_failed
      expect(result.message).to include("taxonomy")
    end
  end
end
