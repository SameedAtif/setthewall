module KbEvolution
  class Applier
    ALLOWED_ROOT = Rails.root.join("knowledge_base").to_s

    def self.call(proposal:)
      # Belt-and-braces guardrail against writing outside knowledge_base/.
      # Model validation is one layer; this is the second.
      real_path = proposal.target_pathname.expand_path.to_s
      unless real_path.start_with?(ALLOWED_ROOT + "/")
        raise ApplyError, "Refusing to apply — target_path resolves outside knowledge_base/: #{real_path}"
      end

      case proposal.change_type
      when "edit_snippet"    then apply_edit_snippet(proposal)
      when "append"          then apply_append(proposal)
      when "replace_file"    then apply_replace_file(proposal)
      end

      proposal.update!(status: "applied", applied_at: Time.current)
    end

    def self.apply_edit_snippet(proposal)
      content = File.read(proposal.target_pathname)
      if proposal.old_snippet.blank?
        raise ApplyError, "edit_snippet requires old_snippet"
      end
      unless content.include?(proposal.old_snippet)
        raise ApplyError, "old_snippet not found verbatim in #{proposal.target_path} — reviewer must edit the proposal or reject it"
      end
      # Refuse to apply if old_snippet appears multiple times — ambiguous.
      if content.scan(proposal.old_snippet).size > 1
        raise ApplyError, "old_snippet appears more than once in #{proposal.target_path} — cannot apply unambiguously; reviewer should tighten the snippet"
      end
      new_content = content.sub(proposal.old_snippet, proposal.effective_new_snippet)
      File.write(proposal.target_pathname, new_content)
    end

    def self.apply_append(proposal)
      File.open(proposal.target_pathname, "a") do |f|
        f.puts if !File.read(proposal.target_pathname).end_with?("\n")
        f.puts proposal.effective_new_snippet
      end
    end

    def self.apply_replace_file(proposal)
      # For a brand-new file, target_pathname.parent must exist.
      proposal.target_pathname.dirname.mkpath
      File.write(proposal.target_pathname, proposal.effective_new_snippet)
    end
  end
end
