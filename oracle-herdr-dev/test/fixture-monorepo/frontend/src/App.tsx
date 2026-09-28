import { useEffect, useState } from 'react'
import { Counter } from './components/Counter'
import { fetchGreeting, type Greeting } from './lib/api'

export function App() {
  const [greeting, setGreeting] = useState<Greeting | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    fetchGreeting('workspace')
      .then((g) => {
        if (!cancelled) setGreeting(g)
      })
      .catch((err: unknown) => {
        if (!cancelled) setError(err instanceof Error ? err.message : String(err))
      })
    return () => {
      cancelled = true
    }
  }, [])

  return (
    <main>
      <h1>fixture-frontend</h1>
      <p>{greeting ? greeting.message : error ? `backend unavailable: ${error}` : 'loading…'}</p>
      <Counter initial={0} step={1} />
    </main>
  )
}
