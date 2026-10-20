"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { Filters, filterShowtimes, type FilterState } from "@/components/Filters";
import { MovieCard } from "@/components/MovieCard";
import { groupByMovie, showtimeDay } from "@/lib/showtimes-utils";
import type { ShowtimesSnapshot } from "@/types/showtimes";

function initialFilters(
  snapshot: ShowtimesSnapshot,
  today: string,
): FilterState {
  const hasToday = snapshot.showtimes.some((s) =>
    s.startsAt.startsWith(today),
  );
  return {
    day: hasToday ? today : "",
    cinemaKey: "",
    room: "",
  };
}

export function ShowtimesBoard({
  snapshot,
  today,
}: {
  snapshot: ShowtimesSnapshot;
  today: string;
}) {
  const [filters, setFilters] = useState<FilterState>(() =>
    initialFilters(snapshot, today),
  );
  const [stuck, setStuck] = useState(false);
  const sentinelRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = sentinelRef.current;
    if (!el) return;
    const io = new IntersectionObserver(
      ([entry]) => setStuck(!entry.isIntersecting),
      { threshold: 1 },
    );
    io.observe(el);
    return () => io.disconnect();
  }, []);

  const days = useMemo(() => {
    const set = new Set(snapshot.showtimes.map((s) => showtimeDay(s.startsAt)));
    return Array.from(set).sort();
  }, [snapshot.showtimes]);

  const rooms = useMemo(() => {
    const set = new Set(snapshot.showtimes.map((s) => s.roomLabel));
    return Array.from(set).sort((a, b) => a.localeCompare(b, "fr"));
  }, [snapshot.showtimes]);

  const filtered = useMemo(
    () => filterShowtimes(snapshot.showtimes, filters),
    [snapshot.showtimes, filters],
  );

  const groups = useMemo(() => groupByMovie(filtered), [filtered]);

  const updatedLabel = useMemo(() => {
    try {
      return new Intl.DateTimeFormat("fr-FR", {
        dateStyle: "medium",
        timeStyle: "short",
        timeZone: "Europe/Paris",
      }).format(new Date(snapshot.fetchedAt));
    } catch {
      return snapshot.fetchedAt;
    }
  }, [snapshot.fetchedAt]);

  if (snapshot.error) {
    return (
      <div className="animate-fade rounded-xl border border-amber-500/25 bg-amber-500/[0.08] px-5 py-6 text-amber-50">
        <p className="font-semibold">Données indisponibles</p>
        <p className="mt-2 text-sm text-amber-100/75">{snapshot.error}</p>
      </div>
    );
  }

  if (snapshot.showtimes.length === 0) {
    return (
      <div className="animate-fade border border-[var(--line)] bg-[var(--surface)]/60 px-5 py-12 text-center">
        <p className="font-[family-name:var(--font-display)] text-2xl tracking-tight">
          Aucune séance VOST cette semaine
        </p>
        <p className="mt-2 text-sm text-[var(--muted)]">
          Les programmes changent souvent — reviens un peu plus tard.
        </p>
      </div>
    );
  }

  return (
    <div className="animate-fade flex flex-col">
      <div ref={sentinelRef} className="h-px w-full" aria-hidden />
      <Filters
        cinemas={snapshot.cinemas}
        days={days}
        rooms={rooms}
        today={today}
        value={filters}
        onChange={setFilters}
        resultCount={filtered.length}
        stuck={stuck}
      />

      <p className="mt-4 text-xs text-[var(--muted)]">
        Mis à jour le {updatedLabel}
      </p>

      {groups.length === 0 ? (
        <div className="mt-8 border border-[var(--line)] bg-[var(--surface)]/50 px-5 py-12 text-center">
          <p className="font-[family-name:var(--font-display)] text-xl">
            Rien pour ces filtres
          </p>
          <button
            type="button"
            className="mt-3 text-sm text-[var(--accent)] hover:text-[var(--accent-hot)]"
            onClick={() => setFilters({ day: "", cinemaKey: "", room: "" })}
          >
            Voir toute la semaine
          </button>
        </div>
      ) : (
        <div className="mt-2">
          {groups.map((group, index) => (
            <MovieCard
              key={
                group.movie.tmdbId
                  ? `tmdb-${group.movie.tmdbId}`
                  : group.movie.id
              }
              group={group}
              index={index}
            />
          ))}
        </div>
      )}
    </div>
  );
}
