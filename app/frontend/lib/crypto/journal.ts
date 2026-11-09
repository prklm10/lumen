/**
 * Zero-knowledge journal crypto (PRD §7). Everything here runs in the browser; the server only
 * ever receives the outputs (salts, wrapped keys, ciphertext) and never the passphrase,
 * recovery key, data key or plaintext.
 *
 *   passphrase ──Argon2id(salt)──► KEK ─┐
 *                                       ├─ AES-GCM wrap ─► wrapped DEK (stored twice on the server)
 *   recovery key ──HKDF(salt)──► KEK ───┘
 *   DEK (random AES-256 key) ──AES-GCM(iv, AAD = entry id + version)──► entry ciphertext
 */
import { argon2id } from 'hash-wasm'
import type { RichDoc } from '@/api/tasks'
import { fromBase32, fromBase64, pad, randomBytes, toBase32, toBase64, unpad } from './encoding'

export interface KdfParams {
  /** Memory in KiB. */
  m: number
  /** Iterations. */
  t: number
  /** Parallelism. */
  p: number
}

/** ~64 MiB, 3 passes: roughly 0.5–1.5 s in a browser (NFR "Journal crypto"). */
export const DEFAULT_KDF: KdfParams = { m: 65_536, t: 3, p: 1 }

/** What the server stores (base64 strings). Safe to send: none of it decrypts anything alone. */
export interface VaultRecord {
  kdf_algo: 'argon2id'
  kdf_params: KdfParams
  salt: string
  wrapped_dek: string
  wrapped_dek_iv: string
  recovery_salt: string
  wrapped_dek_recovery: string
  wrapped_dek_recovery_iv: string
}

export interface EntryPayload {
  v: 1
  title: string
  doc: RichDoc
  mood: number | null
  tags: string[]
  prompt: string | null
  word_count: number
}

export interface EncryptedEntry {
  id: string
  version: number
  ciphertext: string
  iv: string
}

/** Wrong passphrase / recovery key, or a tampered vault: AES-GCM authentication failed. */
export class UnlockError extends Error {}
/** An entry failed authentication: tampered, swapped between rows, or the wrong key. */
export class DecryptError extends Error {}

const encoder = new TextEncoder()
const decoder = new TextDecoder()
const WRAP_AAD = encoder.encode('lumen/journal/dek/v1')
const RECOVERY_INFO = encoder.encode('lumen/journal/recovery-kek/v1')
const RECOVERY_BYTES = 16
const PAD_BLOCK = 512

async function passphraseKek(passphrase: string, salt: Uint8Array, params: KdfParams) {
  const raw = await argon2id({
    password: passphrase.normalize('NFKC'),
    salt,
    parallelism: params.p,
    iterations: params.t,
    memorySize: params.m,
    hashLength: 32,
    outputType: 'binary',
  })
  const bytes = new Uint8Array(raw) // WebCrypto wants an ArrayBuffer-backed view
  raw.fill(0)
  try {
    return await crypto.subtle.importKey('raw', bytes, 'AES-GCM', false, ['wrapKey', 'unwrapKey'])
  } finally {
    bytes.fill(0)
  }
}

async function recoveryKek(recoveryKey: Uint8Array<ArrayBuffer>, salt: Uint8Array<ArrayBuffer>) {
  const material = await crypto.subtle.importKey('raw', recoveryKey, 'HKDF', false, ['deriveKey'])
  return crypto.subtle.deriveKey(
    { name: 'HKDF', hash: 'SHA-256', salt, info: RECOVERY_INFO },
    material,
    { name: 'AES-GCM', length: 256 },
    false,
    ['wrapKey', 'unwrapKey'],
  )
}

async function wrap(dek: CryptoKey, kek: CryptoKey) {
  const iv = randomBytes(12)
  const wrapped = new Uint8Array(await crypto.subtle.wrapKey('raw', dek, kek, { name: 'AES-GCM', iv, additionalData: WRAP_AAD }))
  return { wrapped: toBase64(wrapped), iv: toBase64(iv) }
}

async function unwrap(wrapped: string, iv: string, kek: CryptoKey, extractable: boolean) {
  try {
    return await crypto.subtle.unwrapKey(
      'raw', fromBase64(wrapped), kek, { name: 'AES-GCM', iv: fromBase64(iv), additionalData: WRAP_AAD },
      { name: 'AES-GCM', length: 256 }, extractable, ['encrypt', 'decrypt'],
    )
  } catch {
    throw new UnlockError('That key doesn’t unlock this journal.')
  }
}

function formatRecoveryKey(bytes: Uint8Array) {
  return toBase32(bytes).match(/.{1,5}/g)!.join('-')
}

function parseRecoveryKey(text: string) {
  try {
    return fromBase32(text, RECOVERY_BYTES)
  } catch {
    throw new UnlockError('That doesn’t look like a recovery key.')
  }
}

