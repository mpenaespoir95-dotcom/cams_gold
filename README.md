# CAMS Gold

Application Flutter de gestion d’un comptoir d’or et de devises, en français.

## Écrans

- Connexion et création de compte (mode démonstration).
- Accueil : trésorerie, indicateurs, rendez-vous et dernières opérations.
- Achats d’or avec estimation selon le cours GoldAPI, le poids et les carats.
- Carnet d’achats avec saisie manuelle du prix, suivi des avances et poids
  facultatif pour mettre à jour le stock.
- Ventes à Dubaï avec cours GoldAPI, conversion en FCFA et calcul du bénéfice.
- Échanges de devises avec conversion en FCFA et graphique historique local
  (24 heures, 7 jours, 30 jours et 1 an).
- Répertoire clients/fournisseurs et gestion de rendez-vous.
- Achats en partenariat et répartition des apports.
- Banques, caisse, versements et retraits ; les versements sont consultables
  depuis la caisse et les opérations bancaires peuvent être recherchées.

Les écrans sont organisés sous `lib/screens/`, avec des composants communs dans
`lib/shared/` et les données de démonstration dans `lib/core/app_store.dart`.

## Lancer et tester

```sh
flutter pub get
flutter run --dart-define=EXCHANGE_RATE_API_KEY=votre_cle_taux --dart-define=GOLDAPI_KEY=votre_cle_or
flutter test
flutter analyze
```

L’écran Échanges utilise ExchangeRate-API. La clé doit être transmise au
lancement via `--dart-define` et ne doit pas être ajoutée au dépôt. Sans clé,
l’application utilise le point d’accès public sans clé. La clé incluse dans
une application mobile compilée reste extractible ; pour une mise en
production, il est préférable de faire transiter les requêtes par un serveur.
Les écrans Achats et Ventes utilisent [GoldAPI](https://www.goldapi.io) pour le
cours XAU/USD et ExchangeRate-API pour la conversion USD/XAF. Les champs de
prix restent modifiables ; sans cours disponible, le prix d’achat doit être
saisi manuellement. Transmettez la clé GoldAPI au lancement avec
`--dart-define=GOLDAPI_KEY=votre_cle_or`. Une clé compilée dans une application
mobile reste extractible ; en production, faites transiter les appels par un
serveur.
Le graphique conserve localement les relevés observés par l’application,
jusqu’à un an. L’offre gratuite publie les cours une fois par jour : les
intervalles horaires montrent les relevés collectés lorsque l’application est
utilisée, mais ne constituent pas un historique horaire fourni par l’API.

## Limites du prototype

L’authentification et les registres fonctionnent uniquement en mémoire pour la
démonstration. Aucun serveur, stockage permanent ou service bancaire n’est
configuré ; les données sont perdues à la fermeture de l’application.
