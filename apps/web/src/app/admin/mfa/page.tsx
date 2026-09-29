import { redirect } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { createServerSupabase } from "@/lib/supabase/server";
import { signOut } from "../actions";
import { MfaForm } from "./mfa-form";

export const dynamic = "force-dynamic";

export default async function AdminMfaPage() {
  const supabase = await createServerSupabase();
  const { data: claimsData } = await supabase.auth.getClaims();
  if (!claimsData?.claims) redirect("/admin/login");
  if (claimsData.claims.aal === "aal2") redirect("/admin/overview");

  const { data: factors } = await supabase.auth.mfa.listFactors();
  const verified = factors?.totp[0] ?? null;
  if (!verified) {
    const { data: candidate } = await supabase.rpc("is_admin_candidate");
    if (!candidate) redirect("/admin/login?e=forbidden");
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-bg p-4">
      <Card className="w-full max-w-sm">
        <CardContent className="flex flex-col gap-5 p-8">
          <h1 className="text-xl font-bold text-text">Xác thực hai bước</h1>
          <MfaForm factorId={verified?.id ?? null} />
          <form action={signOut}>
            <Button type="submit" variant="ghost" className="w-full">Đăng xuất</Button>
          </form>
        </CardContent>
      </Card>
    </main>
  );
}
