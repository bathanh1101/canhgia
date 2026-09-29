import * as React from "react";
import { cn } from "@/lib/utils";

type DivProps = React.HTMLAttributes<HTMLDivElement>;

export const Card = ({ className, ...p }: DivProps) => (
  <div className={cn("rounded-2xl border border-border bg-surface", className)} {...p} />
);
export const CardHeader = ({ className, ...p }: DivProps) => (
  <div className={cn("flex flex-col gap-1 p-5 pb-0", className)} {...p} />
);
export const CardTitle = ({ className, ...p }: DivProps) => (
  <div className={cn("text-base font-semibold text-text", className)} {...p} />
);
export const CardContent = ({ className, ...p }: DivProps) => (
  <div className={cn("p-5", className)} {...p} />
);
