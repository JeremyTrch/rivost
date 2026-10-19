"use client";

import type { Cinema, Showtime } from "@/types/showtimes";

export interface FilterState {
  day: string;
  cinemaKey: string;
  room: string;
}

interface FiltersProps {
  cinemas: Cinema[];
  days: string[];
  rooms: string[];
  value: FilterState;
  onChange: (next: FilterState) => void;
  resultCount: number;
}

function formatDayLabel(isoDay: string): string {
  const [y, m, d] = isoDay.split("-").map(Number);
  const date = new Date(Date.UTC(y, m - 1, d));
  return new Intl.DateTimeFormat("fr-FR", {
    weekday: "short",
    day: "numeric",
    month: "short",
    timeZone: "UTC",
  }).format(date);
}

export function Filters({
  cinemas,
  days,
  rooms,
  value,
  onChange,
  resultCount,
}: FiltersProps) {
  return (
    <div className="flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:items-end">
      <label className="flex min-w-[9rem] flex-1 flex-col gap-1.5 text-xs font-medium uppercase tracking-wider text-[var(--muted)]">
        Jour
        <select
          className="rounded-lg border border-white/10 bg-[var(--surface)] px-3 py-2.5 text-sm font-normal normal-case tracking-normal text-[var(--foreground)] outline-none focus:border-[var(--accent)]/50"
          value={value.day}
          onChange={(e) => onChange({ ...value, day: e.target.value })}
        >
          <option value="">Tous</option>
          {days.map((day) => (
            <option key={day} value={day}>
              {formatDayLabel(day)}
            </option>
          ))}
        </select>
      </label>

      <label className="flex min-w-[11rem] flex-1 flex-col gap-1.5 text-xs font-medium uppercase tracking-wider text-[var(--muted)]">
        Cinéma
        <select
          className="rounded-lg border border-white/10 bg-[var(--surface)] px-3 py-2.5 text-sm font-normal normal-case tracking-normal text-[var(--foreground)] outline-none focus:border-[var(--accent)]/50"
          value={value.cinemaKey}
          onChange={(e) => onChange({ ...value, cinemaKey: e.target.value })}
        >
          <option value="">Tous</option>
          {cinemas.map((c) => (
            <option key={c.key} value={c.key}>
              {c.label}
            </option>
          ))}
        </select>
      </label>

      <label className="flex min-w-[9rem] flex-1 flex-col gap-1.5 text-xs font-medium uppercase tracking-wider text-[var(--muted)]">
        Salle
        <select
          className="rounded-lg border border-white/10 bg-[var(--surface)] px-3 py-2.5 text-sm font-normal normal-case tracking-normal text-[var(--foreground)] outline-none focus:border-[var(--accent)]/50"
          value={value.room}
          onChange={(e) => onChange({ ...value, room: e.target.value })}
        >
          <option value="">Toutes</option>
          {rooms.map((room) => (
            <option key={room} value={room}>
              {room}
            </option>
          ))}
        </select>
      </label>

      <p className="pb-2 text-sm text-[var(--muted)] sm:ml-auto">
        {resultCount} séance{resultCount === 1 ? "" : "s"}
      </p>
    </div>
  );
}

export function filterShowtimes(
  showtimes: Showtime[],
  filters: FilterState,
): Showtime[] {
  return showtimes.filter((st) => {
    if (filters.day && !st.startsAt.startsWith(filters.day)) return false;
    if (filters.cinemaKey && st.cinema.key !== filters.cinemaKey) return false;
    if (filters.room && st.roomLabel !== filters.room) return false;
    return true;
  });
}
