import { cacheLife, cacheTag } from "next/cache";
import {
  ApiCinemaError,
  fetchAllCinemaShowtimes,
} from "@/lib/api-cinema/client";
import { RIVOST_CINEMAS } from "@/lib/cinemas";
import { roomLabel } from "@/lib/room";
import type { Movie, Showtime, ShowtimesSnapshot } from "@/types/showtimes";

export const SHOWTIMES_CACHE_TAG = "showtimes";

function parisDateParts(d = new Date()): { y: number; m: number; day: number } {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Paris",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(d);
  const get = (type: string) =>
    Number(parts.find((p) => p.type === type)?.value ?? 0);
  return { y: get("year"), m: get("month"), day: get("day") };
}

function addDays(y: number, m: number, day: number, days: number): string {
  const utc = new Date(Date.UTC(y, m - 1, day + days));
  const yy = utc.getUTCFullYear();
  const mm = String(utc.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(utc.getUTCDate()).padStart(2, "0");
  return `${yy}-${mm}-${dd}`;
}

function weekRange(): { from: string; to: string } {
  const { y, m, day } = parisDateParts();
  const from = `${y}-${String(m).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
  const to = addDays(y, m, day, 6);
  return { from, to };
}

function mapMovie(raw: {
  id: string;
  title: string;
  originalTitle: string | null;
  year: number | null;
  durationMin: number | null;
  director: string | null;
  posterUrl: string | null;
  tmdbId: number | null;
}): Movie {
  return {
    id: raw.id,
    title: raw.title,
    originalTitle: raw.originalTitle,
    year: raw.year,
    durationMin: raw.durationMin,
    director: raw.director,
    posterUrl: raw.posterUrl,
    tmdbId: raw.tmdbId,
  };
}

async function fetchFreshSnapshot(): Promise<ShowtimesSnapshot> {
  const { from, to } = weekRange();
  const showtimes: Showtime[] = [];

  for (const cinema of RIVOST_CINEMAS) {
    const rows = await fetchAllCinemaShowtimes(cinema.id, {
      from,
      to,
      version: "VOST",
      include: ["movie"],
      limit: 1000,
    });

    for (const row of rows) {
      if (row.version !== "VOST" || !row.movie) continue;
      showtimes.push({
        id: row.id,
        startsAt: row.startsAt,
        version: row.version,
        format: row.format,
        room: row.room,
        bookingUrl: row.bookingUrl,
        roomLabel: roomLabel(row.format, row.room),
        movie: mapMovie(row.movie),
        cinema,
      });
    }
  }

  showtimes.sort((a, b) => a.startsAt.localeCompare(b.startsAt));

  return {
    fetchedAt: new Date().toISOString(),
    showtimes,
    cinemas: RIVOST_CINEMAS,
  };
}

async function getShowtimesSnapshot(): Promise<ShowtimesSnapshot> {
  "use cache";
  cacheTag(SHOWTIMES_CACHE_TAG);
  cacheLife({
    stale: 60 * 60,
    revalidate: 6 * 60 * 60,
    expire: 24 * 60 * 60,
  });
  return fetchFreshSnapshot();
}

export async function loadShowtimesSnapshot(): Promise<ShowtimesSnapshot> {
  if (!process.env.API_CINEMA_KEY) {
    return {
      fetchedAt: new Date().toISOString(),
      showtimes: [],
      cinemas: RIVOST_CINEMAS,
      error:
        "Configure API_CINEMA_KEY pour charger les séances (voir .env.example).",
    };
  }

  try {
    return await getShowtimesSnapshot();
  } catch (err) {
    const message =
      err instanceof ApiCinemaError
        ? err.message
        : err instanceof Error
          ? err.message
          : "Erreur inconnue lors du chargement des séances.";
    return {
      fetchedAt: new Date().toISOString(),
      showtimes: [],
      cinemas: RIVOST_CINEMAS,
      error: message,
    };
  }
}
