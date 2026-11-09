/** Byte helpers for the journal crypto. Kept dependency-free and easy to test. */
export function toBase64(bytes: Uint8Array): string {
  let binary = ''
  for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000))
  return btoa(binary)
}

export function fromBase64(text: string): Uint8Array<ArrayBuffer> {
  const binary = atob(text)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  return bytes
}

export function randomBytes(length: number): Uint8Array<ArrayBuffer> {
  return crypto.getRandomValues(new Uint8Array(length))
}

// Crockford base32: no I, L, O or U, so a written-down recovery key can't be misread.
const ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'

export function toBase32(bytes: Uint8Array): string {
  let bits = 0
  let value = 0
  let out = ''
  for (const byte of bytes) {
    value = (value << 8) | byte
    bits += 8
    while (bits >= 5) {
      out += ALPHABET[(value >>> (bits - 5)) & 31]
      bits -= 5
    }
  }
  if (bits > 0) out += ALPHABET[(value << (5 - bits)) & 31]
  return out
}

export function fromBase32(text: string, length: number): Uint8Array<ArrayBuffer> {
  const clean = text.toUpperCase().replace(/[^0-9A-Z]/g, '').replace(/[IL]/g, '1').replace(/O/g, '0')
  const out = new Uint8Array(length)
  let bits = 0
  let value = 0
  let index = 0
  for (const char of clean) {
    const digit = ALPHABET.indexOf(char)
    if (digit === -1) throw new Error('Invalid character in recovery key')
    value = (value << 5) | digit
    bits += 5
    if (bits >= 8) {
      if (index >= length) throw new Error('Recovery key is too long')
      out[index++] = (value >>> (bits - 8)) & 0xff
      bits -= 8
    }
  }
  if (index !== length) throw new Error('Recovery key is too short')
  return out
}

/**
 * Pads to a multiple of `block` bytes (ISO/IEC 7816-4: 0x80 then zeros), so the ciphertext
 * size only reveals the entry's length to the nearest block.
 */
export function pad(bytes: Uint8Array, block: number): Uint8Array<ArrayBuffer> {
  const length = Math.ceil((bytes.length + 1) / block) * block
  const out = new Uint8Array(length)
  out.set(bytes)
  out[bytes.length] = 0x80
  return out
}

export function unpad(bytes: Uint8Array): Uint8Array {
  let end = bytes.length - 1
  while (end >= 0 && bytes[end] === 0) end--
  if (end < 0 || bytes[end] !== 0x80) throw new Error('Bad padding')
  return bytes.subarray(0, end)
}
