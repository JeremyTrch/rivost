import { ShowtimesBoard } from "@/components/ShowtimesBoard";
import { RIVOST_CINEMAS } from "@/lib/cinemas";
import { loadShowtimesSnapshot } from "@/lib/showtimes";

export default async function HomePage() {
  const snapshot = await loadShowtimesSnapshot();

  return (
    <main className="relative z-10 mx-auto flex w-full max-w-3xl flex-1 flex-col px-5 pb-16 pt-12 sm:px-8 sm:pt-16">
      <header className="mb-10 sm:mb-12">
        <p className="mb-3 text-xs font-semibold uppercase tracking-[0.28em] text-[var(--accent)]">
          Riviera · VOST
        </p>
        <h1 className="font-[family-name:var(--font-display)] text-5xl leading-none tracking-tight text-[var(--foreground)] sm:text-6xl">
          RiVOST
        </h1>
        <p className="mt-4 max-w-xl text-base leading-relaxed text-[var(--muted)] sm:text-lg">
          Les séances en version originale sous-titrée dans tes cinémas
          habituels — sans ouvrir quatre sites.
        </p>
        <ul className="mt-5 flex flex-wrap gap-x-3 gap-y-1 text-sm text-[var(--accent-soft)]">
          {RIVOST_CINEMAS.map((c) => (
            <li key={c.key} className="after:ml-3 after:text-white/20 after:content-['·'] last:after:content-none">
              {c.label}
            </li>
          ))}
        </ul>
      </header>

      <ShowtimesBoard snapshot={snapshot} />

      <footer className="mt-16 border-t border-white/10 pt-6 text-xs leading-relaxed text-[var(--muted)]">
        <p>
          Données via{" "}
          <a
            className="underline decoration-white/20 underline-offset-2 hover:text-[var(--foreground)]"
            href="https://api-cinema.com"
            target="_blank"
            rel="noopener noreferrer"
          >
            API Cinéma
          </a>
          . Affiches et métadonnées film peuvent provenir de TMDB. Projet
          personnel — horaires indicatifs uniquement.
        </p>
      </footer>
    </main>
  );
}
