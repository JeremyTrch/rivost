import type { ShowFormat } from "@/types/showtimes";

/**
 * Human label for the screening experience.
 * Prefer premium formats; otherwise use room name hints (Lounge, etc.).
 */
export function roomLabel(format: ShowFormat, room: string | null): string {
  if (format === "IMAX") return "IMAX";
  if (format === "4DX") return "4DX";
  if (format === "DOLBY") return "Dolby";
  if (format === "3D") {
    if (room && /lounge|atmos|premium|vip/i.test(room)) {
      return `${room} · 3D`;
    }
    return "3D";
  }

  if (room) {
    const trimmed = room.trim();
    if (/lounge|imax|atmos|premium|vip|laser|ice/i.test(trimmed)) {
      return trimmed;
    }
    // Generic "Salle 3" → Standard, but keep distinctive names
    if (!/^salle\s*\d+$/i.test(trimmed)) {
      return trimmed;
    }
  }

  return "Standard";
}
