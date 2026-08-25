require "test_helper"

class PreflightCheckTest < ActiveSupport::TestCase
  test "allow_dirty: true always returns a stamped version and never raises" do
    result = Workflow::PreflightCheck.call!(allow_dirty: true)
    assert result.kb_version.present?
    assert_equal result.dirty, result.kb_version.start_with?("dirty:")
  end

  test "refuses a dirty KB when allow_dirty is false" do
    marker = Pipeline::KB_ROOT.join("rules/.dirty_marker")
    File.write(marker, "x")
    begin
      assert_raises(Workflow::DirtyKnowledgeBaseError) do
        Workflow::PreflightCheck.call!
      end
    ensure
      File.delete(marker) rescue nil
    end
  end
end
