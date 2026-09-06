require "rails_helper"

RSpec.describe Workflow::RunMode do
  describe "defaults" do
    it "defaults to committed when nothing is in scope" do
      expect(described_class.speculative?).to be(false)
      expect(described_class.current).to eq("committed")
    end
  end

  describe ".with" do
    it "scopes the mode and run_id for the duration of the block" do
      expect(described_class.current).to eq("committed")

      described_class.with("speculative", run_id: "r1") do
        expect(described_class.current).to eq("speculative")
        expect(described_class.speculative?).to be(true)
      end

      expect(described_class.current).to eq("committed")
    end

    it "restores the previous mode after an exception" do
      described_class.with("speculative", run_id: "r1") do
        expect { described_class.with("committed", run_id: "r2") { raise "boom" } }
          .to raise_error("boom")
        expect(described_class.current).to eq("speculative")
      end
    end

    it "rejects an unknown mode" do
      expect { described_class.with("nonsense", run_id: "r1") { } }
        .to raise_error(ArgumentError, /bad mode/)
    end
  end

  describe ".write_root" do
    it "returns the knowledge base root in committed mode" do
      described_class.with("committed", run_id: "r1") do
        expect(described_class.write_root).to eq(Pipeline::KB_ROOT)
      end
    end

    it "returns the staging root in speculative mode" do
      described_class.with("speculative", run_id: "r1") do
        expect(described_class.write_root.to_s).to include("tmp/runs/r1/staging")
      end
    end
  end

  describe ".staging_root" do
    it "raises when no run_id is in scope" do
      expect { described_class.staging_root }
        .to raise_error(Workflow::SpeculativeWriteError, /no run_id/)
    end
  end

  describe ".require_committed!" do
    it "raises in speculative mode" do
      described_class.with("speculative", run_id: "r1") do
        expect { described_class.require_committed!("Etsy publish") }
          .to raise_error(Workflow::SpeculativeWriteError, /Etsy publish/)
      end
    end

    it "passes in committed mode" do
      described_class.with("committed", run_id: "r1") do
        expect { described_class.require_committed!("Etsy publish") }.not_to raise_error
      end
    end
  end
end
