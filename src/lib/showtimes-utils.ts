import type { MovieGroup, Showtime } from "@/types/showtimes";

export function groupByMovie(showtimes: Showtime[]): MovieGroup[] {
  const map = new Map<string, MovieGroup>();

  for (const st of showtimes) {
    const key = st.movie.tmdbId
      ? `tmdb:${st.movie.tmdbId}`
      : `id:${st.movie.id}`;
    const existing = map.get(key);
    if (existing) {
      existing.showtimes.push(st);
    } else {
      map.set(key, { movie: st.movie, showtimes: [st] });
    }
  }

  return Array.from(map.values()).sort((a, b) =>
    a.movie.title.localeCompare(b.movie.title, "fr"),
  );
}

export function showtimeDay(startsAt: string): string {
  return startsAt.slice(0, 10);
}

export function showtimeTime(startsAt: string): string {
  return startsAt.slice(11, 16);
}
