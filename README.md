# 🔧 Utilisation du script sur Debian

## 🐧 Environnement requis
- Distribution Linux : **Debian**
- Accès à internet
- Identifiants GitLab (username + mot de passe ou token)

---

## 1. 📥 Cloner le dépôt Git

```bash
git clone https://gitlab.com/TukaLeHibou/toolboxfinal.git
```

> 🔐 Si le dépôt est privé, il te sera demandé un **nom d'utilisateur** et un **mot de passe/token** GitLab.

---

## 2. 📁 Se rendre dans l’arborescence du projet

```bash
cd toolboxfinal
```

---

## 3. ▶️ Lancer le script Perl

```bash
perl script.pl
```

> 📝 Suivre les indications affichées à l’écran pendant l’exécution.

> 💡 Si un outil requis n’est pas installé, le script proposera automatiquement de l’installer.

---

## 4. 📄 Rapport généré

Une fois le test terminé, un fichier de **rapport** est généré dans le dossier `toolboxfinal`.

---

## 5. ⬆️ Pousser le rapport sur GitLab

### Étapes :

1. Vérifier l’état du dépôt :
   ```bash
   git status
   ```

2. Repérer le chemin du nouveau fichier rapport (ex: `rapport/test_du_jour.txt`).

3. Ajouter le fichier au suivi :
   ```bash
   git add chemin/du/fichier
   ```

4. Configurer ton identité Git si ce n’est pas encore fait :
   ```bash
   git config --global user.email "you@example.com"
   ```

5. Faire le commit :
   ```bash
   git commit -m "Ajout du rapport : nom_du_test"
   ```

6. Pousser les modifications :
   ```bash
   git push
   ```

7. Authentifie-toi à nouveau si demandé (identifiants GitLab).

---

## ✅ Fin de procédure

Ton rapport est désormais disponible dans le dépôt GitLab ! 🗂️
