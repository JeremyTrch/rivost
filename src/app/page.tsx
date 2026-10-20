import { Suspense } from "react";
import { ShowtimesSection } from "@/components/ShowtimesSection";
import { ShowtimesSkeleton } from "@/components/ShowtimesSkeleton";
import { RIVOST_CINEMAS } from "@/lib/cinemas";

export default function HomePage() {
  return (
    <main className="relative z-10 mx-auto flex w-full max-w-4xl flex-1 flex-col px-5 pb-20 pt-10 sm:px-8 sm:pt-14">
      <div className="rivost-horizon" aria-hidden />

      <header className="relative mb-8 sm:mb-10">
        <p className="animate-rise text-[0.7rem] font-semibold uppercase tracking-[0.32em] text-[var(--accent)]">
          Côte d&apos;Azur · VOST
        </p>
        <h1 className="animate-rise animate-rise-delay-1 mt-3 font-[family-name:var(--font-display)] text-[clamp(3.4rem,12vw,5.5rem)] leading-[0.9] tracking-[-0.03em] text-[var(--foreground)]">
          Ri<span className="text-[var(--accent-hot)]">VOST</span>
        </h1>
        <p className="animate-rise animate-rise-delay-2 mt-5 max-w-lg text-[1.05rem] leading-relaxed text-[var(--muted)] sm:text-lg">
          Une seule page pour les séances en version originale — Cannes, Nice,
          Cagnes, Antibes.
        </p>

        <div className="animate-rise animate-rise-delay-3 mt-6 flex flex-wrap gap-2">
          {RIVOST_CINEMAS.map((c) => (
            <span
              key={c.key}
              className="rounded-full border border-[var(--line)] bg-white/[0.03] px-3 py-1 text-xs text-[var(--fog)]"
            >
              {c.label.replace(/ Nice| Cannes|-sur-Mer/, "")}
              <span className="ml-1.5 text-[var(--muted)]">{c.city}</span>
            </span>
          ))}
        </div>

        <div className="horizon-line mt-8" aria-hidden />
      </header>

      <Suspense fallback={<ShowtimesSkeleton />}>
        <ShowtimesSection />
      </Suspense>

      <footer className="mt-16 border-t border-[var(--line)] pt-6 text-xs leading-relaxed text-[var(--muted)]">
        <p>
          Données via{" "}
          <a
            className="text-[var(--fog)] underline decoration-white/15 underline-offset-2 transition hover:text-[var(--accent-hot)]"
            href="https://api-cinema.com"
            target="_blank"
            rel="noopener noreferrer"
          >
            API Cinéma
          </a>
          . Affiches / métadonnées peuvent provenir de TMDB. Horaires
          indicatifs — vérifie toujours sur le site du cinéma.
        </p>
      </footer>
    </main>
  );
}
