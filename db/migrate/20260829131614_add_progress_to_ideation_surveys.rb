class AddProgressToIdeationSurveys < ActiveRecord::Migration[8.0]
  def change
    add_column :ideation_surveys, :progress, :string
  end
end
