import type { ShowFormat, ShowVersion } from "@/types/showtimes";

export interface ApiCinema {
  id: string;
  slug: string;
  name: string;
  address: string | null;
  city: string;
  country: "FR" | "US";
  timezone: string;
  postalCode: string | null;
  lat: number | null;
  lng: number | null;
  website: string | null;
  ticketingUrl?: string | null;
}

export interface ApiMovie {
  id: string;
  title: string;
  rawTitle: string | null;
  originalTitle: string | null;
  year: number | null;
  durationMin: number | null;
  director: string | null;
  synopsis?: string | null;
  genres?: string[];
  posterUrl: string | null;
  allocineId: string | null;
  tmdbId: number | null;
  titleSource?: "tmdb" | "raw";
}

export interface ApiShowtime {
  id: string;
  cinemaId: string;
  movieId: string;
  startsAt: string;
  version: ShowVersion;
  format: ShowFormat;
  room: string | null;
  bookingUrl: string | null;
  updatedAt: string;
  removedAt: string | null;
  movie?: ApiMovie;
  cinema?: ApiCinema;
}

export interface ApiShowtimeMeta {
  limit: number;
  offset?: number;
  total?: number;
  nextCursor: string | null;
  syncedAt: string;
}

export interface ApiShowtimeList {
  data: ApiShowtime[];
  meta: ApiShowtimeMeta;
}

export interface ApiCinemaList {
  data: ApiCinema[];
  meta: { limit: number; offset: number; total?: number };
}

export interface ShowtimeSearchBody {
  country?: "FR" | "US";
  city?: string;
  cinemaId?: string;
  movieId?: string;
  tmdbId?: number;
  allocineId?: string;
  near?: { lat: number; lng: number; radiusKm?: number };
  date?: string;
  from?: string;
  to?: string;
  version?: ShowVersion;
  include?: Array<"movie" | "cinema">;
  limit?: number;
  offset?: number;
  cursor?: string;
}

export interface CinemaShowtimeSearchBody {
  date?: string;
  from?: string;
  to?: string;
  version?: ShowVersion;
  include?: Array<"movie" | "cinema">;
  limit?: number;
  offset?: number;
  cursor?: string;
}
