import { onBeforeUnmount, onMounted, ref, type Ref } from 'vue'

/** Tracks an element's width so SVG charts can lay out in real pixels (crisp 2px lines). */
export function useChartWidth(el: Ref<HTMLElement | undefined>, fallback = 600) {
  const width = ref(fallback)
  let observer: ResizeObserver | undefined
  onMounted(() => {
    if (!el.value) return
    width.value = el.value.clientWidth || fallback
    observer = new ResizeObserver(([entry]) => (width.value = Math.max(240, Math.floor(entry!.contentRect.width))))
    observer.observe(el.value)
  })
  onBeforeUnmount(() => observer?.disconnect())
  return width
}

/** "Nice" axis maximum and ~4 evenly spaced ticks. */
export function niceTicks(max: number, count = 4) {
  if (max <= 0) return { max: 1, ticks: [0, 1] }
  const raw = max / count
  const magnitude = 10 ** Math.floor(Math.log10(raw))
  const step = [1, 2, 2.5, 5, 10].map((m) => m * magnitude).find((s) => s >= raw)!
  const top = Math.ceil(max / step) * step
  return { max: top, ticks: Array.from({ length: Math.round(top / step) + 1 }, (_, i) => +(i * step).toFixed(6)) }
}

export function formatNumber(n: number | null | undefined, digits = 1) {
  if (n === null || n === undefined) return '—'
  return Number.isInteger(n) ? n.toLocaleString() : n.toLocaleString(undefined, { maximumFractionDigits: digits })
}
