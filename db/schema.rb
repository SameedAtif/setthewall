# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_08_25_142807) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "chats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "model_id"
    t.index ["model_id"], name: "index_chats_on_model_id"
  end

  create_table "human_gates", force: :cascade do |t|
    t.bigint "piece_record_id", null: false
    t.string "step_id", null: false
    t.string "gate_kind", null: false
    t.string "status", default: "open", null: false
    t.text "agent_proposal"
    t.text "reviewer_decision"
    t.jsonb "context_snapshot", default: {}, null: false
    t.jsonb "reviewer_edits", default: {}, null: false
    t.text "notes"
    t.datetime "opened_at"
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["opened_at"], name: "index_human_gates_on_opened_at"
    t.index ["piece_record_id", "status"], name: "index_human_gates_on_piece_record_id_and_status"
    t.index ["piece_record_id"], name: "index_human_gates_on_piece_record_id"
    t.index ["step_id", "status"], name: "index_human_gates_on_step_id_and_status"
  end

  create_table "kb_proposals", force: :cascade do |t|
    t.string "cycle_id", null: false
    t.string "target_path", null: false
    t.string "change_type", null: false
    t.text "old_snippet"
    t.text "new_snippet", null: false
    t.text "rationale", null: false
    t.jsonb "evidence", default: {}, null: false
    t.string "status", default: "open", null: false
    t.text "reviewer_edits"
    t.text "reviewer_notes"
    t.datetime "opened_at"
    t.datetime "closed_at"
    t.datetime "applied_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cycle_id", "status"], name: "index_kb_proposals_on_cycle_id_and_status"
    t.index ["status"], name: "index_kb_proposals_on_status"
    t.index ["target_path"], name: "index_kb_proposals_on_target_path"
  end

  create_table "messages", force: :cascade do |t|
    t.string "role", null: false
    t.text "content"
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "chat_id", null: false
    t.bigint "model_id"
    t.bigint "tool_call_id"
    t.index ["chat_id"], name: "index_messages_on_chat_id"
    t.index ["model_id"], name: "index_messages_on_model_id"
    t.index ["role"], name: "index_messages_on_role"
    t.index ["tool_call_id"], name: "index_messages_on_tool_call_id"
  end

  create_table "models", force: :cascade do |t|
    t.string "model_id", null: false
    t.string "name", null: false
    t.string "provider", null: false
    t.string "family"
    t.datetime "model_created_at"
    t.integer "context_window"
    t.integer "max_output_tokens"
    t.date "knowledge_cutoff"
    t.jsonb "modalities", default: {}
    t.jsonb "capabilities", default: []
    t.jsonb "pricing", default: {}
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["capabilities"], name: "index_models_on_capabilities", using: :gin
    t.index ["family"], name: "index_models_on_family"
    t.index ["modalities"], name: "index_models_on_modalities", using: :gin
    t.index ["provider", "model_id"], name: "index_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_models_on_provider"
  end

  create_table "performance_snapshots", force: :cascade do |t|
    t.bigint "piece_record_id", null: false
    t.date "captured_on", null: false
    t.integer "views", default: 0
    t.integer "favorites", default: 0
    t.integer "orders", default: 0
    t.decimal "revenue", precision: 10, scale: 2, default: "0.0"
    t.jsonb "search_terms", default: [], null: false
    t.jsonb "raw", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["piece_record_id", "captured_on"], name: "index_performance_snapshots_on_piece_record_id_and_captured_on", unique: true
    t.index ["piece_record_id"], name: "index_performance_snapshots_on_piece_record_id"
  end

  create_table "piece_records", force: :cascade do |t|
    t.string "style_spec_slug", null: false
    t.string "scene_spec_id", null: false
    t.string "kb_version", null: false
    t.string "mood"
    t.string "content_type"
    t.string "frame_form"
    t.string "wall_condition"
    t.string "furniture_weight"
    t.string "room_type"
    t.string "room_shape"
    t.string "space_math"
    t.string "color_role"
    t.integer "batch_count"
    t.jsonb "candidate_urls", default: [], null: false
    t.jsonb "finalist_urls", default: [], null: false
    t.string "chosen_url"
    t.string "placement_branch"
    t.string "frame_material_category"
    t.string "frame_material_finish"
    t.string "frame_contour"
    t.string "matting_technique"
    t.string "mat_intensity"
    t.string "arrangement_form"
    t.integer "piece_count"
    t.string "anchor_piece_ref"
    t.boolean "weight_balance_pass"
    t.jsonb "composite_measurements", default: {}, null: false
    t.string "composite_url"
    t.jsonb "photos", default: {}, null: false
    t.jsonb "photo_order", default: [], null: false
    t.string "listing_title"
    t.jsonb "listing_tags", default: [], null: false
    t.jsonb "listing_attributes", default: {}, null: false
    t.string "listing_category"
    t.text "listing_description"
    t.string "etsy_listing_id"
    t.datetime "published_at"
    t.string "status", default: "pending", null: false
    t.string "current_step"
    t.jsonb "step_log", default: [], null: false
    t.text "last_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "color_role_confirmed"
    t.index ["etsy_listing_id"], name: "index_piece_records_on_etsy_listing_id", unique: true
    t.index ["kb_version"], name: "index_piece_records_on_kb_version"
    t.index ["status"], name: "index_piece_records_on_status"
    t.index ["style_spec_slug", "scene_spec_id"], name: "index_piece_records_on_style_spec_slug_and_scene_spec_id"
  end

  create_table "tool_calls", force: :cascade do |t|
    t.string "tool_call_id", null: false
    t.string "name", null: false
    t.jsonb "arguments", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "message_id", null: false
    t.index ["message_id"], name: "index_tool_calls_on_message_id"
    t.index ["name"], name: "index_tool_calls_on_name"
    t.index ["tool_call_id"], name: "index_tool_calls_on_tool_call_id", unique: true
  end

  add_foreign_key "chats", "models"
  add_foreign_key "human_gates", "piece_records"
  add_foreign_key "messages", "chats"
  add_foreign_key "messages", "models"
  add_foreign_key "messages", "tool_calls"
  add_foreign_key "performance_snapshots", "piece_records"
  add_foreign_key "tool_calls", "messages"
end
