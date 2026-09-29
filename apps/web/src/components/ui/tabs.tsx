"use client";

import { Tabs as T } from "radix-ui";
import * as React from "react";
import { cn } from "@/lib/utils";

export const Tabs = T.Root;
export const TabsList = ({ className, ...p }: React.ComponentProps<typeof T.List>) => (
  <T.List className={cn("inline-flex gap-1 rounded-lg bg-bg p-1", className)} {...p} />
);
export const TabsTrigger = ({ className, ...p }: React.ComponentProps<typeof T.Trigger>) => (
  <T.Trigger
    className={cn(
      "rounded-md px-3 py-1.5 text-sm font-medium text-text-muted data-[state=active]:bg-surface data-[state=active]:text-text data-[state=active]:shadow-sm",
      className,
    )}
    {...p}
  />
);
export const TabsContent = T.Content;
