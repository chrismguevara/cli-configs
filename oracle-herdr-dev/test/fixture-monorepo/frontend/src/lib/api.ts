export interface Greeting {
  message: string
  app: string
  count: number
}

/** Calls the Go backend through the Vite dev-server proxy (/api → API_PORT). */
export async function fetchGreeting(name: string): Promise<Greeting> {
  const res = await fetch(`/api/greet?name=${encodeURIComponent(name)}`)
  if (!res.ok) {
    throw new Error(`greet failed: ${res.status}`)
  }
  return (await res.json()) as Greeting
}
