# Study Budy

Application iOS pour consulter WebAurion.

<p align="center">
  <a href="https://github.com/Icxxsh/Study-Budy/raw/refs/heads/main/xtool/studybudy.ipa">
    <img alt="Télécharger l’IPA" src="https://img.shields.io/badge/T%C3%A9l%C3%A9charger-l%27IPA-147EFB?style=for-the-badge">
  </a>
</p>

Le bouton télécharge l’IPA actuellement suivie dans le dépôt. Les versions créées à partir d’un tag sont publiées séparément dans les releases.

## Installer l’application sur un iPhone ou un iPad

L’IPA doit être signée avec un identifiant Apple avant de pouvoir être installée. AltStore s’occupe de cette signature.

1. Sur un Mac ou un PC Windows, installez **AltServer** depuis [altstore.io](https://altstore.io/). Sous Windows, installez également iTunes et iCloud depuis le site d’Apple.
2. Connectez l’iPhone ou l’iPad à l’ordinateur, puis utilisez l’icône AltServer dans la barre des menus ou la zone de notification pour installer AltStore sur l’appareil. Saisissez votre identifiant Apple lorsque cela est demandé.
3. Sur l’appareil, si iOS le demande, autorisez le mode développeur dans **Réglages > Confidentialité et sécurité > Mode développeur**, puis redémarrez l’appareil.
4. Téléchargez l’IPA avec le bouton ci-dessus. Dans AltStore, ouvrez **Mes apps**, touchez **+**, puis sélectionnez `studybudy.ipa` dans l’app Fichiers.
5. Si iOS demande de faire confiance au certificat, ouvrez **Réglages > Général > VPN et gestion de l’appareil**, sélectionnez le profil associé à votre identifiant Apple, puis touchez **Faire confiance**.

Avec un compte Apple gratuit, la signature expire au bout de sept jours. Actualisez l’application depuis AltStore avant son expiration ; AltServer doit être disponible sur le même réseau Wi-Fi.

## Publier une nouvelle version

La GitHub Action [release-ipa](./.github/workflows/release-ipa.yml) compile l’application et joint l’IPA à une release lorsqu’un tag de version est poussé. Par exemple :

```bash
git tag v1.0.0
git push origin v1.0.0
```

La release et son IPA seront disponibles dans les [versions publiées](https://github.com/Icxxsh/Study-Budy/releases). Après la première publication, l’IPA sera aussi accessible via le [téléchargement direct de la dernière release](https://github.com/Icxxsh/Study-Budy/releases/latest/download/studybudy.ipa). Les IPA générées par l’action ne sont pas signées pour la distribution App Store ; installez-les avec AltStore ou un outil équivalent de sideloading.
