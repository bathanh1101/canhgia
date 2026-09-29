import type { MerchantRate } from "@/lib/landing/schema";
import { merchantColor } from "./brand";

/** Live from get_merchant_rates() (active merchants only). Hidden when the list is empty. */
export function PartnerStrip({ merchants }: { merchants: MerchantRate[] }) {
  if (merchants.length === 0) return null;
  return (
    <section id="doi-tac" className="border-b border-border bg-surface py-9">
      <div className="mx-auto max-w-[1200px] px-6 text-center">
        <p className="text-sm text-text-muted">Hoàn tiền khi mua sắm tại các sàn và đối tác hàng đầu</p>
        <ul className="mt-6 flex flex-wrap items-center justify-center gap-x-10 gap-y-4">
          {merchants.map((m) => (
            <li key={m.merchant_id} className="flex items-center gap-2.5 text-base font-bold text-text">
              <span
                aria-hidden
                className="flex size-8 items-center justify-center rounded-lg text-sm font-bold text-white"
                style={{ backgroundColor: merchantColor(m.merchant_id) }}
              >
                {m.badge_letter}
              </span>
              {m.name}
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