/** First-time setup: a new data key, wrapped by the passphrase and by a fresh recovery key. */
export async function createVault(passphrase: string, kdf: KdfParams = DEFAULT_KDF) {
  const dek = await crypto.subtle.generateKey({ name: 'AES-GCM', length: 256 }, true, ['encrypt', 'decrypt'])
  const salt = randomBytes(16)
  const recoverySalt = randomBytes(16)
  const recovery = randomBytes(RECOVERY_BYTES)

  const kek = await passphraseKek(passphrase, salt, kdf)
  const byPassphrase = await wrap(dek, kek)
  const byRecovery = await wrap(dek, await recoveryKek(recovery, recoverySalt))

  const record: VaultRecord = {
    kdf_algo: 'argon2id',
    kdf_params: kdf,
    salt: toBase64(salt),
    wrapped_dek: byPassphrase.wrapped,
    wrapped_dek_iv: byPassphrase.iv,
    recovery_salt: toBase64(recoverySalt),
    wrapped_dek_recovery: byRecovery.wrapped,
    wrapped_dek_recovery_iv: byRecovery.iv,
  }
  // The session gets a non-extractable copy: script can use it but never read its bytes.
  const sessionKey = await unwrap(record.wrapped_dek, record.wrapped_dek_iv, kek, false)
  const recoveryKey = formatRecoveryKey(recovery)
  recovery.fill(0)
  return { record, recoveryKey, key: sessionKey }
}

export async function unlockWithPassphrase(vault: VaultRecord, passphrase: string) {
  const kek = await passphraseKek(passphrase, fromBase64(vault.salt), vault.kdf_params)
  return unwrap(vault.wrapped_dek, vault.wrapped_dek_iv, kek, false)
}

export async function unlockWithRecoveryKey(vault: VaultRecord, recoveryKey: string) {
  const kek = await recoveryKek(parseRecoveryKey(recoveryKey), fromBase64(vault.recovery_salt))
  return unwrap(vault.wrapped_dek_recovery, vault.wrapped_dek_recovery_iv, kek, false)
}

type Secret = { passphrase: string } | { recoveryKey: string }

/** An extractable copy of the data key, only for re-wrapping, and only inside these functions. */
async function extractableKey(vault: VaultRecord, secret: Secret) {
  if ('passphrase' in secret) {
    const kek = await passphraseKek(secret.passphrase, fromBase64(vault.salt), vault.kdf_params)
    return unwrap(vault.wrapped_dek, vault.wrapped_dek_iv, kek, true)
  }
  const kek = await recoveryKek(parseRecoveryKey(secret.recoveryKey), fromBase64(vault.recovery_salt))
  return unwrap(vault.wrapped_dek_recovery, vault.wrapped_dek_recovery_iv, kek, true)
}

/** New passphrase (JRN-10): re-wraps the same data key, so no entry needs re-encrypting. */
export async function changePassphrase(vault: VaultRecord, current: Secret, next: string, kdf: KdfParams = vault.kdf_params) {
  const dek = await extractableKey(vault, current)
  const salt = randomBytes(16)
  const { wrapped, iv } = await wrap(dek, await passphraseKek(next, salt, kdf))
  return { kdf_params: kdf, salt: toBase64(salt), wrapped_dek: wrapped, wrapped_dek_iv: iv }
}

/** A new recovery key; the old one stops working. */
export async function rotateRecoveryKey(vault: VaultRecord, passphrase: string) {
  const dek = await extractableKey(vault, { passphrase })
  const salt = randomBytes(16)
  const recovery = randomBytes(RECOVERY_BYTES)
  const { wrapped, iv } = await wrap(dek, await recoveryKek(recovery, salt))
  const recoveryKey = formatRecoveryKey(recovery)
  recovery.fill(0)
  return { recoveryKey, patch: { recovery_salt: toBase64(salt), wrapped_dek_recovery: wrapped, wrapped_dek_recovery_iv: iv } }
}

/** Binds a ciphertext to its row: moving it to another entry or replaying an old version fails. */
function entryAad(id: string, version: number) {
  return encoder.encode(`lumen/journal/entry/v1|${id}|${version}`)
}

export async function encryptEntry(key: CryptoKey, id: string, version: number, payload: EntryPayload) {
  const iv = randomBytes(12)
  const plaintext = pad(encoder.encode(JSON.stringify(payload)), PAD_BLOCK)
  const ciphertext = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv, additionalData: entryAad(id, version) }, key, plaintext))
  plaintext.fill(0)
  return { ciphertext: toBase64(ciphertext), iv: toBase64(iv) }
}

export async function decryptEntry(key: CryptoKey, entry: EncryptedEntry): Promise<EntryPayload> {
  let plaintext: ArrayBuffer
  try {
    plaintext = await crypto.subtle.decrypt(
      { name: 'AES-GCM', iv: fromBase64(entry.iv), additionalData: entryAad(entry.id, entry.version) }, key, fromBase64(entry.ciphertext),
    )
  } catch {
    throw new DecryptError('This entry couldn’t be decrypted. It may have been tampered with.')
  }
  const payload = JSON.parse(decoder.decode(unpad(new Uint8Array(plaintext)))) as EntryPayload
  if (payload.v !== 1) throw new DecryptError(`Unsupported entry format v${payload.v}`)
  return payload
}
