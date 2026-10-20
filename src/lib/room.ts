import type { ShowFormat } from "@/types/showtimes";

const PREMIUM_ROOM =
  /lounge|lodge|cosy|imax|atmos|premium|vip|laser|ice|screen\s*x|dolby|aurore/i;

function cleanRoomName(room: string): string {
  return room
    .trim()
    .replace(/^salle\s+/i, "")
    .replace(/\s+/g, " ");
}

/**
 * Human label for the screening experience.
 * Prefer premium formats; otherwise use distinctive room names.
 */
export function roomLabel(format: ShowFormat, room: string | null): string {
  if (format === "IMAX") return "IMAX";
  if (format === "4DX") return "4DX";
  if (format === "DOLBY") {
    if (room && /screen\s*x|lodge|cosy/i.test(room)) {
      return cleanRoomName(room);
    }
    return "Dolby";
  }
  if (format === "3D") {
    if (room && PREMIUM_ROOM.test(room)) {
      return `${cleanRoomName(room)} · 3D`;
    }
    return "3D";
  }

  if (room) {
    const cleaned = cleanRoomName(room);
    if (PREMIUM_ROOM.test(cleaned) || PREMIUM_ROOM.test(room)) {
      return cleaned;
    }
    // Generic "3" / "Salle 3" → Standard
    if (!/^\d+$/i.test(cleaned)) {
      return cleaned;
    }
  }

  return "Standard";
}
