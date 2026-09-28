import { useState } from 'react'

export interface CounterProps {
  initial: number
  step: number
}

export function Counter({ initial, step }: CounterProps) {
  const [count, setCount] = useState(initial)

  return (
    <button type="button" onClick={() => setCount((c) => c + step)}>
      count is {count}
    </button>
  )
}
