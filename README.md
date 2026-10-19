# RiVOST

Agrégateur de **séances VOST** sur la Côte d’Azur — pour ne plus ouvrir quatre sites de cinéma.

**Cinémas couverts**

- Cinéum Cannes
- Pathé Lingostière Nice
- CGR Cagnes-sur-Mer
- Cinéplanet Antibes

Pour chaque séance : heure, cinéma, et type de salle / format (IMAX, Dolby, Lounge, Standard…).

## Stack

- [Next.js](https://nextjs.org) (App Router) + TypeScript + Tailwind
- [API Cinéma](https://api-cinema.com) (données séances)
- Déploiement [Vercel](https://vercel.com) + cron de refresh toutes les 6 h

## Démarrage local

```bash
npm install
cp .env.example .env.local
# renseigne API_CINEMA_KEY et CRON_SECRET
npm run dev
```

Ouvre [http://localhost:3000](http://localhost:3000).

## Variables d’environnement

| Variable | Où | Rôle |
|---|---|---|
| `API_CINEMA_KEY` | serveur uniquement | Clé Bearer API Cinéma (`ac_live_…`) |
| `CRON_SECRET` | serveur | Protège `GET /api/revalidate` |

Ne jamais committer `.env.local` ni exposer la clé côté client.

## Cache & quota

Le free plan API Cinéma limite à **250 requêtes / semaine**. RiVOST :

1. résout les 4 cinémas puis charge leurs séances VOST de la semaine ;
2. met le résultat en cache (~6 h) via Cache Components ;
3. le cron Vercel (`0 */6 * * *` → `/api/revalidate`) invalide le tag `showtimes`.

Les visiteurs lisent le cache : le quota reste largement sous la limite pour un usage personnel / public léger.

## Repo

- GitHub : [JeremyTrch/rivost](https://github.com/JeremyTrch/rivost)

## Déploiement Vercel

1. Sur [vercel.com/new](https://vercel.com/new), importe **JeremyTrch/rivost** (compte Gmail / celui où tu as déjà tes projets).
2. Avant le premier deploy, ajoute les env vars (Production + Preview) :
   - `API_CINEMA_KEY` — clé `ac_live_…` (API Cinéma)
   - `CRON_SECRET` — chaîne aléatoire longue (ex. `openssl rand -hex 24`)
3. Deploy — le cron (`0 */6 * * *` → `/api/revalidate`) est dans [`vercel.json`](./vercel.json).

Vercel envoie `Authorization: Bearer <CRON_SECRET>` aux crons Hobby quand `CRON_SECRET` est défini dans le projet.

## Disclaimer

Horaires **non contractuels**. Vérifie toujours sur le site / la billetterie du cinéma. Données via API Cinéma ; métadonnées / affiches peuvent provenir de TMDB.

## Licence

MIT — voir [LICENSE](./LICENSE).
