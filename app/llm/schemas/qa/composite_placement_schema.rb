module Schemas
  module Qa
    class CompositePlacementSchema < RubyLLM::Schema
      boolean :overlaps_ceiling,
              description: "Whether the framed artwork touches or crosses the ceiling line"
      boolean :overlaps_furniture,
              description: "Whether the framed artwork touches or overlaps the furniture below it"
      boolean :centered,
              description: "Whether the framed artwork is horizontally centered over the furniture"
      string :notes, description: "One short sentence describing the placement"
    end
  end
end
