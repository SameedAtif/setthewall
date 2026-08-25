module Schemas
  module Phase2
    class ThemeUnificationSchema < RubyLLM::Schema
      boolean :reads_as_one_collection
      string :shared_thread,
             description: "Named explicitly: subject / texture / color / shape / size / intensity / balance"
      array :checks do
        object do
          string :criterion,
                 enum: %w[at_a_glance_collection count_limited shared_thread echo_not_clone shape_dominance]
          string :result, enum: %w[pass fail borderline]
          string :reasoning
        end
      end
      integer :fails_count
      integer :borderlines_count
    end
  end
end
