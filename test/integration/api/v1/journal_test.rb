require "test_helper"

class Api::V1::JournalTest < ActionDispatch::IntegrationTest
  setup { sign_in }

  def b64(bytes) = Base64.strict_encode64(bytes)
  def rand64(n) = b64(SecureRandom.random_bytes(n))

  def vault_params
    { kdf_algo: "argon2id", kdf_params: { m: 65_536, t: 3, p: 1 },
      salt: rand64(16), wrapped_dek: rand64(48), wrapped_dek_iv: rand64(12),
      recovery_salt: rand64(16), wrapped_dek_recovery: rand64(48), wrapped_dek_recovery_iv: rand64(12) }
  end

  def entry_params(id: SecureRandom.uuid, date: Date.current, ciphertext: rand64(200))
    { id:, entry_date: date.iso8601, ciphertext:, iv: rand64(12) }
  end

  test "vault: not set up, create once, read back byte-for-byte" do
    get api_v1_journal_vault_path, as: :json
    assert_response :success
    assert_nil json["vault"]

    params = vault_params
    post api_v1_journal_vault_path, as: :json, params: { vault: params }
    assert_response :created

    get api_v1_journal_vault_path, as: :json
    assert_equal params[:wrapped_dek], json.dig("vault", "wrapped_dek")
    assert_equal({ "m" => 65_536, "t" => 3, "p" => 1 }, json.dig("vault", "kdf_params"))

    post api_v1_journal_vault_path, as: :json, params: { vault: vault_params }
    assert_response :conflict
  end

  test "vault rejects weak KDF parameters and malformed keys" do
    post api_v1_journal_vault_path, as: :json, params: { vault: vault_params.merge(kdf_params: { m: 1024, t: 1, p: 1 }) }
    assert_response :unprocessable_entity
    post api_v1_journal_vault_path, as: :json, params: { vault: vault_params.merge(wrapped_dek: rand64(32)) }
    assert_response :unprocessable_entity
    post api_v1_journal_vault_path, as: :json, params: { vault: vault_params.merge(salt: "not base64!") }
    assert_response :unprocessable_entity
  end

  test "re-wrapping the key needs the login password" do
    post api_v1_journal_vault_path, as: :json, params: { vault: vault_params }
    new_key = rand64(48)

    patch api_v1_journal_vault_path, as: :json, params: { password: "wrong", vault: { wrapped_dek: new_key, wrapped_dek_iv: rand64(12), salt: rand64(16) } }
    assert_response :forbidden

    patch api_v1_journal_vault_path, as: :json, params: { password: ApiTestHelper::PASSWORD, vault: { wrapped_dek: new_key, wrapped_dek_iv: rand64(12), salt: rand64(16) } }
    assert_response :success
    assert_equal new_key, json["wrapped_dek"]
  end

  test "entries: create with a client UUID, list by range, read back exactly" do
    params = entry_params
    post api_v1_journal_entries_path, as: :json, params: { entry: params }
    assert_response :created
    assert_equal 1, json["version"]

    get api_v1_journal_entries_path, as: :json
    assert_equal [ params[:id] ], json["entries"].map { |e| e["id"] }
    assert_equal params[:ciphertext], json["entries"].first["ciphertext"]

    post api_v1_journal_entries_path, as: :json, params: { entry: params }
    assert_response :conflict
  end

  test "entries need a v4 UUID, a 12-byte IV and a date" do
    post api_v1_journal_entries_path, as: :json, params: { entry: entry_params(id: "1") }
    assert_response :unprocessable_entity
    post api_v1_journal_entries_path, as: :json, params: { entry: entry_params.merge(iv: rand64(8)) }
    assert_response :unprocessable_entity
    post api_v1_journal_entries_path, as: :json, params: { entry: entry_params.except(:entry_date) }
    assert_response :unprocessable_entity
  end

  test "updates are compare-and-swap on version" do
    params = entry_params
    post api_v1_journal_entries_path, as: :json, params: { entry: params }
    path = api_v1_journal_entry_path(params[:id])

    put path, as: :json, params: { entry: { version: 1, ciphertext: rand64(300), iv: rand64(12) } }
    assert_response :success
    assert_equal 2, json["version"]

    put path, as: :json, params: { entry: { version: 1, ciphertext: rand64(300), iv: rand64(12) } }
    assert_response :conflict
    assert_equal "stale_entry", json.dig("error", "code")

    put api_v1_journal_entry_path(SecureRandom.uuid), as: :json, params: { entry: { version: 1, ciphertext: rand64(300), iv: rand64(12) } }
    assert_response :not_found
  end

  test "dates and writing streak need no decryption" do
    today = Time.find_zone("Asia/Kolkata").today
    [ 0, 1, 1, 2, 5 ].each { |d| post api_v1_journal_entries_path, as: :json, params: { entry: entry_params(date: today - d) } }

    get dates_api_v1_journal_entries_path, as: :json
    assert_equal 5, json["total"]
    assert_equal 3, json["streak"]
    assert_equal 2, json["dates"].find { |d| d["entry_date"] == (today - 1).iso8601 }["count"]
  end

  test "delete removes the row for real" do
    params = entry_params
    post api_v1_journal_entries_path, as: :json, params: { entry: params }
    delete api_v1_journal_entry_path(params[:id]), as: :json
    assert_response :no_content
    assert_not JournalEntry.exists?(params[:id])
  end

  test "ciphertext and keys never reach the log" do
    canary = b64("LEAK-CANARY-#{SecureRandom.hex(8)}" * 4)
    log = Rails.root.join("log/test.log")
    before = File.size(log)

    post api_v1_journal_entries_path, as: :json, params: { entry: entry_params(ciphertext: canary) }
    post api_v1_journal_vault_path, as: :json, params: { vault: vault_params.merge(wrapped_dek: canary[0, 64]) }

    written = File.binread(log, nil, before)
    assert_not_includes written, canary
    assert_includes written, "[FILTERED]"
  end

  test "log filtering is exact for iv, so ordinary params stay readable" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered = filter.filter("iv" => "x", "wrapped_dek_recovery" => "y", "archived" => true, "ciphertext" => "z")
    assert_equal({ "iv" => "[FILTERED]", "wrapped_dek_recovery" => "[FILTERED]", "archived" => true, "ciphertext" => "[FILTERED]" }, filtered)
  end
end
