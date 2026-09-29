// Merchant badge colours sampled from the L1 design (partner strip). Unknown merchant → primary.
export const MERCHANT_COLORS: Record<string, string> = {
  shopee: "#ee4d2d",
  lazada: "#0f146d",
  tiktok_shop: "#111111",
  tiki: "#189eff",
  agoda: "#2a6ad8",
  traveloka: "#0194f3",
  klook: "#ff5b00",
};
export const merchantColor = (id: string) => MERCHANT_COLORS[id] ?? "#059669";
