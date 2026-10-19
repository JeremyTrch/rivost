import type { Cinema, CinemaKey } from "@/types/showtimes";

/**
 * Fixed Riviera cinemas — IDs resolved once against API Cinéma (2026-10).
 * Hardcoding avoids 4 search calls on every cache refresh.
 */
export const RIVOST_CINEMAS: Cinema[] = [
  {
    key: "cineum-cannes",
    id: "cnc_723880",
    slug: "cineum-cannes-cannes",
    name: "Cineum Cannes",
    city: "Cannes",
    label: "Cinéum Cannes",
  },
  {
    key: "pathe-lingostiere",
    id: "cnc_290191",
    slug: "pathe-lingostiere-nice",
    name: "Pathe Lingostiere",
    city: "Nice",
    label: "Pathé Lingostière Nice",
  },
  {
    key: "cgr-cagnes",
    id: "cnc_81545",
    slug: "cgr-polygone-riviera-cagnes-sur-mer",
    name: "Cgr Polygone Riviera",
    city: "Cagnes-sur-Mer",
    label: "CGR Cagnes-sur-Mer",
  },
  {
    key: "cineplanet-antibes",
    id: "cnc_20685",
    slug: "cineplanet-antibes-antibes",
    name: "Cineplanet Antibes",
    city: "Antibes",
    label: "Cinéplanet Antibes",
  },
];

export function cinemaByKey(key: CinemaKey): Cinema | undefined {
  return RIVOST_CINEMAS.find((c) => c.key === key);
}

export function cinemaLabel(key: CinemaKey): string {
  return cinemaByKey(key)?.label ?? key;
}
