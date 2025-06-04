# Ping Cheatsheet - Niveau OSI 3 (Réseau)

## Description
Ping est un outil en ligne de commande utilisé pour tester la connectivité réseau entre deux hôtes en envoyant des paquets ICMP Echo Request et en attendant des réponses Echo Reply.

# PRE_REQUIS_EXEC
apt update -y && apt install iputils-ping -y

# COMMANDE_EXEC
ping -c 10 "$TARGET"
