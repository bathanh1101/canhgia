"use client";

import QRCode from "qrcode";
import { useEffect, useState } from "react";
import { buildVietQrPayload, type VietQrInput } from "@/lib/vietqr/emvco-payload";

/** Generates the QR locally (no bank data leaves the browser). */
export function VietQrImage({ bin, account, amount, addInfo }: VietQrInput) {
  const key = `${bin}|${account}|${amount}|${addInfo}`;
  const [done, setDone] = useState<{ key: string; src: string | null } | null>(null);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      let src: string | null = null;
      try {
        src = await QRCode.toDataURL(buildVietQrPayload({ bin, account, amount, addInfo }), { errorCorrectionLevel: "M", margin: 2, width: 280 });
      } catch {
        src = null;
      }
      if (!cancelled) setDone({ key, src });
    })();
    return () => { cancelled = true; };
  }, [key, bin, account, amount, addInfo]);

  const current = done?.key === key ? done : null;
  const failed = current !== null && current.src === null;
  const src = current?.src ?? null;

  if (failed) {
    return <p role="alert" className="rounded-lg bg-danger-tint p-3 text-sm text-danger">Không tạo được mã QR. Kiểm tra lại thông tin ngân hàng, hoặc chuyển khoản thủ công.</p>;
  }
  if (!src) return <div className="h-[280px] w-[280px] animate-pulse rounded-lg bg-bg" aria-label="Đang tạo mã QR" />;
  // eslint-disable-next-line @next/next/no-img-element -- local data URL, next/image adds nothing
  return <img src={src} width={280} height={280} alt="Mã VietQR chuyển khoản" className="rounded-lg border border-border" />;
}
