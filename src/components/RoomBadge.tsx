const PREMIUM = /imax|4dx|dolby|lounge|atmos|vip|premium|laser|ice|3d/i;

export function RoomBadge({ label }: { label: string }) {
  const premium = PREMIUM.test(label);

  return (
    <span
      className={
        premium
          ? "inline-flex items-center rounded-md bg-[var(--accent)]/15 px-2 py-0.5 text-[11px] font-semibold uppercase tracking-wide text-[var(--accent)] ring-1 ring-[var(--accent)]/30"
          : "inline-flex items-center rounded-md bg-white/5 px-2 py-0.5 text-[11px] font-medium uppercase tracking-wide text-[var(--muted)] ring-1 ring-white/10"
      }
    >
      {label}
    </span>
  );
}
