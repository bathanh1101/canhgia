// Contact comes from env so the policy never hardcodes a mailbox (no domain yet).
export function contactLine(email = process.env.NEXT_PUBLIC_SUPPORT_EMAIL): string {
  const e = email?.trim();
  return e && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e) ? e : "";
}
