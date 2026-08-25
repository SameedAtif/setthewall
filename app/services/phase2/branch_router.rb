module Phase2
  class BranchRouter
    STEP_CLASSES = {
      "single"     => Steps::Phase2::SingleFocalTreatment,
      "set"        => Steps::Phase2::SetGroupingAndCount,
      "split_wall" => Steps::Phase2::SplitWallZoning,
      "nook"       => Steps::Phase2::NookFit,
      "surface"    => Steps::Phase2::SurfaceDisplay
    }.freeze

    def self.klass_for(placement_branch)
      STEP_CLASSES.fetch(placement_branch) do
        raise ArgumentError, "Unknown placement_branch=#{placement_branch.inspect}"
      end
    end
  end
end
