const pad = (n: number) => String(n).padStart(2, '0')

export function formatVnd(n: number): string {
  return `${Math.round(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.')}đ`
}

/** 700 bps -> "7%", 750 -> "7,5%". */
export function formatRate(bps: number): string {
  const pct = bps / 100
  return `${Number.isInteger(pct) ? pct : pct.toFixed(1).replace('.', ',')}%`
}

export function formatHms(ms: number): string {
  const s = Math.max(0, Math.floor(ms / 1000))
  return `${pad(Math.floor(s / 3600))}:${pad(Math.floor((s % 3600) / 60))}:${pad(s % 60)}`
}

export function formatHm(ms: number): string {
  const m = Math.max(0, Math.floor(ms / 60000))
  return `${Math.floor(m / 60)} giờ ${pad(m % 60)} phút`
}
