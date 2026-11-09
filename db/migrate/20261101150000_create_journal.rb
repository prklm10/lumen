# Phase 4 — Encrypted journal (PRD §4.2, §7, §8.2). Zero-knowledge: the browser encrypts,
# so these tables only ever hold ciphertext, wrapped keys and public KDF parameters.
class CreateJournal < ActiveRecord::Migration[8.1]
  def change
    create_table :journal_vaults do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.string :kdf_algo, null: false, default: "argon2id"
      t.jsonb :kdf_params, null: false                # { m: KiB, t: iterations, p: parallelism }
      t.binary :salt, null: false                     # Argon2id salt for the passphrase
      t.binary :wrapped_dek, null: false              # the data key, AES-GCM-wrapped by the passphrase key
      t.binary :wrapped_dek_iv, null: false
      t.binary :recovery_salt, null: false            # HKDF salt for the recovery key
      t.binary :wrapped_dek_recovery, null: false     # the same data key, wrapped by the recovery key
      t.binary :wrapped_dek_recovery_iv, null: false
      t.timestamps
    end
    add_check_constraint :journal_vaults, "octet_length(salt) = 16 AND octet_length(recovery_salt) = 16", name: "journal_vaults_salt_length"
    add_check_constraint :journal_vaults, "octet_length(wrapped_dek_iv) = 12 AND octet_length(wrapped_dek_recovery_iv) = 12", name: "journal_vaults_iv_length"
    # A 32-byte key + 16-byte GCM tag.
    add_check_constraint :journal_vaults, "octet_length(wrapped_dek) = 48 AND octet_length(wrapped_dek_recovery) = 48", name: "journal_vaults_wrapped_length"

    # Ids are UUIDs generated in the browser, so an entry's ciphertext can be bound to its id
    # (AES-GCM associated data) before the row exists.
    create_table :journal_entries, id: :uuid, default: nil do |t|
      t.date :entry_date, null: false                  # the only plaintext metadata (calendar, streaks)
      t.binary :ciphertext, null: false
      t.binary :iv, null: false
      t.integer :version, null: false, default: 1       # optimistic locking, also bound into the AAD
      t.timestamps
    end
    add_index :journal_entries, :entry_date
    add_check_constraint :journal_entries, "octet_length(iv) = 12", name: "journal_entries_iv_length"
    add_check_constraint :journal_entries, "octet_length(ciphertext) BETWEEN 16 AND 4194304", name: "journal_entries_ciphertext_size"
    add_check_constraint :journal_entries, "version >= 1", name: "journal_entries_version_positive"
  end
end
