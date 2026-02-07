"use client";

import { useState } from "react";
import { useSession } from "next-auth/react";
import { Sidebar } from "@/components/Sidebar";
import { SearchOverlay } from "@/components/SearchOverlay";
import { KeyboardShortcuts } from "@/components/KeyboardShortcuts";
import { ShortcutHelpOverlay } from "@/components/ShortcutHelpOverlay";

export function AppShell({ children }: { children: React.ReactNode }) {
  const { data: session, status } = useSession();
  const [searchOpen, setSearchOpen] = useState(false);
  const [shortcutHelpOpen, setShortcutHelpOpen] = useState(false);

  // Show nothing while loading session to avoid layout flash
  if (status === "loading") {
    return (
      <div className="flex h-screen items-center justify-center bg-neutral-50 dark:bg-neutral-950">
        <div className="h-8 w-8 animate-pulse rounded-full bg-neutral-300 dark:bg-neutral-800" />
      </div>
    );
  }

  // Unauthenticated: render children directly (login page)
  if (!session?.user) {
    return <>{children}</>;
  }

  return (
    <div className="flex h-screen">
      <KeyboardShortcuts
        onSearchOpen={() => setSearchOpen(true)}
        onShortcutHelp={() => setShortcutHelpOpen(true)}
      />
      <Sidebar onSearchOpen={() => setSearchOpen(true)} />
      <main className="flex-1 overflow-y-auto bg-neutral-50 dark:bg-neutral-950">
        {children}
      </main>
      {searchOpen && (
        <SearchOverlay onClose={() => setSearchOpen(false)} />
      )}
      {shortcutHelpOpen && (
        <ShortcutHelpOverlay onClose={() => setShortcutHelpOpen(false)} />
      )}
    </div>
  );
}
