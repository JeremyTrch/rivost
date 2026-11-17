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

## App iOS

Une app SwiftUI native et **autonome** (iOS 26+, Liquid Glass) vit dans [`ios/`](./ios) : films à l’affiche, agenda heure par heure, fiches cinémas, recherche, billetterie in-app. Elle ne dépend d’aucun serveur : elle appelle API Cinéma directement et trouve elle-même les affiches.

- **Clé API** : copie `ios/Config/Secrets.example.xcconfig` en `ios/Config/Secrets.xcconfig` (ignoré par git) et colle ta clé `API_CINEMA_KEY`. Elle est injectée dans l’Info.plist au build.
- **Quota** (250 requêtes/semaine, ~5 par actualisation, partagé avec le site) : l’app garde ses séances 6 h sur le téléphone, ne rafraîchit qu’au-delà ou au changement de jour, et ignore un tirer-pour-actualiser fait moins de 10 min après le précédent.
- **Affiches** : chaque lien est vérifié sur l’appareil ; si aucun ne marche, l’app cherche sur AlloCiné puis TMDB (pages de recherche publiques), et dessine une affiche en dernier recours.
- La clé est embarquée dans l’app : parfait pour un usage perso, mais pour l’App Store il faudrait repasser par un serveur.
- Ouvre `ios/RiVOST.xcodeproj` dans Xcode et lance sur un simulateur ou ton iPhone. L’icône se régénère avec `swift ios/Tools/make-icon.swift ios/RiVOST/Assets.xcassets/AppIcon.appiconset/AppIcon.png`.
- En ligne de commande avec Anaconda actif, `xcodebuild` récupère le linker de conda : préfixe la commande par `env -u LD -u LDFLAGS`.

## Variables d’environnement

| Variable | Où | Rôle |
|---|---|---|
| `API_CINEMA_KEY` | serveur uniquement | Clé Bearer API Cinéma (`ac_live_…`) |
| `CRON_SECRET` | serveur | Protège `GET /api/revalidate` |
| `TMDB_API_KEY` | serveur, optionnel | Clé TMDB gratuite (v3 ou jeton v4) : retrouve les affiches que les cinémas ne fournissent pas |

Chaque affiche est vérifiée à la construction du cache. Si le lien est mort, le serveur essaie l’affiche d’une autre salle, puis la recherche publique AlloCiné puis TMDB (scraping, seulement pour les films sans affiche, résultat mis en cache), puis l’API TMDB si `TMDB_API_KEY` est définie. En dernier recours, l’app iOS dessine une affiche typographique.

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

Compte cible : équipe **JustMe** (`just-me-1ed5`) — pas le compte Gmail.

Le projet Vercel `rivost` existe déjà avec `API_CINEMA_KEY` et `CRON_SECRET`.

Pour brancher GitHub (déploys auto à chaque push) :

1. Connecte GitHub sur ce compte : [vercel.com/account](https://vercel.com/account) → **Login Connections** / Git
2. Puis dans le projet `rivost` → Settings → Git → connecte `JeremyTrch/rivost`

Le cron quotidien (`0 6 * * *` UTC → `/api/revalidate`) est dans [`vercel.json`](./vercel.json)
(Hobby : 1 cron/jour max). Le cache Next se rafraîchit aussi via `cacheLife` (~6 h).

## Disclaimer

Horaires **non contractuels**. Vérifie toujours sur le site / la billetterie du cinéma. Données via API Cinéma ; métadonnées / affiches peuvent provenir de TMDB.

## Licence

MIT — voir [LICENSE](./LICENSE).
