module Steps
  module Phase2
    class ColorFunctionCheck < Steps::Base
      step id: "P2_4b", mechanism: :lookup, ownership: "[AGENT-READY]"

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
