module Steps
  module Phase2
    class ColorFunctionCheck < Steps::Base
      step id: "P2_4b", mechanism: :lookup, ownership: "[AGENT-READY]"

      # The colour role is a style-level observation (A1b reference essence), not a room-function
      # decision, so this step no longer asks whether the piece fulfils a "colour function in the
      # room". It records the artwork's mat intensity and the mood-based pairing implied by its
      # role — an art-intensity/framing lookup consumed by Phase 2 framing.
      def perform
        color_rules = rules("color_role")
        mat_intensity = color_rules.fetch("mat_intensity", "per_role_default", piece.color_role)
        pairing = color_rules.fetch("pairing_by_mood", piece.mood)

        piece.update!(
          color_role_confirmed: piece.color_role,
          mat_intensity: mat_intensity
        )

        ok({ color_role: piece.color_role, mat_intensity: mat_intensity, pairing_by_mood: pairing })
      end
    end
  end
end
