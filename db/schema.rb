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

ActiveRecord::Schema[8.0].define(version: 2025_09_21_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "addresses", force: :cascade do |t|
    t.string "line_one", null: false
    t.string "line_two"
    t.string "city", null: false
    t.string "postcode", null: false
    t.string "country", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "state", null: false
    t.string "first_name"
    t.string "last_name"
    t.date "birthday"
    t.string "shipping_name"
    t.index ["user_id"], name: "index_addresses_on_user_id"
  end

  create_table "ballots", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "week", null: false
    t.text "reasoning"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "voted", default: false, null: false
    t.index ["user_id", "week"], name: "index_ballots_on_user_id_and_week", unique: true
    t.index ["user_id"], name: "index_ballots_on_user_id"
  end

  create_table "cosmetics", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "cost", default: 0
    t.boolean "purchasable", default: false
    t.index ["type"], name: "index_cosmetics_on_type"
  end

  create_table "flipper_features", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.string "feature_key", null: false
    t.string "key", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "meeple_cosmetics", force: :cascade do |t|
    t.bigint "meeple_id", null: false
    t.bigint "cosmetic_id", null: false
    t.boolean "unlocked", default: false
    t.boolean "equipped", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cosmetic_id"], name: "index_meeple_cosmetics_on_cosmetic_id"
    t.index ["equipped"], name: "index_meeple_cosmetics_on_equipped"
    t.index ["meeple_id", "cosmetic_id"], name: "index_meeple_cosmetics_on_meeple_id_and_cosmetic_id", unique: true
    t.index ["meeple_id"], name: "index_meeple_cosmetics_on_meeple_id"
    t.index ["unlocked"], name: "index_meeple_cosmetics_on_unlocked"
  end

  create_table "meeples", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "color"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "unlocked_colors", default: ["blue", "red", "green", "purple"], null: false
    t.index ["user_id"], name: "index_meeples_on_user_id"
  end

  create_table "physical_items", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "cost", default: 0, null: false
    t.boolean "purchasable", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_physical_items_on_name"
    t.index ["purchasable"], name: "index_physical_items_on_purchasable"
  end

  create_table "projects", force: :cascade do |t|
    t.string "name"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "elo"
    t.string "repo_url"
    t.string "demo_url"
    t.string "description", null: false
    t.json "hackatime_projects", default: []
    t.string "status", default: "building", null: false
    t.boolean "in_airtable", default: false, null: false
    t.json "logs", default: [], null: false
    t.integer "time_override_days"
    t.decimal "coin_value", precision: 10, scale: 2, default: "0.0", null: false
    t.string "fraud_status", default: "unchecked", null: false
    t.text "fraud_reasoning"
    t.boolean "is_update", default: false
    t.text "reviewer_feedback"
    t.boolean "hidden", default: false, null: false
    t.text "stonemason_feedback"
    t.decimal "reviewer_multiplier", precision: 3, scale: 1, default: "2.0"
    t.text "reviewer_video_url"
    t.index ["fraud_status"], name: "index_projects_on_fraud_status"
    t.index ["hidden"], name: "index_projects_on_hidden"
    t.index ["status"], name: "index_projects_on_status"
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "shop_purchases", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "item_name", null: false
    t.integer "coins_spent", null: false
    t.datetime "purchased_at", null: false
    t.boolean "fulfilled", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fulfilled"], name: "index_shop_purchases_on_fulfilled"
    t.index ["item_name"], name: "index_shop_purchases_on_item_name"
    t.index ["user_id", "item_name"], name: "index_shop_purchases_unique_one_time", unique: true, where: "((item_name)::text = ANY ((ARRAY['Unlock Orange Meeple'::character varying, 'Random Sticker'::character varying])::text[]))"
    t.index ["user_id", "purchased_at"], name: "index_shop_purchases_on_user_id_and_purchased_at"
    t.index ["user_id"], name: "index_shop_purchases_on_user_id"
    t.check_constraint "coins_spent > 0", name: "check_positive_purchase_amount"
  end

  create_table "users", force: :cascade do |t|
    t.string "slack_id", null: false
    t.string "email"
    t.string "name"
    t.string "team_id"
    t.string "team_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_admin", default: false, null: false
    t.string "rank", default: "user", null: false
    t.integer "coins", default: 0, null: false
    t.string "status", default: "working", null: false
    t.string "idv_rec"
    t.integer "referrer_id"
    t.string "main_device"
    t.string "display_name"
    t.json "audit_logs", default: []
    t.boolean "on_fraud_team", default: false, null: false
    t.index ["rank"], name: "index_users_on_rank"
    t.index ["referrer_id"], name: "index_users_on_referrer_id"
    t.index ["slack_id"], name: "index_users_on_slack_id", unique: true
  end

  create_table "votes", force: :cascade do |t|
    t.bigint "ballot_id", null: false
    t.integer "week", null: false
    t.bigint "project_id"
    t.boolean "voted", default: false
    t.integer "star_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ballot_id", "project_id"], name: "index_votes_on_ballot_id_and_project_id"
    t.index ["ballot_id"], name: "index_votes_on_ballot_id"
    t.index ["project_id"], name: "index_votes_on_project_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "addresses", "users"
  add_foreign_key "ballots", "users"
  add_foreign_key "meeple_cosmetics", "cosmetics"
  add_foreign_key "meeple_cosmetics", "meeples"
  add_foreign_key "meeples", "users"
  add_foreign_key "projects", "users"
  add_foreign_key "shop_purchases", "users"
  add_foreign_key "users", "users", column: "referrer_id"
  add_foreign_key "votes", "ballots"
  add_foreign_key "votes", "projects"
end
