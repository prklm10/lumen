import { describe, expect, it } from 'vitest'
import {
  DecryptError, UnlockError, changePassphrase, createVault, decryptEntry, encryptEntry, rotateRecoveryKey, unlockWithPassphrase,
  unlockWithRecoveryKey, type EntryPayload, type KdfParams,
} from '@/lib/crypto/journal'
import { fromBase32, fromBase64, pad, toBase32, unpad } from '@/lib/crypto/encoding'

// Small Argon2id cost so the suite stays fast; production uses DEFAULT_KDF.
const FAST: KdfParams = { m: 1024, t: 1, p: 1 }
const id = '8a7f8f5e-2c4b-4d0a-9e1f-0b5c3a2d1e4f'
const payload: EntryPayload = {
  v: 1, title: 'A good day', doc: { type: 'doc', content: [{ type: 'paragraph', content: [{ type: 'text', text: 'SECRET-CANARY' }] }] },
  mood: 4, tags: ['family'], prompt: null, word_count: 1,
}

describe('journal vault', () => {
  it('unlocks with the passphrase and with the recovery key, and the keys are not extractable', async () => {
    const { record, recoveryKey, key } = await createVault('correct horse battery staple', FAST)
    expect(key.extractable).toBe(false)
    expect(recoveryKey).toMatch(/^[0-9A-Z]{5}(-[0-9A-Z]{1,5}){5}$/)

    const encrypted = await encryptEntry(key, id, 1, payload)
    const viaPassphrase = await unlockWithPassphrase(record, 'correct horse battery staple')
    const viaRecovery = await unlockWithRecoveryKey(record, recoveryKey.toLowerCase())
    expect(await decryptEntry(viaPassphrase, { id, version: 1, ...encrypted })).toEqual(payload)
    expect(await decryptEntry(viaRecovery, { id, version: 1, ...encrypted })).toEqual(payload)
    await expect(crypto.subtle.exportKey('raw', viaPassphrase)).rejects.toThrow()
  })

  it('rejects a wrong passphrase or recovery key', async () => {
    const { record } = await createVault('correct horse battery staple', FAST)
    await expect(unlockWithPassphrase(record, 'correct horse battery stapler')).rejects.toBeInstanceOf(UnlockError)
    await expect(unlockWithRecoveryKey(record, 'AAAAA-AAAAA-AAAAA-AAAAA-AAAAA-A')).rejects.toBeInstanceOf(UnlockError)
    await expect(unlockWithRecoveryKey(record, 'nope')).rejects.toBeInstanceOf(UnlockError)
  })

  it('never puts the passphrase or plaintext in what goes to the server', async () => {
    const { record, key } = await createVault('my-very-own-passphrase', FAST)
    const encrypted = await encryptEntry(key, id, 1, payload)
    const sent = JSON.stringify({ record, encrypted })
    expect(sent).not.toContain('my-very-own-passphrase')
    expect(sent).not.toContain('SECRET-CANARY')
    expect(new TextDecoder().decode(fromBase64(encrypted.ciphertext))).not.toContain('SECRET-CANARY')
  })

  it('changing the passphrase re-wraps the same key: old entries still decrypt', async () => {
    const { record, key } = await createVault('old passphrase here', FAST)
    const encrypted = await encryptEntry(key, id, 1, payload)
    const patch = await changePassphrase(record, { passphrase: 'old passphrase here' }, 'new passphrase here')
    const updated = { ...record, ...patch }

    await expect(unlockWithPassphrase(updated, 'old passphrase here')).rejects.toBeInstanceOf(UnlockError)
    const key2 = await unlockWithPassphrase(updated, 'new passphrase here')
    expect((await decryptEntry(key2, { id, version: 1, ...encrypted })).title).toBe('A good day')
  })

  it('a rotated recovery key replaces the old one', async () => {
    const { record, recoveryKey } = await createVault('passphrase number one', FAST)
    const { recoveryKey: fresh, patch } = await rotateRecoveryKey(record, 'passphrase number one')
    const updated = { ...record, ...patch }
    await expect(unlockWithRecoveryKey(updated, recoveryKey)).rejects.toBeInstanceOf(UnlockError)
    await expect(unlockWithRecoveryKey(updated, fresh)).resolves.toBeDefined()
  })
})

describe('journal entries', () => {
  it('detects tampering, swapping between entries, and replaying an old version', async () => {
    const { key } = await createVault('passphrase for tamper', FAST)
    const encrypted = await encryptEntry(key, id, 3, payload)

    const bytes = fromBase64(encrypted.ciphertext)
    bytes[10]! ^= 1
    const tampered = btoa(String.fromCharCode(...bytes))
    await expect(decryptEntry(key, { id, version: 3, ...encrypted, ciphertext: tampered })).rejects.toBeInstanceOf(DecryptError)
    await expect(decryptEntry(key, { id: '00000000-0000-4000-8000-000000000000', version: 3, ...encrypted })).rejects.toBeInstanceOf(DecryptError)
    await expect(decryptEntry(key, { ...encrypted, id, version: 4 })).rejects.toBeInstanceOf(DecryptError)
  })

  it('uses a fresh IV every time and pads to 512-byte blocks', async () => {
    const { key } = await createVault('passphrase for ivs', FAST)
    const a = await encryptEntry(key, id, 1, payload)
    const b = await encryptEntry(key, id, 1, payload)
    expect(a.iv).not.toBe(b.iv)
    expect(a.ciphertext).not.toBe(b.ciphertext)
    expect(fromBase64(a.ciphertext).length).toBe(512 + 16) // one block + GCM tag

    const long = await encryptEntry(key, id, 1, { ...payload, title: 'x'.repeat(600) })
    expect(fromBase64(long.ciphertext).length).toBe(1024 + 16)
  })
})

describe('encoding', () => {
  it('base32 round-trips and forgives O/0 and I/1 typos', () => {
    const bytes = new Uint8Array([0, 1, 2, 250, 255, 128, 64, 32, 16, 8, 4, 2, 1, 0, 99, 7])
    const text = toBase32(bytes)
    expect(fromBase32(text, 16)).toEqual(bytes)
    expect(fromBase32(text.replace(/0/g, 'O').replace(/1/g, 'i'), 16)).toEqual(bytes)
  })

  it('padding round-trips, including empty input', () => {
    for (const n of [0, 1, 511, 512, 513]) {
      const data = new Uint8Array(n).fill(7)
      expect(Array.from(unpad(pad(data, 512)))).toEqual(Array.from(data))
    }
  })
})
