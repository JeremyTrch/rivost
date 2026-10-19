export type ShowVersion = "VF" | "VO" | "VOST" | "VFST" | "UNKNOWN";

export type ShowFormat = "2D" | "3D" | "IMAX" | "4DX" | "DOLBY" | "UNKNOWN";

export type CinemaKey =
  | "cineum-cannes"
  | "pathe-lingostiere"
  | "cgr-cagnes"
  | "cineplanet-antibes";

export interface Cinema {
  key: CinemaKey;
  id: string;
  slug: string;
  name: string;
  city: string;
  label: string;
}

export interface Movie {
  id: string;
  title: string;
  originalTitle: string | null;
  year: number | null;
  durationMin: number | null;
  director: string | null;
  posterUrl: string | null;
  tmdbId: number | null;
}

export interface Showtime {
  id: string;
  startsAt: string;
  version: ShowVersion;
  format: ShowFormat;
  room: string | null;
  bookingUrl: string | null;
  roomLabel: string;
  movie: Movie;
  cinema: Cinema;
}

export interface MovieGroup {
  movie: Movie;
  showtimes: Showtime[];
}

export interface ShowtimesSnapshot {
  fetchedAt: string;
  showtimes: Showtime[];
  cinemas: Cinema[];
  error?: string;
}
