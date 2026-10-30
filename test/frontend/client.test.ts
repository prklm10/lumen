import { afterEach, describe, expect, it, vi } from 'vitest'
import { api, ApiError } from '@/api/client'

function mockFetch(status: number, body?: unknown) {
  const fetch = vi.fn().mockResolvedValue(
    new Response(body === undefined ? null : JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } }),
  )
  vi.stubGlobal('fetch', fetch)
  return fetch
}

describe('api client', () => {
  afterEach(() => {
    vi.unstubAllGlobals()
    document.head.innerHTML = ''
  })

  it('sends the CSRF token and JSON body', async () => {
    document.head.innerHTML = '<meta name="csrf-token" content="tok123">'
    const fetch = mockFetch(201, { ok: true })

    await api('/session', { method: 'POST', body: { a: 1 } })

    const [url, init] = fetch.mock.calls[0]!
    expect(url).toBe('/api/v1/session')
    expect(init.headers['X-CSRF-Token']).toBe('tok123')
    expect(init.headers['Content-Type']).toBe('application/json')
    expect(init.body).toBe('{"a":1}')
  })

  it('returns undefined for 204 responses', async () => {
    mockFetch(204)
    await expect(api('/session', { method: 'DELETE' })).resolves.toBeUndefined()
  })

  it('throws ApiError with the server error shape', async () => {
    mockFetch(422, { error: { code: 'validation_failed', message: 'Bad', details: { password: ['too short'] } } })

    const error = await api('/setup', { method: 'POST', body: {} }).catch((e) => e)
    expect(error).toBeInstanceOf(ApiError)
    expect(error).toMatchObject({ status: 422, code: 'validation_failed', message: 'Bad', details: { password: ['too short'] } })
  })
})
