export class ApiError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
    public details?: Record<string, string[]>,
  ) {
    super(message)
  }
}

type Method = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE'

function csrfToken(): string {
  return document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? ''
}

export async function api<T>(path: string, options: { method?: Method; body?: unknown } = {}): Promise<T> {
  const { method = 'GET', body } = options
  const response = await fetch(`/api/v1${path}`, {
    method,
    credentials: 'same-origin',
    headers: {
      Accept: 'application/json',
      'X-CSRF-Token': csrfToken(),
      ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  })

  if (response.status === 204) return undefined as T

  const data = await response.json().catch(() => ({}))
  if (!response.ok) {
    const error = data?.error ?? {}
    throw new ApiError(response.status, error.code ?? 'unknown', error.message ?? response.statusText, error.details)
  }
  return data as T
}
