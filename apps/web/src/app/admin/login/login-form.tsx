"use client";

import { Turnstile } from "@marsidev/react-turnstile";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { Button } from "@/components/ui/button";
import { Input, Label } from "@/components/ui/input";
import { toast } from "@/components/ui/sonner";
import { sendEmailOtp, verifyEmailOtp } from "./actions";

export function LoginForm() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [captcha, setCaptcha] = useState<string | null>(null);
  const [sent, setSent] = useState(false);
  const [pending, start] = useTransition();
  const siteKey = process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY;

  const send = () =>
    start(async () => {
      const res = await sendEmailOtp({ email, captchaToken: captcha ?? "" });
      if (res.ok) {
        setSent(true);
        toast.success(res.message ?? "Đã gửi mã");
      } else toast.error(res.error);
    });

  const verify = () =>
    start(async () => {
      const res = await verifyEmailOtp({ email, token: code });
      if (res.ok) router.push("/admin/mfa");
      else toast.error(res.error);
    });

  return (
    <div className="flex flex-col gap-3">
      <Label htmlFor="email">Email quản trị</Label>
      <Input
        id="email" type="email" autoComplete="email" value={email} disabled={sent}
        onChange={(e) => setEmail(e.target.value)} placeholder="admin@example.com"
      />
      {!sent ? (
        <>
          {siteKey && <Turnstile siteKey={siteKey} onSuccess={setCaptcha} onExpire={() => setCaptcha(null)} />}
          <Button onClick={send} disabled={pending || !email || !captcha}>
            {pending ? "Đang gửi..." : "Gửi mã qua email"}
          </Button>
        </>
      ) : (
        <>
          <Label htmlFor="code">Mã xác thực</Label>
          <Input
            id="code" inputMode="numeric" autoComplete="one-time-code" maxLength={10}
            value={code} onChange={(e) => setCode(e.target.value)}
          />
          <Button onClick={verify} disabled={pending || code.length < 6}>
            {pending ? "Đang xác thực..." : "Đăng nhập"}
          </Button>
        </>
      )}
    </div>
  );
}
