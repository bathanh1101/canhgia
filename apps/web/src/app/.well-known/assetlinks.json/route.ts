import { buildAssetLinks } from "@/lib/app-links";

export const dynamic = "force-dynamic";

export function GET() {
  return Response.json(buildAssetLinks());
}
