module Schemas
  module TrackC
    class PromptSynthesisSchema < RubyLLM::Schema
      # The LLM writes only the SCENE/SURFACE description. C1 assembles the final image-generation
      # prompt deterministically from knowledge_base/prompts/c1_image_prompt.md plus
      # knowledge_base/rules/generation_prompt_template.yml, so prompt structure is a file edit and
      # the axis directives + negative clause are always applied.
      string :scene_description,
             description: "One continuous description of the artwork's own surface/imagery, for the image-generation prompt"
    end
  end
end
