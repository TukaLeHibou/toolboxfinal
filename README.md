
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

> 💡 Si un outil requis n’est pas installé, le script proposera automatiquement de l’installer.  

> 📝 Suivre les indications affichées à l’écran pendant l’exécution.

---

### 💻 Exemple d'exécution :

```bash
root@osboxes:~/toolboxfinal# perl script.pl
 Script de Test de Sécurité v2.0.0
==================================================
Entrez votre nom et prénom (testeur): Pierre Paul
Entrez le nom du client ou de l'organisation: Test

=== Liste des biens essentiels disponibles ===
1. Bien
2. Serveur Web
3. Réseau Local
4. Base de Données
5. Application Mobile
Sélectionnez un bien essentiel (numéro 1-5): 2
 Bien essentiel sélectionné : Serveur Web
 Risque associé : Exposition aux attaques réseau
 Attaque associée : Scan de ports

=== Outils disponibles pour l'attaque 'Scan de ports' ===
1. nmap
2. ncat
Sélectionnez un outil (numéro 1-2) : 1
 Outil sélectionné : nmap
 L'outil nmap est installé.
Entrez la cible à tester (IP, domaine ou URL): 127.0.0.1
Exécution de nmap sur 127.0.0.1...
Starting Nmap 7.80 ( https://nmap.org ) at 2025-06-04 10:14 EDT
Nmap scan report for localhost (127.0.0.1)
Host is up (0.0000030s latency).
Not shown: 998 closed ports
PORT   STATE SERVICE
22/tcp open  ssh
80/tcp open  http

Nmap done: 1 IP address (1 host up) scanned in 0.17 seconds
 Exécution terminée
Entrez un commentaire sur les résultats (optionnel):
 Rapport généré avec succès : RESULTAT/rapport_20250604_101439_Test.md

 Test terminé avec succès !
 Rapport disponible : RESULTAT/rapport_20250604_101439_Test.md
```

---

## 4. ⬆️ Pousser le rapport sur GitLab

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

Ton rapport est désormais disponible dans le dépôt GitLab RESULTAT ! 🗂️
